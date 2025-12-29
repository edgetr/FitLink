import SwiftUI
import Combine
import HealthKit

#if canImport(UIKit)
import UIKit
#endif

#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - View State

enum HabitTrackerViewState: Equatable {
    case loading
    case loaded
    case error(String)
    case saving
}

// MARK: - AI Suggestion State

enum AISuggestionState: Equatable {
    case idle
    case loading
    case ready(HabitSuggestion)
    case failed(String)
    
    static func == (lhs: AISuggestionState, rhs: AISuggestionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        case (.ready, .ready):
            return true
        default:
            return false
        }
    }
}

// MARK: - HabitTrackerViewModel

@MainActor
class HabitTrackerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var habits: [Habit] = []
    @Published var selectedDate: Date = Habit.normalizeDate(Date())
    @Published var focusedHabitId: UUID?
    @Published var viewState: HabitTrackerViewState = .loading
    
    // AI-related state
    @Published var aiSuggestionState: AISuggestionState = .idle
    @Published var currentSuggestion: HabitSuggestion?
    @Published var streakMotivation: String?
    @Published var enrichingHabitIds: Set<UUID> = []
    
    let instanceId: UUID = UUID()
    @Published var isOnline: Bool = true
    @Published var lastSyncDate: Date?
    
    // MARK: - Focus Timer (derived from FocusTimerManager)
    
    var focusTimeRemainingSeconds: Int {
        FocusTimerManager.shared.remainingSeconds
    }
    
    var isFocusTimerRunning: Bool {
        FocusTimerManager.shared.isActive && !FocusTimerManager.shared.isPaused
    }
    
    var isFocusOnBreak: Bool {
        FocusTimerManager.shared.isOnBreak
    }
    
    // MARK: - Private Properties
    
    private var focusTimerObserver: AnyCancellable?
    private var suggestionDebounceTask: Task<Void, Never>?
    private var lifecycleObservers: [Any] = []
    private let habitStore: HabitStore
    private let habitAIService: HabitAIService
    
    var userId: String? {
        didSet {
            if userId != nil {
                log("User ID set to: \(userId ?? "nil"), reloading habits")
                Task {
                    await loadHabitsAsync()
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var dateRange: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (-6...0).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today)
        }
    }
    
    var activeHabitsForSelectedDate: [Habit] {
        let normalized = Habit.normalizeDate(selectedDate)
        return habits.filter { habit in
            let createdNormalized = Habit.normalizeDate(habit.createdAt)
            let isAfterCreation = normalized >= createdNormalized
            
            if let endDate = habit.endDate {
                let endNormalized = Habit.normalizeDate(endDate)
                return isAfterCreation && normalized <= endNormalized
            }
            
            return isAfterCreation
        }
    }
    
    /// Get the focused habit object
    var focusedHabit: Habit? {
        guard let id = focusedHabitId else { return nil }
        return habits.first { $0.id == id }
    }
    
    /// Total streaks across all habits
    var totalActiveStreaks: Int {
        habits.reduce(0) { $0 + $1.currentStreak }
    }
    
    /// Habits grouped by preferred time of day
    var habitsByTimeOfDay: [HabitTimeOfDay: [Habit]] {
        Dictionary(grouping: activeHabitsForSelectedDate, by: { $0.preferredTime })
    }
    
    // MARK: - Initialization
    
    init(habitStore: HabitStore = .shared, habitAIService: HabitAIService = .shared) {
        self.habitStore = habitStore
        self.habitAIService = habitAIService
        log("HabitTrackerViewModel initialized with instanceId: \(instanceId)")
        setupLifecycleObservers()
        Task {
            await loadHabitsAsync()
        }
    }
    
    deinit {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [HabitTracker-\(instanceId.uuidString.prefix(8))] HabitTrackerViewModel deinit for instanceId: \(instanceId)")
        #endif
        
        #if canImport(UIKit)
        for observer in lifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        #endif
        lifecycleObservers.removeAll()
        
        focusTimerObserver?.cancel()
        focusTimerObserver = nil
        suggestionDebounceTask?.cancel()
    }
    
    // MARK: - Lifecycle
    
    private func setupLifecycleObservers() {
        #if canImport(UIKit)
        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidEnterBackground()
        }
        
        let foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillEnterForeground()
        }
        
        lifecycleObservers.append(backgroundObserver)
        lifecycleObservers.append(foregroundObserver)
        #endif
        
        log("Lifecycle observers set up")
    }
    
    private func removeLifecycleObservers() {
        #if canImport(UIKit)
        for observer in lifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        #endif
        lifecycleObservers.removeAll()
        log("Lifecycle observers removed")
    }
    
    private func handleAppDidEnterBackground() {
        log("App entered background")
        Task {
            await saveHabitsAsync()
        }
    }
    
    private func handleAppWillEnterForeground() {
        log("App will enter foreground")
        let today = Habit.normalizeDate(Date())
        if selectedDate != today {
            selectedDate = today
        }
        resumeFocusTimerAndActivity()
    }
    
    func resumeFocusTimerAndActivity() {
        if focusedHabitId != nil && FocusTimerManager.shared.isActive {
            setupFocusTimerObserver()
            log("Resuming focus timer observer")
        }
    }
    
    // MARK: - Persistence
    
    func loadHabitsAsync() async {
        viewState = .loading
        
        do {
            let loadedHabits = try await habitStore.loadHabits(userId: userId)
            habits = loadedHabits
            viewState = .loaded
            log("Loaded \(habits.count) habits")
            
            await deleteExpiredHabitsAsync()
            
            Task {
                await enrichLegacyHabits()
            }
        } catch {
            log("Failed to load habits: \(error.localizedDescription)")
            viewState = .error(error.localizedDescription)
            habits = []
        }
    }
    
    func saveHabitsAsync() async {
        do {
            try await habitStore.saveHabits(habits, userId: userId)
            lastSyncDate = Date()
            log("Saved \(habits.count) habits")
        } catch {
            log("Failed to save habits: \(error.localizedDescription)")
        }
    }
    
    // MARK: - AI Suggestions
    
    /// Request AI suggestion for habit input (debounced)
    func requestSuggestion(for input: String) {
        // Cancel previous debounce
        suggestionDebounceTask?.cancel()
        
        // Don't suggest for very short inputs
        guard input.count >= 3 else {
            aiSuggestionState = .idle
            currentSuggestion = nil
            return
        }
        
        // Debounce 500ms
        suggestionDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            guard !Task.isCancelled else { return }
            
            await fetchSuggestion(for: input)
        }
    }
    
    /// Fetch AI suggestion immediately (no debounce)
    func fetchSuggestion(for input: String) async {
        aiSuggestionState = .loading
        
        do {
            let suggestion = try await habitAIService.suggestHabitDetails(from: input)
            currentSuggestion = suggestion
            aiSuggestionState = .ready(suggestion)
            log("AI suggestion received: \(suggestion.title)")
        } catch {
            log("AI suggestion failed: \(error.localizedDescription)")
            aiSuggestionState = .failed(error.localizedDescription)
            currentSuggestion = nil
        }
    }
    
    /// Clear current suggestion
    func clearSuggestion() {
        suggestionDebounceTask?.cancel()
        aiSuggestionState = .idle
        currentSuggestion = nil
    }
    
    /// Apply current AI suggestion to create a new habit
    func applyCurrentSuggestion(endDate: Date? = nil) {
        guard let suggestion = currentSuggestion else { return }
        
        let habit = Habit.from(suggestion: suggestion)
        var newHabit = habit
        newHabit = Habit(
            id: habit.id,
            name: habit.name,
            createdAt: habit.createdAt,
            endDate: endDate,
            completionDates: habit.completionDates,
            icon: habit.icon,
            category: habit.category,
            suggestedDurationMinutes: habit.suggestedDurationMinutes,
            preferredTime: habit.preferredTime,
            reminderTime: habit.reminderTime,
            notes: habit.notes,
            isAIGenerated: true,
            motivationalTip: habit.motivationalTip
        )
        
        habits.append(newHabit)
        Task {
            await saveHabitsAsync()
        }
        
        clearSuggestion()
        log("Applied AI suggestion: \(newHabit.name)")
    }
    
    /// Fetch streak motivation for a habit
    func fetchStreakMotivation(for habit: Habit) async {
        guard habit.currentStreak > 0 else {
            streakMotivation = nil
            return
        }
        
        do {
            let message = try await habitAIService.generateStreakMotivation(
                habitName: habit.name,
                streakDays: habit.currentStreak
            )
            streakMotivation = message
        } catch {
            log("Failed to fetch streak motivation: \(error.localizedDescription)")
            streakMotivation = nil
        }
    }
    
    // MARK: - Background Enrichment
    
    func enrichHabitInBackground(habitId: UUID, name: String) async {
        enrichingHabitIds.insert(habitId)
        defer { enrichingHabitIds.remove(habitId) }
        
        do {
            let suggestion = try await habitAIService.suggestHabitDetails(from: name)
            
            if let index = habits.firstIndex(where: { $0.id == habitId }),
               habits[index].icon == "checkmark.circle.fill" {
                habits[index].icon = suggestion.icon
                habits[index].category = HabitCategory(rawValue: suggestion.category.lowercased()) ?? .productivity
                habits[index].suggestedDurationMinutes = suggestion.suggestedDurationMinutes
                habits[index].preferredTime = HabitTimeOfDay(rawValue: suggestion.preferredTimeOfDay.lowercased()) ?? .anytime
                habits[index].motivationalTip = suggestion.motivationalTip
                habits[index].isAIGenerated = true
                
                await saveHabitsAsync()
                log("Background enrichment completed for: \(name)")
            }
        } catch {
            log("Background enrichment failed for \(name): \(error.localizedDescription)")
        }
    }
    
    func enrichLegacyHabits() async {
        let habitsNeedingEnrichment = habits.filter {
            $0.icon == "checkmark.circle.fill" && !$0.isAIGenerated
        }
        
        for habit in habitsNeedingEnrichment {
            await enrichHabitInBackground(habitId: habit.id, name: habit.name)
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }
    
    // MARK: - Habit CRUD
    
    func addHabit(name: String, endDate: Date? = nil) {
        if case .ready(let suggestion) = aiSuggestionState,
           suggestion.title.lowercased().contains(name.lowercased()) ||
           name.lowercased().contains(String(suggestion.title.lowercased().prefix(5))) {
            let habit = Habit(
                name: name,
                endDate: endDate,
                icon: suggestion.icon,
                category: HabitCategory(rawValue: suggestion.category.lowercased()) ?? .productivity,
                suggestedDurationMinutes: suggestion.suggestedDurationMinutes,
                preferredTime: HabitTimeOfDay(rawValue: suggestion.preferredTimeOfDay.lowercased()) ?? .anytime,
                isAIGenerated: true,
                motivationalTip: suggestion.motivationalTip
            )
            habits.append(habit)
            clearSuggestion()
            Task { await saveHabitsAsync() }
            log("Added habit with AI suggestion: \(name)")
        } else {
            let habit = Habit(name: name, endDate: endDate)
            habits.append(habit)
            clearSuggestion()
            Task {
                await saveHabitsAsync()
                await enrichHabitInBackground(habitId: habit.id, name: name)
            }
            log("Added habit (queued for enrichment): \(name)")
        }
    }
    
    /// Add habit with full details
    func addHabit(
        name: String,
        icon: String,
        category: HabitCategory,
        duration: Int,
        preferredTime: HabitTimeOfDay,
        endDate: Date? = nil,
        notes: String? = nil
    ) {
        let habit = Habit(
            name: name,
            endDate: endDate,
            icon: icon,
            category: category,
            suggestedDurationMinutes: duration,
            preferredTime: preferredTime,
            notes: notes
        )
        habits.append(habit)
        Task {
            await saveHabitsAsync()
        }
        log("Added habit with details: \(name)")
    }
    
    func updateHabitName(id: UUID, newName: String) {
        if let index = habits.firstIndex(where: { $0.id == id }) {
            let oldName = habits[index].name
            habits[index].name = newName
            Task {
                await saveHabitsAsync()
            }
            log("Updated habit name from '\(oldName)' to '\(newName)'")
        }
    }
    
    /// Update habit with all properties
    func updateHabit(
        id: UUID,
        name: String? = nil,
        icon: String? = nil,
        category: HabitCategory? = nil,
        duration: Int? = nil,
        preferredTime: HabitTimeOfDay? = nil,
        notes: String? = nil
    ) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        
        if let name = name { habits[index].name = name }
        if let icon = icon { habits[index].icon = icon }
        if let category = category { habits[index].category = category }
        if let duration = duration { habits[index].suggestedDurationMinutes = duration }
        if let preferredTime = preferredTime { habits[index].preferredTime = preferredTime }
        if let notes = notes { habits[index].notes = notes }
        
        Task {
            await saveHabitsAsync()
        }
        log("Updated habit: \(habits[index].name)")
    }
    
    func deleteHabit(withId id: UUID) {
        if let index = habits.firstIndex(where: { $0.id == id }) {
            let habitName = habits[index].name
            habits.removeAll { $0.id == id }
            Task {
                await saveHabitsAsync()
            }
            log("Deleted habit: \(habitName)")
        }
    }
    
    private func deleteExpiredHabitsAsync() async {
        let today = Habit.normalizeDate(Date())
        let expiredHabits = habits.filter { habit in
            if let endDate = habit.endDate {
                return Habit.normalizeDate(endDate) < today
            }
            return false
        }
        
        for habit in expiredHabits {
            log("Removing expired habit: \(habit.name)")
        }
        
        habits.removeAll { habit in
            if let endDate = habit.endDate {
                return Habit.normalizeDate(endDate) < today
            }
            return false
        }
        
        if !expiredHabits.isEmpty {
            await saveHabitsAsync()
            log("Removed \(expiredHabits.count) expired habit(s)")
        }
    }
    
    func toggleCompletion(habit: Habit, on date: Date) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        
        let normalizedDate = Habit.normalizeDate(date)
        
        if let completionIndex = habits[index].completionDates.firstIndex(where: {
            Habit.normalizeDate($0) == normalizedDate
        }) {
            habits[index].completionDates.remove(at: completionIndex)
            log("Unmarked habit '\(habit.name)' as incomplete for \(normalizedDate)")
        } else {
            habits[index].completionDates.append(normalizedDate)
            log("Marked habit '\(habit.name)' as complete for \(normalizedDate)")
        }
        
        Task {
            await saveHabitsAsync()
        }
    }
    
    func isCompleted(habit: Habit, on date: Date) -> Bool {
        let normalizedDate = Habit.normalizeDate(date)
        return habit.completionDates.contains { Habit.normalizeDate($0) == normalizedDate }
    }
    
    // MARK: - Focus Timer
    
    func startFocusSession(for habit: Habit) {
        focusedHabitId = habit.id
        FocusTimerManager.shared.startTimer(for: habit)
        setupFocusTimerObserver()
        log("Started focus session for habit: \(habit.name) (\(habit.suggestedDurationMinutes) min)")
    }
    
    func startFocusSession(for habit: Habit, durationMinutes: Int) {
        focusedHabitId = habit.id
        FocusTimerManager.shared.startTimer(for: habit, durationMinutes: durationMinutes)
        setupFocusTimerObserver()
        log("Started focus session for habit: \(habit.name) (\(durationMinutes) min custom)")
    }
    
    func toggleFocusTimer() {
        if FocusTimerManager.shared.isPaused {
            FocusTimerManager.shared.resume()
            log("Focus timer resumed")
        } else {
            FocusTimerManager.shared.pause()
            log("Focus timer paused")
        }
    }
    
    func stopFocusSession() {
        let habitName = habits.first(where: { $0.id == focusedHabitId })?.name ?? "Unknown"
        focusedHabitId = nil
        focusTimerObserver?.cancel()
        focusTimerObserver = nil
        FocusTimerManager.shared.stop()
        log("Stopped focus session for habit: \(habitName)")
    }
    
    func startFocusBreak() {
        let breakMinutes = max(5, FocusTimerManager.shared.remainingSeconds / 60 / 5)
        FocusTimerManager.shared.startBreak(durationMinutes: breakMinutes)
        log("Started \(breakMinutes)-minute break")
    }
    
    func startFocusBreak(durationMinutes: Int) {
        FocusTimerManager.shared.startBreak(durationMinutes: durationMinutes)
        log("Started \(durationMinutes)-minute custom break")
    }
    
    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    func markCompleteIfNotAlready(habit: Habit) {
        let today = Date()
        if !isCompleted(habit: habit, on: today) {
            toggleCompletion(habit: habit, on: today)
            log("Auto-marked habit '\(habit.name)' as complete after focus session")
        }
    }
    
    private func setupFocusTimerObserver() {
        focusTimerObserver?.cancel()
        focusTimerObserver = FocusTimerManager.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [HabitTracker-\(instanceId.uuidString.prefix(8))] \(message)")
        #endif
    }
}

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

// MARK: - HabitTrackerViewModel

@MainActor
class HabitTrackerViewModel: ObservableObject {
    
    @Published var habits: [Habit] = []
    @Published var selectedDate: Date = Habit.normalizeDate(Date())
    @Published var focusedHabitId: UUID?
    @Published var focusTimeRemainingSeconds: Int = 25 * 60
    @Published var isFocusTimerRunning = false
    @Published var isFocusOnBreak = false
    @Published var viewState: HabitTrackerViewState = .loading
    
    let instanceId: UUID = UUID()
    @Published var isOnline: Bool = true
    @Published var lastSyncDate: Date?
    
    private var timerCancellable: AnyCancellable?
    private var lifecycleObservers: [Any] = []
    private let habitStore: HabitStore
    
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
    
    init(habitStore: HabitStore = .shared) {
        self.habitStore = habitStore
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
        
        timerCancellable?.cancel()
        timerCancellable = nil
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
        if isFocusTimerRunning {
            stopTimer()
            log("Focus timer paused on background")
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
        if focusedHabitId != nil && focusTimeRemainingSeconds > 0 && !isFocusTimerRunning {
            log("Resuming focus timer")
            startTimer()
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
    
    // MARK: - Habit CRUD
    
    func addHabit(name: String, endDate: Date? = nil) {
        let habit = Habit(name: name, endDate: endDate)
        habits.append(habit)
        Task {
            await saveHabitsAsync()
        }
        log("Added habit: \(name)")
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
        focusTimeRemainingSeconds = 25 * 60
        isFocusOnBreak = false
        startTimer()
        startLiveActivity(for: habit)
        log("Started focus session for habit: \(habit.name)")
    }
    
    func toggleFocusTimer() {
        if isFocusTimerRunning {
            stopTimer()
            updateLiveActivity()
            log("Focus timer paused")
        } else {
            startTimer()
            updateLiveActivity()
            log("Focus timer resumed")
        }
    }
    
    func stopFocusSession() {
        stopTimer()
        let habitName = habits.first(where: { $0.id == focusedHabitId })?.name ?? "Unknown"
        focusedHabitId = nil
        focusTimeRemainingSeconds = 25 * 60
        isFocusOnBreak = false
        endLiveActivity()
        log("Stopped focus session for habit: \(habitName)")
    }
    
    func startFocusBreak() {
        focusTimeRemainingSeconds = 5 * 60
        isFocusOnBreak = true
        startTimer()
        updateLiveActivity()
        log("Started 5-minute break")
    }
    
    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func startTimer() {
        isFocusTimerRunning = true
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.focusTimeRemainingSeconds > 0 {
                    self.focusTimeRemainingSeconds -= 1
                    self.updateLiveActivity()
                } else {
                    self.stopTimer()
                    self.endLiveActivity()
                    self.log("Focus timer completed")
                }
            }
    }
    
    private func stopTimer() {
        isFocusTimerRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }
    
    // MARK: - Live Activity
    
    private func startLiveActivity(for habit: Habit) {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            LiveActivityManager.shared.startFocusActivity(
                habitId: habit.id.uuidString,
                habitName: habit.name
            )
        }
        #endif
    }
    
    private func updateLiveActivity() {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            LiveActivityManager.shared.updateActivity(
                timeRemaining: focusTimeRemainingSeconds,
                isRunning: isFocusTimerRunning,
                isOnBreak: isFocusOnBreak
            )
        }
        #endif
    }
    
    private func endLiveActivity() {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            LiveActivityManager.shared.endCurrentActivity()
        }
        #endif
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [HabitTracker-\(instanceId.uuidString.prefix(8))] \(message)")
        #endif
    }
}

import SwiftUI
import Combine
import HealthKit

#if canImport(UIKit)
import UIKit
#endif

#if canImport(ActivityKit)
import ActivityKit
#endif

struct Habit: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var createdAt: Date
    var endDate: Date?
    var completionDates: [Date]
    
    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), endDate: Date? = nil, completionDates: [Date] = []) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.endDate = endDate
        self.completionDates = completionDates
    }
    
    static func normalizeDate(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}

class HabitTrackerViewModel: ObservableObject {
    
    @Published var habits: [Habit] = []
    @Published var selectedDate: Date = Habit.normalizeDate(Date())
    @Published var focusedHabitId: UUID?
    @Published var focusTimeRemainingSeconds: Int = 25 * 60
    @Published var isFocusTimerRunning = false
    @Published var isFocusOnBreak = false
    
    let instanceId: UUID = UUID()
    @Published var isOnline: Bool = true
    @Published var lastSyncDate: Date?
    @Published var showPermissionAlert: Bool = false
    
    private var timerCancellable: AnyCancellable?
    private var lifecycleObservers: [Any] = []
    private let healthStore = HKHealthStore()
    
    var userId: String? {
        didSet {
            if userId != nil {
                log("User ID set to: \(userId ?? "nil"), reloading habits")
                loadHabits()
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
    
    init() {
        log("HabitTrackerViewModel initialized with instanceId: \(instanceId)")
        setupLifecycleObservers()
        requestPermissions()
    }
    
    deinit {
        log("HabitTrackerViewModel deinit for instanceId: \(instanceId)")
        removeLifecycleObservers()
        stopTimer()
    }
    
    func requestPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else {
            log("HealthKit not available on this device")
            loadHabits()
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if success {
                    self.log("HealthKit authorization granted")
                    self.showPermissionAlert = false
                } else {
                    self.log("HealthKit authorization denied: \(error?.localizedDescription ?? "Unknown error")")
                    self.showPermissionAlert = true
                }
                
                self.loadHabits()
            }
        }
    }
    
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
        saveHabits()
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
    
    func addHabit(name: String, endDate: Date? = nil) {
        let habit = Habit(name: name, endDate: endDate)
        habits.append(habit)
        saveHabits()
        log("Added habit: \(name)")
    }
    
    func updateHabitName(id: UUID, newName: String) {
        if let index = habits.firstIndex(where: { $0.id == id }) {
            let oldName = habits[index].name
            habits[index].name = newName
            saveHabits()
            log("Updated habit name from '\(oldName)' to '\(newName)'")
        }
    }
    
    func deleteHabit(withId id: UUID) {
        if let index = habits.firstIndex(where: { $0.id == id }) {
            let habitName = habits[index].name
            habits.removeAll { $0.id == id }
            saveHabits()
            log("Deleted habit: \(habitName)")
        }
    }
    
    func deleteExpiredHabits() {
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
            saveHabits()
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
        
        saveHabits()
    }
    
    func isCompleted(habit: Habit, on date: Date) -> Bool {
        let normalizedDate = Habit.normalizeDate(date)
        return habit.completionDates.contains { Habit.normalizeDate($0) == normalizedDate }
    }
    
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
    
    private func habitsFileURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let filename: String
        if let userId = userId, !userId.isEmpty {
            filename = "habits_\(userId).json"
        } else {
            filename = "habits.json"
        }
        
        return documentsDirectory.appendingPathComponent(filename)
    }
    
    private func saveHabits() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(habits)
            try data.write(to: habitsFileURL())
            lastSyncDate = Date()
            log("Saved \(habits.count) habits to \(habitsFileURL().lastPathComponent)")
        } catch {
            log("Failed to save habits: \(error.localizedDescription)")
        }
    }
    
    private func loadHabits() {
        let url = habitsFileURL()
        log("Loading habits from: \(url.lastPathComponent)")
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            log("No habits file found, loading sample data")
            habits = sampleHabits
            saveHabits()
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            habits = try decoder.decode([Habit].self, from: data)
            log("Loaded \(habits.count) habits")
            
            deleteExpiredHabits()
        } catch {
            log("Failed to load habits: \(error.localizedDescription), using sample data")
            habits = sampleHabits
        }
    }
    
    private var sampleHabits: [Habit] {
        [
            Habit(name: "Morning Exercise"),
            Habit(name: "Read 30 minutes"),
            Habit(name: "Drink 8 glasses of water")
        ]
    }
    
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
    
    private func log(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [HabitTracker-\(instanceId.uuidString.prefix(8))] \(message)")
        #endif
    }
}

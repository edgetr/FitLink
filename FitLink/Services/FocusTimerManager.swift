import Foundation
import Combine

#if canImport(UIKit)
import UIKit
#endif

#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - FocusTimerManager

/// Centralized timer manager that persists across navigation and app lifecycle.
/// Singleton that manages timer state, Live Activity integration, and background persistence.
@MainActor
final class FocusTimerManager: ObservableObject {
    static let shared = FocusTimerManager()
    
    // MARK: - Published State
    
    @Published private(set) var isActive: Bool = false
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var isOnBreak: Bool = false
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var totalSeconds: Int = 0
    @Published private(set) var activeHabit: Habit?
    
    // MARK: - Persistence Keys
    
    private let kTimerIsActive = "FocusTimerIsActive"
    private let kTimerIsPaused = "FocusTimerIsPaused"
    private let kTimerEndDate = "FocusTimerEndDate"
    private let kTimerHabitId = "FocusTimerHabitId"
    private let kTimerHabitName = "FocusTimerHabitName"
    private let kTimerHabitIcon = "FocusTimerHabitIcon"
    private let kTimerTotalSeconds = "FocusTimerTotalSeconds"
    private let kTimerRemainingSeconds = "FocusTimerRemainingSeconds"
    private let kTimerIsBreak = "FocusTimerIsBreak"
    private let kTimerPreBreakRemaining = "FocusTimerPreBreakRemaining"
    private let kTimerPreBreakTotal = "FocusTimerPreBreakTotal"
    
    // MARK: - Private Properties
    
    private var timerCancellable: AnyCancellable?
    private var endDate: Date?
    private var lifecycleObservers: [Any] = []
    
    /// Stores the remaining seconds from the focus session before a break started
    private var preBreakRemainingSeconds: Int = 0
    /// Stores the total seconds from the focus session before a break started
    private var preBreakTotalSeconds: Int = 0
    
    // MARK: - State Snapshot
    
    struct TimerStateSnapshot: Sendable {
        let remainingSeconds: Int
        let isPaused: Bool
        let isOnBreak: Bool
        let totalSeconds: Int
        let endDate: Date?
    }
    
    func createStateSnapshot() -> TimerStateSnapshot {
        TimerStateSnapshot(
            remainingSeconds: remainingSeconds,
            isPaused: isPaused,
            isOnBreak: isOnBreak,
            totalSeconds: totalSeconds,
            endDate: isPaused ? nil : Date().addingTimeInterval(TimeInterval(remainingSeconds))
        )
    }
    
    // MARK: - Computed Properties
    
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
    }
    
    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Initialization
    
    private init() {
        restoreTimerState()
        setupLifecycleObservers()
        log("FocusTimerManager initialized")
    }
    
    deinit {
        #if canImport(UIKit)
        for observer in lifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        #endif
        lifecycleObservers.removeAll()
        timerCancellable?.cancel()
    }
    
    // MARK: - Public API
    
    /// Start a timer for a specific habit
    func startTimer(for habit: Habit, durationMinutes: Int? = nil) {
        let duration = durationMinutes ?? habit.suggestedDurationMinutes
        
        activeHabit = habit
        totalSeconds = duration * 60
        remainingSeconds = totalSeconds
        isActive = true
        isPaused = false
        isOnBreak = false
        endDate = Date().addingTimeInterval(TimeInterval(totalSeconds))
        
        persistTimerState()
        startLiveActivity()
        startCountdown()
        
        log("Started timer for habit: \(habit.name) (\(duration) min)")
    }
    
    /// Pause the current timer
    func pause() {
        guard isActive, !isPaused else { return }
        
        isPaused = true
        timerCancellable?.cancel()
        timerCancellable = nil
        
        // Store remaining time, clear end date
        endDate = nil
        persistTimerState()
        updateLiveActivity()
        
        log("Timer paused with \(remainingSeconds) seconds remaining")
    }
    
    /// Resume a paused timer
    func resume() {
        guard isActive, isPaused else { return }
        
        isPaused = false
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        
        persistTimerState()
        updateLiveActivity()
        startCountdown()
        
        log("Timer resumed")
    }
    
    /// Stop and reset the timer
    func stop() {
        let habitName = activeHabit?.name ?? "Unknown"
        
        isActive = false
        isPaused = false
        isOnBreak = false
        remainingSeconds = 0
        totalSeconds = 0
        activeHabit = nil
        endDate = nil
        
        timerCancellable?.cancel()
        timerCancellable = nil
        
        clearPersistedState()
        endLiveActivity()
        
        log("Timer stopped for habit: \(habitName)")
    }
    
    func startBreak(durationMinutes: Int = 5) {
        guard isActive else { return }
        
        preBreakRemainingSeconds = remainingSeconds
        preBreakTotalSeconds = totalSeconds
        
        isOnBreak = true
        totalSeconds = durationMinutes * 60
        remainingSeconds = totalSeconds
        isPaused = false
        endDate = Date().addingTimeInterval(TimeInterval(totalSeconds))
        
        persistTimerState()
        updateLiveActivity()
        startCountdown()
        
        log("Started \(durationMinutes)-minute break (saved \(preBreakRemainingSeconds)s remaining)")
    }
    
    func endBreak() {
        guard isActive, isOnBreak else { return }
        
        isOnBreak = false
        
        totalSeconds = preBreakTotalSeconds
        remainingSeconds = preBreakRemainingSeconds
        
        isPaused = false
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        
        preBreakRemainingSeconds = 0
        preBreakTotalSeconds = 0
        
        persistTimerState()
        updateLiveActivity()
        startCountdown()
        
        log("Ended break, resuming focus session with \(remainingSeconds)s remaining")
    }
    
    func addTime(minutes: Int) {
        remainingSeconds += minutes * 60
        totalSeconds += minutes * 60
        
        if !isPaused {
            endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        }
        
        persistTimerState()
        updateLiveActivity()
        
        log("Added \(minutes) minutes to timer")
    }
    
    // MARK: - Private Implementation
    
    private func startCountdown() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    private func tick() {
        if remainingSeconds > 0 {
            remainingSeconds -= 1
            
            // Update Live Activity every 15 seconds to save battery
            if remainingSeconds % 15 == 0 {
                updateLiveActivity()
            }
        } else {
            handleTimerComplete()
        }
    }
    
    private func handleTimerComplete() {
        timerCancellable?.cancel()
        timerCancellable = nil
        
        if isOnBreak {
            NotificationService.shared.sendLocalNotification(
                title: "Break Complete",
                body: "Ready to get back to \(activeHabit?.name ?? "focus")?"
            )
            log("Break completed for habit: \(activeHabit?.name ?? "Unknown")")
            endBreak()
        } else {
            NotificationService.shared.sendLocalNotification(
                title: "Focus Complete!",
                body: "Great work on \(activeHabit?.name ?? "your habit")!"
            )
            log("Focus session completed for habit: \(activeHabit?.name ?? "Unknown")")
            stop()
        }
    }
    
    // MARK: - Persistence
    
    private func persistTimerState() {
        let defaults = UserDefaults.standard
        defaults.set(isActive, forKey: kTimerIsActive)
        defaults.set(isPaused, forKey: kTimerIsPaused)
        defaults.set(endDate, forKey: kTimerEndDate)
        defaults.set(activeHabit?.id.uuidString, forKey: kTimerHabitId)
        defaults.set(activeHabit?.name, forKey: kTimerHabitName)
        defaults.set(activeHabit?.icon, forKey: kTimerHabitIcon)
        defaults.set(totalSeconds, forKey: kTimerTotalSeconds)
        defaults.set(remainingSeconds, forKey: kTimerRemainingSeconds)
        defaults.set(isOnBreak, forKey: kTimerIsBreak)
        defaults.set(preBreakRemainingSeconds, forKey: kTimerPreBreakRemaining)
        defaults.set(preBreakTotalSeconds, forKey: kTimerPreBreakTotal)
    }
    
    private func clearPersistedState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: kTimerIsActive)
        defaults.removeObject(forKey: kTimerIsPaused)
        defaults.removeObject(forKey: kTimerEndDate)
        defaults.removeObject(forKey: kTimerHabitId)
        defaults.removeObject(forKey: kTimerHabitName)
        defaults.removeObject(forKey: kTimerHabitIcon)
        defaults.removeObject(forKey: kTimerTotalSeconds)
        defaults.removeObject(forKey: kTimerRemainingSeconds)
        defaults.removeObject(forKey: kTimerIsBreak)
        defaults.removeObject(forKey: kTimerPreBreakRemaining)
        defaults.removeObject(forKey: kTimerPreBreakTotal)
    }
    
    private func restoreTimerState() {
        let defaults = UserDefaults.standard
        
        guard defaults.bool(forKey: kTimerIsActive) else { return }
        
        isOnBreak = defaults.bool(forKey: kTimerIsBreak)
        totalSeconds = defaults.integer(forKey: kTimerTotalSeconds)
        let waspaused = defaults.bool(forKey: kTimerIsPaused)
        
        preBreakRemainingSeconds = defaults.integer(forKey: kTimerPreBreakRemaining)
        preBreakTotalSeconds = defaults.integer(forKey: kTimerPreBreakTotal)
        
        if let habitIdString = defaults.string(forKey: kTimerHabitId),
           let habitId = UUID(uuidString: habitIdString) {
            let habitName = defaults.string(forKey: kTimerHabitName) ?? "Focus"
            let habitIcon = defaults.string(forKey: kTimerHabitIcon) ?? "checkmark.circle.fill"
            
            activeHabit = Habit(
                id: habitId,
                name: habitName,
                icon: habitIcon
            )
        }
        
        if waspaused {
            remainingSeconds = defaults.integer(forKey: kTimerRemainingSeconds)
            isActive = true
            isPaused = true
            log("Restored paused timer with \(remainingSeconds) seconds remaining")
        } else if let storedEndDate = defaults.object(forKey: kTimerEndDate) as? Date {
            let now = Date()
            if storedEndDate > now {
                remainingSeconds = Int(storedEndDate.timeIntervalSince(now))
                endDate = storedEndDate
                isActive = true
                isPaused = false
                startCountdown()
                log("Restored running timer with \(remainingSeconds) seconds remaining")
            } else {
                remainingSeconds = 0
                isActive = true
                isPaused = false
                handleTimerComplete()
                log("Timer completed while app was closed")
            }
        }
        
        updateLiveActivity()
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
    }
    
    private func handleAppDidEnterBackground() {
        persistTimerState()
        log("App entered background - timer state persisted")
    }
    
    private func handleAppWillEnterForeground() {
        processWidgetCommands()
        
        guard isActive else { return }
        
        if !isPaused, let storedEndDate = endDate {
            let now = Date()
            if storedEndDate > now {
                remainingSeconds = Int(storedEndDate.timeIntervalSince(now))
                log("Restored from background with \(remainingSeconds) seconds remaining")
            } else {
                remainingSeconds = 0
                handleTimerComplete()
            }
        }
        
        updateLiveActivity()
    }
    
    func processWidgetCommands() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        
        log("processWidgetCommands() called")
        if let command = LiveActivityManager.shared.processWidgetCommand() {
            log("Found widget command: \(command)")
            switch command {
            case .start:
                break
            case .pause:
                pause()
            case .resume:
                resume()
            case .stop:
                stop()
            }
            log("Processed widget command: \(command)")
        } else {
            log("No widget command found")
        }
        #endif
    }
    
    // MARK: - Live Activity
    
    private func startLiveActivity() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        
        LiveActivityManager.shared.startFocusActivity()
        #endif
    }
    
    private func updateLiveActivity() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        
        LiveActivityManager.shared.updateActivity()
        #endif
    }
    
    private func endLiveActivity() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        
        LiveActivityManager.shared.endCurrentActivity()
        #endif
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [FocusTimerManager] \(message)")
        #endif
    }
}

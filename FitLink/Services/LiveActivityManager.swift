import Foundation
import WidgetKit

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
@MainActor
final class LiveActivityManager {
    
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<FitLinkLiveActivityAttributes>?
    
    private static let appGroupIdentifier = "group.com.edgetr.FitLink"
    private static let stateKey = "focusTimerState"
    private static let commandKey = "focusTimerCommand"
    
    private init() {}
    
    var isActivityActive: Bool {
        currentActivity != nil && currentActivity?.activityState != .ended
    }
    
    private var timerManager: FocusTimerManager {
        FocusTimerManager.shared
    }
    
    // MARK: - Focus Activity
    
    func startFocusActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            log("Live Activities are not enabled")
            return
        }
        
        endCurrentActivity()
        
        let habitId = timerManager.activeHabit?.id.uuidString ?? ""
        let habitName = timerManager.activeHabit?.name ?? "Focus"
        let habitIcon = timerManager.activeHabit?.icon ?? "brain.head.profile"
        let totalSeconds = timerManager.totalSeconds
        
        let attributes = FitLinkLiveActivityAttributes(
            habitId: habitId,
            habitName: habitName,
            habitIcon: habitIcon
        )
        
        let now = Date()
        let initialState = FitLinkLiveActivityAttributes.ContentState.initialFocusState(
            totalTime: totalSeconds,
            startDate: now
        )
        
        let staleDate = now.addingTimeInterval(TimeInterval(totalSeconds + 300))
        
        do {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: initialState, staleDate: staleDate)
                currentActivity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } else {
                currentActivity = try Activity.request(
                    attributes: attributes,
                    contentState: initialState,
                    pushType: nil
                )
            }
            
            writeSharedState(timerState: .running)
            reloadWidgets()
            
            log("Started Live Activity for habit: \(habitName) with \(totalSeconds)s")
        } catch {
            log("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }
    
    func updateActivity() {
        guard let activity = currentActivity else { return }
        
        let timeRemaining = timerManager.remainingSeconds
        let totalTime = timerManager.totalSeconds
        let isRunning = !timerManager.isPaused
        let isOnBreak = timerManager.isOnBreak
        
        let newState: FitLinkLiveActivityAttributes.ContentState
        let sharedTimerState: FocusTimerStateRaw
        
        if timeRemaining <= 0 {
            newState = .finishedState()
            sharedTimerState = .finished
        } else if isOnBreak {
            if isRunning {
                newState = .runningState(
                    timeRemaining: timeRemaining,
                    totalTime: totalTime,
                    isOnBreak: true
                )
            } else {
                newState = .pausedState(timeRemaining: timeRemaining, totalTime: totalTime)
            }
            sharedTimerState = isRunning ? .breakTime : .paused
        } else if isRunning {
            newState = .runningState(
                timeRemaining: timeRemaining,
                totalTime: totalTime,
                isOnBreak: false
            )
            sharedTimerState = .running
        } else {
            newState = .pausedState(timeRemaining: timeRemaining, totalTime: totalTime)
            sharedTimerState = .paused
        }
        
        let staleDate: Date? = timeRemaining > 0 ? Date().addingTimeInterval(TimeInterval(timeRemaining + 300)) : nil
        
        Task {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: newState, staleDate: staleDate)
                await activity.update(content)
            } else {
                await activity.update(using: newState)
            }
        }
        
        writeSharedState(timerState: sharedTimerState)
    }
    
    func endCurrentActivity() {
        guard let activity = currentActivity else { return }
        
        let finalState = FitLinkLiveActivityAttributes.ContentState.finishedState()
        
        Task {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(content, dismissalPolicy: .immediate)
            } else {
                await activity.end(using: finalState, dismissalPolicy: .immediate)
            }
        }
        
        currentActivity = nil
        
        clearSharedState()
        reloadWidgets()
        
        log("Ended Live Activity")
    }
    
    func endAllActivities() {
        Task {
            for activity in Activity<FitLinkLiveActivityAttributes>.activities {
                let finalState = FitLinkLiveActivityAttributes.ContentState.finishedState()
                if #available(iOS 16.2, *) {
                    let content = ActivityContent(state: finalState, staleDate: nil)
                    await activity.end(content, dismissalPolicy: .immediate)
                } else {
                    await activity.end(using: finalState, dismissalPolicy: .immediate)
                }
            }
        }
        currentActivity = nil
        
        clearSharedState()
        reloadWidgets()
        
        log("Ended all Live Activities")
    }
    
    // MARK: - Command Processing
    
    func processWidgetCommand() -> FocusTimerCommandRaw? {
        guard let defaults = UserDefaults(suiteName: LiveActivityManager.appGroupIdentifier),
              let rawValue = defaults.string(forKey: LiveActivityManager.commandKey) else {
            return nil
        }
        
        defaults.removeObject(forKey: LiveActivityManager.commandKey)
        return FocusTimerCommandRaw(rawValue: rawValue)
    }
    
    // MARK: - App Group Shared State
    
    private func writeSharedState(timerState: FocusTimerStateRaw) {
        guard let defaults = UserDefaults(suiteName: LiveActivityManager.appGroupIdentifier) else {
            return
        }
        
        let timeRemaining = timerManager.remainingSeconds
        let habitId = timerManager.activeHabit?.id.uuidString
        let habitName = timerManager.activeHabit?.name ?? "Focus Session"
        
        let state = SharedFocusTimerState(
            isActive: timeRemaining > 0,
            habitId: habitId,
            habitName: habitName,
            timeRemaining: timeRemaining,
            timerState: timerState.rawValue,
            lastUpdated: Date()
        )
        
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: LiveActivityManager.stateKey)
        }
    }
    
    private func clearSharedState() {
        guard let defaults = UserDefaults(suiteName: LiveActivityManager.appGroupIdentifier) else { return }
        defaults.removeObject(forKey: LiveActivityManager.stateKey)
        defaults.removeObject(forKey: LiveActivityManager.commandKey)
    }
    
    private func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusTimerWidget")
    }
    
    private func log(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [LiveActivityManager] \(message)")
        #endif
    }
}

// MARK: - Internal Types for App Group Communication

enum FocusTimerStateRaw: String, Codable {
    case running
    case paused
    case breakTime
    case finished
}

enum FocusTimerCommandRaw: String, Codable {
    case start
    case pause
    case resume
    case stop
}

struct SharedFocusTimerState: Codable {
    let isActive: Bool
    let habitId: String?
    let habitName: String
    let timeRemaining: Int
    let timerState: String
    let lastUpdated: Date
}
#endif

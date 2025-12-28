import Foundation
import WidgetKit

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
final class LiveActivityManager: @unchecked Sendable {
    
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<FitLinkLiveActivityAttributes>?
    private var currentHabitId: String?
    private var currentHabitName: String?
    
    private static let appGroupIdentifier = "group.com.edgetr.FitLink"
    private static let stateKey = "focusTimerState"
    private static let commandKey = "focusTimerCommand"
    
    private init() {}
    
    var isActivityActive: Bool {
        currentActivity != nil && currentActivity?.activityState != .ended
    }
    
    // MARK: - Focus Activity
    
    func startFocusActivity(habitId: String, habitName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            log("Live Activities are not enabled")
            return
        }
        
        endCurrentActivity()
        
        currentHabitId = habitId
        currentHabitName = habitName
        
        let attributes = FitLinkLiveActivityAttributes(
            habitId: habitId,
            habitName: habitName
        )
        
        let initialState = FitLinkLiveActivityAttributes.ContentState.initialFocusState()
        
        do {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: initialState, staleDate: nil)
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
            
            writeSharedState(
                isActive: true,
                timeRemaining: 25 * 60,
                timerState: .running
            )
            reloadWidgets()
            
            log("Started Live Activity for habit: \(habitName)")
        } catch {
            log("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }
    
    func updateActivity(timeRemaining: Int, isRunning: Bool, isOnBreak: Bool) {
        guard let activity = currentActivity else { return }
        
        let timerState: FitLinkLiveActivityAttributes.TimerState
        let sharedTimerState: FocusTimerStateRaw
        let emoji: String
        
        if timeRemaining <= 0 {
            timerState = .finished
            sharedTimerState = .finished
            emoji = "✅"
        } else if isOnBreak {
            timerState = .breakTime
            sharedTimerState = .breakTime
            emoji = "☕️"
        } else if isRunning {
            timerState = .running
            sharedTimerState = .running
            emoji = "🧠"
        } else {
            timerState = .paused
            sharedTimerState = .paused
            emoji = "⏸️"
        }
        
        let newState = FitLinkLiveActivityAttributes.ContentState(
            timerState: timerState,
            timeRemaining: max(0, timeRemaining),
            emoji: emoji
        )
        
        Task {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: newState, staleDate: nil)
                await activity.update(content)
            } else {
                await activity.update(using: newState)
            }
        }
        
        writeSharedState(
            isActive: timeRemaining > 0,
            timeRemaining: timeRemaining,
            timerState: sharedTimerState
        )
    }
    
    func startBreak(timeRemaining: Int = 5 * 60) {
        guard let activity = currentActivity else { return }
        
        let breakState = FitLinkLiveActivityAttributes.ContentState.breakState(timeRemaining: timeRemaining)
        
        Task {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: breakState, staleDate: nil)
                await activity.update(content)
            } else {
                await activity.update(using: breakState)
            }
        }
        
        writeSharedState(
            isActive: true,
            timeRemaining: timeRemaining,
            timerState: .breakTime
        )
        
        log("Updated Live Activity to break state")
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
        currentHabitId = nil
        currentHabitName = nil
        
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
        currentHabitId = nil
        currentHabitName = nil
        
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
    
    private func writeSharedState(isActive: Bool, timeRemaining: Int, timerState: FocusTimerStateRaw) {
        guard let defaults = UserDefaults(suiteName: LiveActivityManager.appGroupIdentifier) else {
            return
        }
        
        let state = SharedFocusTimerState(
            isActive: isActive,
            habitId: currentHabitId,
            habitName: currentHabitName ?? "Focus Session",
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

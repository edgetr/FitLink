import Foundation

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
final class LiveActivityManager: @unchecked Sendable {
    
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<FitLinkLiveActivityAttributes>?
    
    private init() {}
    
    var isActivityActive: Bool {
        currentActivity != nil && currentActivity?.activityState != .ended
    }
    
    func startFocusActivity(habitId: String, habitName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            log("Live Activities are not enabled")
            return
        }
        
        endCurrentActivity()
        
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
            log("Started Live Activity for habit: \(habitName)")
        } catch {
            log("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }
    
    func updateActivity(timeRemaining: Int, isRunning: Bool, isOnBreak: Bool) {
        guard let activity = currentActivity else { return }
        
        let timerState: FitLinkLiveActivityAttributes.TimerState
        let emoji: String
        
        if timeRemaining <= 0 {
            timerState = .finished
            emoji = "✅"
        } else if isOnBreak {
            timerState = .breakTime
            emoji = "☕️"
        } else if isRunning {
            timerState = .running
            emoji = "🧠"
        } else {
            timerState = .paused
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
        log("Ended all Live Activities")
    }
    
    private func log(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [LiveActivityManager] \(message)")
        #endif
    }
}
#endif

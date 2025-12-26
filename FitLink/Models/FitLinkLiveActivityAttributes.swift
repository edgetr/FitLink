import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Activity Attributes for the Focus Timer Live Activity
/// This model is shared between the main app and the Widget Extension
@available(iOS 16.1, *)
struct FitLinkLiveActivityAttributes: ActivityAttributes {
    
    /// Dynamic state that updates during the Live Activity
    public struct ContentState: Codable, Hashable {
        /// Current timer state
        var timerState: TimerState
        /// Time remaining in seconds
        var timeRemaining: Int
        /// Emoji to display in minimal Dynamic Island view
        var emoji: String
        
        /// Formatted time string (MM:SS)
        var formattedTime: String {
            let minutes = timeRemaining / 60
            let seconds = timeRemaining % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
        
        /// Progress percentage (0.0 - 1.0)
        var progress: Double {
            let totalTime: Double
            switch timerState {
            case .running, .paused, .finished:
                totalTime = 25 * 60 // 25 minutes focus session
            case .breakTime:
                totalTime = 5 * 60 // 5 minutes break
            }
            return max(0, min(1, 1.0 - (Double(timeRemaining) / totalTime)))
        }
        
        /// Creates an initial running state for a focus session
        static func initialFocusState() -> ContentState {
            ContentState(
                timerState: .running,
                timeRemaining: 25 * 60,
                emoji: "🧠"
            )
        }
        
        /// Creates a break state
        static func breakState(timeRemaining: Int = 5 * 60) -> ContentState {
            ContentState(
                timerState: .breakTime,
                timeRemaining: timeRemaining,
                emoji: "☕️"
            )
        }
        
        /// Creates a paused state
        static func pausedState(timeRemaining: Int) -> ContentState {
            ContentState(
                timerState: .paused,
                timeRemaining: timeRemaining,
                emoji: "⏸️"
            )
        }
        
        /// Creates a finished state
        static func finishedState() -> ContentState {
            ContentState(
                timerState: .finished,
                timeRemaining: 0,
                emoji: "✅"
            )
        }
    }
    
    /// Timer state enum
    enum TimerState: String, Codable, Hashable {
        case running
        case paused
        case finished
        case breakTime
        
        var displayName: String {
            switch self {
            case .running: return "Focus"
            case .paused: return "Paused"
            case .finished: return "Done!"
            case .breakTime: return "Break"
            }
        }
        
        var icon: String {
            switch self {
            case .running: return "brain.head.profile"
            case .paused: return "pause.fill"
            case .finished: return "checkmark.circle.fill"
            case .breakTime: return "cup.and.saucer.fill"
            }
        }
        
        var tintColor: String {
            switch self {
            case .running: return "cyan"
            case .paused: return "orange"
            case .finished: return "green"
            case .breakTime: return "blue"
            }
        }
    }
    
    // MARK: - Static Properties (don't change during activity)
    
    /// The habit ID being focused on
    var habitId: String
    
    /// The habit name for display
    var habitName: String
}
#endif

import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Activity Attributes for the Focus Timer Live Activity
/// This model is shared between the main app and the Widget Extension
@available(iOS 16.1, *)
struct FitLinkLiveActivityAttributes: ActivityAttributes {
    
    public struct ContentState: Codable, Hashable {
        var timerState: TimerState
        var timeRemaining: Int
        var totalTime: Int
        var emoji: String
        
        // Date-based timer for real-time countdown via Text(timerInterval:)
        var timerEndDate: Date?
        var timerStartDate: Date?
        
        var timerRange: ClosedRange<Date>? {
            guard let start = timerStartDate, let end = timerEndDate else { return nil }
            guard start < end else { return nil }
            return start...end
        }
        
        var formattedTime: String {
            let minutes = timeRemaining / 60
            let seconds = timeRemaining % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
        
        var progress: Double {
            guard totalTime > 0 else { return 0 }
            return max(0, min(1, 1.0 - (Double(timeRemaining) / Double(totalTime))))
        }
        
        // MARK: - Factory Methods
        
        static func initialFocusState(totalTime: Int = 25 * 60, startDate: Date = Date()) -> ContentState {
            ContentState(
                timerState: .running,
                timeRemaining: totalTime,
                totalTime: totalTime,
                emoji: "🧠",
                timerEndDate: startDate.addingTimeInterval(TimeInterval(totalTime)),
                timerStartDate: startDate
            )
        }
        
        static func breakState(timeRemaining: Int = 5 * 60, startDate: Date = Date()) -> ContentState {
            ContentState(
                timerState: .breakTime,
                timeRemaining: timeRemaining,
                totalTime: timeRemaining,
                emoji: "☕️",
                timerEndDate: startDate.addingTimeInterval(TimeInterval(timeRemaining)),
                timerStartDate: startDate
            )
        }
        
        static func pausedState(timeRemaining: Int, totalTime: Int) -> ContentState {
            ContentState(
                timerState: .paused,
                timeRemaining: timeRemaining,
                totalTime: totalTime,
                emoji: "⏸️",
                timerEndDate: nil,
                timerStartDate: nil
            )
        }
        
        static func finishedState() -> ContentState {
            ContentState(
                timerState: .finished,
                timeRemaining: 0,
                totalTime: 0,
                emoji: "✅",
                timerEndDate: nil,
                timerStartDate: nil
            )
        }
        
        static func runningState(
            timeRemaining: Int,
            totalTime: Int,
            isOnBreak: Bool = false,
            startDate: Date = Date()
        ) -> ContentState {
            ContentState(
                timerState: isOnBreak ? .breakTime : .running,
                timeRemaining: timeRemaining,
                totalTime: totalTime,
                emoji: isOnBreak ? "☕️" : "🧠",
                timerEndDate: startDate.addingTimeInterval(TimeInterval(timeRemaining)),
                timerStartDate: startDate
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
    
    // MARK: - Static Properties
    
    var habitId: String
    var habitName: String
    var habitIcon: String
}
#endif

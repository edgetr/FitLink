import AppIntents
import SwiftUI

// MARK: - Start Focus Timer Intent

struct StartFocusTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Focus Timer"
    static var description = IntentDescription("Start a focus timer session for deep work")
    
    static var openAppWhenRun: Bool = false
    
    @Parameter(
        title: "Duration (minutes)",
        description: "How long to focus",
        default: 25,
        inclusiveRange: (1, 180)
    )
    var durationMinutes: Int
    
    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$durationMinutes) minute focus session")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let manager = FocusTimerManager.shared
        
        // Check if already running
        if manager.isActive {
            let minutesLeft = manager.remainingSeconds / 60
            let habitName = manager.activeHabit?.name ?? "Focus"
            
            return .result(
                dialog: "You already have a \(habitName) session running with \(minutesLeft) minutes left."
            ) {
                FocusTimerSnippetView(
                    timeRemaining: manager.remainingSeconds,
                    totalTime: manager.totalSeconds,
                    state: manager.isPaused ? .paused : .running,
                    habitName: habitName
                )
            }
        }
        
        // Create a generic focus habit for Siri-initiated sessions
        let focusHabit = Habit(
            name: "Focus Session",
            icon: "brain.head.profile",
            category: .productivity,
            suggestedDurationMinutes: durationMinutes
        )
        
        // Start the timer
        manager.startTimer(for: focusHabit, durationMinutes: durationMinutes)
        
        return .result(
            dialog: "Started \(durationMinutes) minute focus session. Stay focused!"
        ) {
            FocusTimerSnippetView(
                timeRemaining: durationMinutes * 60,
                totalTime: durationMinutes * 60,
                state: .running,
                habitName: "Focus Session"
            )
        }
    }
}

// MARK: - Stop Focus Timer Intent

struct StopFocusTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Focus Timer"
    static var description = IntentDescription("Stop the current focus timer session")
    
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = FocusTimerManager.shared
        
        guard manager.isActive || manager.remainingSeconds > 0 else {
            return .result(dialog: "No focus timer is currently running.")
        }
        
        let habitName = manager.activeHabit?.name ?? "Focus"
        let totalFocused = manager.totalSeconds - manager.remainingSeconds
        let minutesFocused = totalFocused / 60
        
        manager.stop()
        
        if minutesFocused > 0 {
            return .result(
                dialog: "Focus session stopped. You focused on \(habitName) for \(minutesFocused) minutes. Great work!"
            )
        } else {
            return .result(dialog: "Focus session stopped.")
        }
    }
}

// MARK: - Pause Focus Timer Intent

struct PauseFocusTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Focus Timer"
    static var description = IntentDescription("Pause the current focus timer")
    
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = FocusTimerManager.shared
        
        guard manager.isActive else {
            if manager.isPaused && manager.remainingSeconds > 0 {
                return .result(dialog: "Focus timer is already paused.")
            }
            return .result(dialog: "No focus timer is currently running.")
        }
        
        if manager.isPaused {
            return .result(dialog: "Focus timer is already paused.")
        }
        
        manager.pause()
        let minutesLeft = manager.remainingSeconds / 60
        
        return .result(
            dialog: "Focus timer paused with \(minutesLeft) minutes remaining."
        )
    }
}

// MARK: - Resume Focus Timer Intent

struct ResumeFocusTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Focus Timer"
    static var description = IntentDescription("Resume a paused focus timer")
    
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = FocusTimerManager.shared
        
        guard manager.isActive else {
            return .result(dialog: "No focus timer to resume. Would you like to start one?")
        }
        
        guard manager.isPaused else {
            return .result(dialog: "Focus timer is already running.")
        }
        
        manager.resume()
        let minutesLeft = manager.remainingSeconds / 60
        
        return .result(
            dialog: "Focus timer resumed. \(minutesLeft) minutes remaining. Let's go!"
        )
    }
}

// MARK: - Get Focus Status Intent

struct GetFocusStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Focus Timer Status"
    static var description = IntentDescription("Check the current focus timer status")
    
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let manager = FocusTimerManager.shared
        
        if manager.isActive && !manager.isPaused {
            let minutesLeft = manager.remainingSeconds / 60
            let secondsLeft = manager.remainingSeconds % 60
            let habitName = manager.activeHabit?.name ?? "Focus"
            let state: FocusTimerSnippetView.TimerDisplayState = manager.isOnBreak ? .onBreak : .running
            
            return .result(
                dialog: "You have \(minutesLeft) minutes and \(secondsLeft) seconds left in your \(habitName) session."
            ) {
                FocusTimerSnippetView(
                    timeRemaining: manager.remainingSeconds,
                    totalTime: manager.totalSeconds,
                    state: state,
                    habitName: habitName
                )
            }
        } else if manager.isPaused && manager.remainingSeconds > 0 {
            let minutesLeft = manager.remainingSeconds / 60
            let habitName = manager.activeHabit?.name ?? "Focus"
            
            return .result(
                dialog: "Focus timer is paused with \(minutesLeft) minutes remaining."
            ) {
                FocusTimerSnippetView(
                    timeRemaining: manager.remainingSeconds,
                    totalTime: manager.totalSeconds,
                    state: .paused,
                    habitName: habitName
                )
            }
        } else {
            return .result(
                dialog: "No focus timer is running. Say 'Start focus timer' to begin."
            ) {
                EmptyTimerSnippetView()
            }
        }
    }
}

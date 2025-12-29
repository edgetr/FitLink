//
//  FitLinkLiveActivityControl.swift
//  FitLinkLiveActivity
//
//  Created by Gökay Ege Süren on 25.12.2025.
//

import AppIntents
import SwiftUI
import WidgetKit

#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Control Widget

struct FitLinkLiveActivityControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.edgetr.FitLink.FocusTimerControl",
            provider: FocusTimerControlProvider()
        ) { value in
            ControlWidgetToggle(
                "Focus Timer",
                isOn: value,
                action: ToggleFocusTimerIntent()
            ) { isRunning in
                Label(isRunning ? "Running" : "Paused", systemImage: isRunning ? "brain.head.profile" : "pause.fill")
            }
        }
        .displayName("Focus Timer")
        .description("Pause or resume your current focus session.")
    }
}

// MARK: - Control Value Provider

extension FitLinkLiveActivityControl {
    struct FocusTimerControlProvider: ControlValueProvider {
        var previewValue: Bool {
            true
        }

        func currentValue() async throws -> Bool {
            guard let state = FocusTimerSharedState.read() else {
                return false
            }
            return state.isActive && state.timerState == .running
        }
    }
}

// MARK: - Toggle Intent

struct ToggleFocusTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle Focus Timer"

    @Parameter(title: "Timer is running")
    var value: Bool

    func perform() async throws -> some IntentResult {
        if value {
            FocusTimerCommand.resume.write()
        } else {
            FocusTimerCommand.pause.write()
        }
        
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusTimerWidget")
        
        return .result()
    }
}

// MARK: - Stop Focus Intent

struct StopFocusTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Focus Timer"
    static let description = IntentDescription("Stops the current focus session")
    
    func perform() async throws -> some IntentResult {
        FocusTimerCommand.stop.write()
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusTimerWidget")
        return .result()
    }
}

// MARK: - LiveActivityIntent Implementations for Dynamic Island Buttons

@available(iOS 17.0, *)
struct EndFocusSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End Focus Session"
    static var description = IntentDescription("Ends the current focus session immediately")
    static var openAppWhenRun: Bool { true }
    
    func perform() async throws -> some IntentResult {
        print("[EndFocusSessionIntent] perform() called")
        
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            for activity in Activity<FitLinkLiveActivityAttributes>.activities {
                print("[EndFocusSessionIntent] Ending activity: \(activity.id)")
                let finalState = FitLinkLiveActivityAttributes.ContentState.finishedState()
                let content = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(content, dismissalPolicy: .immediate)
            }
        }
        #endif
        
        FocusTimerCommand.stop.write()
        print("[EndFocusSessionIntent] Command written: stop")
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusTimerWidget")
        
        return .result()
    }
}

@available(iOS 17.0, *)
struct PauseFocusSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause Focus Session"
    static var description = IntentDescription("Pauses the current focus session")
    static var openAppWhenRun: Bool { true }
    
    func perform() async throws -> some IntentResult {
        print("[PauseFocusSessionIntent] perform() called")
        
        FocusTimerCommand.pause.write()
        print("[PauseFocusSessionIntent] Command written: pause")
        
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *),
           let state = FocusTimerSharedState.read() {
            print("[PauseFocusSessionIntent] Read state: timeRemaining=\(state.timeRemaining)")
            for activity in Activity<FitLinkLiveActivityAttributes>.activities {
                print("[PauseFocusSessionIntent] Updating activity: \(activity.id)")
                let pausedState = FitLinkLiveActivityAttributes.ContentState.pausedState(
                    timeRemaining: state.timeRemaining,
                    totalTime: state.timeRemaining
                )
                let content = ActivityContent(state: pausedState, staleDate: nil)
                await activity.update(content)
            }
        } else {
            print("[PauseFocusSessionIntent] Could not read shared state")
        }
        #endif
        
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusTimerWidget")
        return .result()
    }
}

@available(iOS 17.0, *)
struct ResumeFocusSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Resume Focus Session"
    static var description = IntentDescription("Resumes the paused focus session")
    static var openAppWhenRun: Bool { true }
    
    func perform() async throws -> some IntentResult {
        print("[ResumeFocusSessionIntent] perform() called")
        
        FocusTimerCommand.resume.write()
        print("[ResumeFocusSessionIntent] Command written: resume")
        
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *),
           let state = FocusTimerSharedState.read() {
            print("[ResumeFocusSessionIntent] Read state: timeRemaining=\(state.timeRemaining)")
            for activity in Activity<FitLinkLiveActivityAttributes>.activities {
                print("[ResumeFocusSessionIntent] Updating activity: \(activity.id)")
                let runningState = FitLinkLiveActivityAttributes.ContentState.runningState(
                    timeRemaining: state.timeRemaining,
                    totalTime: state.timeRemaining,
                    isOnBreak: state.timerState == .breakTime
                )
                let content = ActivityContent(state: runningState, staleDate: Date().addingTimeInterval(TimeInterval(state.timeRemaining + 300)))
                await activity.update(content)
            }
        } else {
            print("[ResumeFocusSessionIntent] Could not read shared state")
        }
        #endif
        
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusTimerWidget")
        return .result()
    }
}

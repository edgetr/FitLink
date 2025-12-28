//
//  FitLinkLiveActivityControl.swift
//  FitLinkLiveActivity
//
//  Created by Gökay Ege Süren on 25.12.2025.
//

import AppIntents
import SwiftUI
import WidgetKit

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

//
//  FitLinkLiveActivityLiveActivity.swift
//  FitLinkLiveActivity
//
//  Created by Gökay Ege Süren on 25.12.2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

// FitLinkLiveActivityAttributes is defined in FitLink/Models/FitLinkLiveActivityAttributes.swift
// That file must be added to the FitLinkLiveActivityExtension target in Xcode.

// MARK: - Live Activity Widget

struct FitLinkLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FitLinkLiveActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            LockScreenView(context: context)
                .activityBackgroundTint(Color.cyan.opacity(0.8))
                .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Image(systemName: context.state.timerState.icon)
                            .font(.title2)
                        Text(context.attributes.habitName)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text(context.state.formattedTime)
                            .font(.title2.monospacedDigit())
                            .fontWeight(.bold)
                        Text(context.state.timerState.displayName)
                            .font(.caption)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progress)
                        .tint(timerColor(for: context.state.timerState))
                        .padding(.horizontal)
                }
            } compactLeading: {
                Image(systemName: context.state.timerState.icon)
                    .foregroundColor(timerColor(for: context.state.timerState))
            } compactTrailing: {
                Text(context.state.formattedTime)
                    .font(.caption.monospacedDigit())
                    .fontWeight(.semibold)
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "fitlink://focus"))
            .keylineTint(timerColor(for: context.state.timerState))
        }
    }
    
    private func timerColor(for state: FitLinkLiveActivityAttributes.TimerState) -> Color {
        switch state {
        case .running: return .cyan
        case .paused: return .orange
        case .finished: return .green
        case .breakTime: return .blue
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<FitLinkLiveActivityAttributes>
    
    var body: some View {
        HStack(spacing: 16) {
            // Timer icon
            Image(systemName: context.state.timerState.icon)
                .font(.largeTitle)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.habitName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(context.state.timerState.displayName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Time remaining
            Text(context.state.formattedTime)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding()
    }
}

// MARK: - Preview Helpers

extension FitLinkLiveActivityAttributes {
    fileprivate static var preview: FitLinkLiveActivityAttributes {
        FitLinkLiveActivityAttributes(habitId: "preview", habitName: "Focus Session")
    }
}

extension FitLinkLiveActivityAttributes.ContentState {
    fileprivate static var running: FitLinkLiveActivityAttributes.ContentState {
        .initialFocusState()
    }
    
    fileprivate static var paused: FitLinkLiveActivityAttributes.ContentState {
        .pausedState(timeRemaining: 15 * 60)
    }
    
    fileprivate static var onBreak: FitLinkLiveActivityAttributes.ContentState {
        .breakState()
    }
}

#Preview("Notification", as: .content, using: FitLinkLiveActivityAttributes.preview) {
    FitLinkLiveActivityLiveActivity()
} contentStates: {
    FitLinkLiveActivityAttributes.ContentState.running
    FitLinkLiveActivityAttributes.ContentState.paused
    FitLinkLiveActivityAttributes.ContentState.onBreak
}

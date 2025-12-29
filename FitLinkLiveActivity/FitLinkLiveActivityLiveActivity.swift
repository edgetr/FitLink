//
//  FitLinkLiveActivityLiveActivity.swift
//  FitLinkLiveActivity
//
//  Created by Gökay Ege Süren on 25.12.2025.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

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
                    VStack(alignment: .trailing, spacing: 4) {
                        if let range = context.state.timerRange, context.state.timerState == .running || context.state.timerState == .breakTime {
                            Text(timerInterval: range, countsDown: true)
                                .font(.title2.monospacedDigit())
                                .fontWeight(.bold)
                                .contentTransition(.numericText())
                        } else {
                            Text(context.state.formattedTime)
                                .font(.title2.monospacedDigit())
                                .fontWeight(.bold)
                        }
                        Text(context.state.timerState.displayName)
                            .font(.caption)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        ProgressView(value: context.state.progress)
                            .tint(timerColor(for: context.state.timerState))
                        
                        if #available(iOS 17.0, *) {
                            HStack(spacing: 12) {
                                if context.state.timerState == .running || context.state.timerState == .breakTime {
                                    Button(intent: PauseFocusSessionIntent()) {
                                        Image(systemName: "pause.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.orange)
                                            .frame(width: 36, height: 36)
                                            .background(
                                                Circle()
                                                    .fill(.ultraThinMaterial)
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                } else if context.state.timerState == .paused {
                                    Button(intent: ResumeFocusSessionIntent()) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.green)
                                            .frame(width: 36, height: 36)
                                            .background(
                                                Circle()
                                                    .fill(.ultraThinMaterial)
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Button(intent: EndFocusSessionIntent()) {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.red)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.timerState.icon)
                    .foregroundColor(timerColor(for: context.state.timerState))
                    .font(.caption2)
            } compactTrailing: {
                if let range = context.state.timerRange, context.state.timerState == .running || context.state.timerState == .breakTime {
                    Text(timerInterval: range, countsDown: true)
                        .font(.caption2.monospacedDigit())
                        .fontWeight(.medium)
                        .contentTransition(.numericText())
                        .frame(minWidth: 40)
                } else {
                    Text(context.state.formattedTime)
                        .font(.caption2.monospacedDigit())
                        .fontWeight(.medium)
                        .frame(minWidth: 40)
                }
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
            
            if let range = context.state.timerRange, context.state.timerState == .running || context.state.timerState == .breakTime {
                Text(timerInterval: range, countsDown: true)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
            } else {
                Text(context.state.formattedTime)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
}

// MARK: - Preview Helpers

extension FitLinkLiveActivityAttributes {
    fileprivate static var preview: FitLinkLiveActivityAttributes {
        FitLinkLiveActivityAttributes(
            habitId: "preview",
            habitName: "Focus Session",
            habitIcon: "brain.head.profile"
        )
    }
}

extension FitLinkLiveActivityAttributes.ContentState {
    fileprivate static var running: FitLinkLiveActivityAttributes.ContentState {
        .initialFocusState(totalTime: 25 * 60)
    }
    
    fileprivate static var paused: FitLinkLiveActivityAttributes.ContentState {
        .pausedState(timeRemaining: 15 * 60, totalTime: 25 * 60)
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

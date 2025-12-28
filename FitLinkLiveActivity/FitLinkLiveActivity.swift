//
//  FitLinkLiveActivity.swift
//  FitLinkLiveActivity
//
//  Created by Gökay Ege Süren on 25.12.2025.
//

import WidgetKit
import SwiftUI

// MARK: - Focus Timer Widget

struct FocusTimerWidget: Widget {
    let kind: String = "FocusTimerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusTimerProvider()) { entry in
            if #available(iOS 17.0, *) {
                FocusTimerWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                FocusTimerWidgetView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Focus Timer")
        .description("Track your current focus session at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Provider

struct FocusTimerProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> FocusTimerEntry {
        FocusTimerEntry(
            date: Date(),
            isSessionActive: true,
            habitName: "Focus Session",
            timeRemaining: 25 * 60,
            timerState: .running
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusTimerEntry) -> ()) {
        let entry = createEntry(from: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let entry = createEntry(from: currentDate)
        
        let refreshInterval: TimeInterval = entry.isSessionActive ? 30 : 300
        let nextUpdate = currentDate.addingTimeInterval(refreshInterval)
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func createEntry(from date: Date) -> FocusTimerEntry {
        let state = FocusTimerSharedState.read()
        
        if let state = state, state.isActive {
            let elapsed = date.timeIntervalSince(state.lastUpdated)
            let adjustedTime = max(0, state.timeRemaining - Int(elapsed))
            
            return FocusTimerEntry(
                date: date,
                isSessionActive: true,
                habitName: state.habitName,
                timeRemaining: adjustedTime,
                timerState: state.timerState
            )
        }
        
        return FocusTimerEntry(
            date: date,
            isSessionActive: false,
            habitName: nil,
            timeRemaining: 0,
            timerState: .paused
        )
    }
}

// MARK: - Timeline Entry

struct FocusTimerEntry: TimelineEntry {
    let date: Date
    let isSessionActive: Bool
    let habitName: String?
    let timeRemaining: Int
    let timerState: FocusTimerState
    
    var formattedTime: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Widget View

struct FocusTimerWidgetView: View {
    var entry: FocusTimerEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        if entry.isSessionActive {
            activeSessionView
        } else {
            inactiveView
        }
    }
    
    private var activeSessionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: entry.timerState.icon)
                    .font(.title3)
                    .foregroundColor(entry.timerState.color)
                
                if family == .systemMedium {
                    Text(entry.habitName ?? "Focus Session")
                        .font(.headline)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(entry.timerState.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(entry.formattedTime)
                .font(.system(size: family == .systemMedium ? 40 : 32, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
            
            if family == .systemMedium, let name = entry.habitName {
                Text(name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "fitlink://focus"))
    }
    
    private var inactiveView: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Active Session")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if family == .systemMedium {
                Text("Start a focus session from the Habit Tracker")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "fitlink://habits"))
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    FocusTimerWidget()
} timeline: {
    FocusTimerEntry(date: .now, isSessionActive: true, habitName: "Deep Work", timeRemaining: 15 * 60, timerState: .running)
    FocusTimerEntry(date: .now, isSessionActive: true, habitName: "Reading", timeRemaining: 5 * 60, timerState: .breakTime)
    FocusTimerEntry(date: .now, isSessionActive: false, habitName: nil, timeRemaining: 0, timerState: .paused)
}

#Preview(as: .systemMedium) {
    FocusTimerWidget()
} timeline: {
    FocusTimerEntry(date: .now, isSessionActive: true, habitName: "Deep Work Session", timeRemaining: 15 * 60, timerState: .running)
    FocusTimerEntry(date: .now, isSessionActive: false, habitName: nil, timeRemaining: 0, timerState: .paused)
}

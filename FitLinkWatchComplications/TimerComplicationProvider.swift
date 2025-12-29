import WidgetKit
import SwiftUI

#if os(watchOS)

struct TimerEntry: TimelineEntry {
    let date: Date
    let timerState: TimerSyncState?
    let isPlaceholder: Bool
    
    var isActive: Bool { timerState?.isActive ?? false }
    var isPaused: Bool { timerState?.isPaused ?? false }
    var remainingSeconds: Int { timerState?.remainingSeconds ?? 0 }
    var habitName: String { timerState?.habitName ?? "Focus" }
    
    static let placeholder = TimerEntry(
        date: Date(),
        timerState: TimerSyncState(
            isActive: true,
            isPaused: false,
            isOnBreak: false,
            remainingSeconds: 15 * 60,
            totalSeconds: 25 * 60,
            habitId: nil,
            habitName: "Focus Session",
            habitIcon: "brain.head.profile",
            endDate: Date().addingTimeInterval(15 * 60)
        ),
        isPlaceholder: true
    )
    
    static let idle = TimerEntry(
        date: Date(),
        timerState: nil,
        isPlaceholder: false
    )
}

struct TimerComplicationProvider: TimelineProvider {
    
    private let defaults = UserDefaults(suiteName: WatchSyncConstants.appGroupIdentifier)
    
    func placeholder(in context: Context) -> TimerEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TimerEntry) -> Void) {
        let timerState = loadTimerState()
        completion(TimerEntry(date: Date(), timerState: timerState, isPlaceholder: false))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerEntry>) -> Void) {
        let timerState = loadTimerState()
        let entry = TimerEntry(date: Date(), timerState: timerState, isPlaceholder: false)
        
        let refreshDate: Date
        if let state = timerState, state.isActive, !state.isPaused, let endDate = state.endDate {
            refreshDate = min(endDate, Date().addingTimeInterval(60))
        } else {
            refreshDate = Date().addingTimeInterval(15 * 60)
        }
        
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
    
    private func loadTimerState() -> TimerSyncState? {
        guard let data = defaults?.data(forKey: WatchSyncConstants.cachedStateKey),
              let payload = try? JSONDecoder().decode(WatchSyncPayload.self, from: data) else {
            return nil
        }
        return payload.timerState
    }
}

struct TimerComplication: Widget {
    let kind: String = "TimerComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimerComplicationProvider()) { entry in
            TimerComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Focus Timer")
        .description("Shows your current focus timer status.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct TimerComplicationEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: TimerEntry
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }
    
    private var circularView: some View {
        ZStack {
            if entry.isActive {
                AccessoryWidgetBackground()
                
                if !entry.isPaused, let endDate = entry.timerState?.endDate {
                    ProgressView(
                        timerInterval: Date()...endDate,
                        countsDown: true,
                        label: { EmptyView() },
                        currentValueLabel: {
                            Image(systemName: "brain.head.profile")
                                .font(.caption)
                        }
                    )
                    .progressViewStyle(.circular)
                    .tint(.cyan)
                } else {
                    VStack(spacing: 2) {
                        Image(systemName: "pause.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Text(formattedTime)
                            .font(.system(.caption2, design: .rounded))
                            .fontWeight(.semibold)
                    }
                }
            } else {
                AccessoryWidgetBackground()
                
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var rectangularView: some View {
        HStack {
            Image(systemName: entry.isActive ? "brain.head.profile" : "brain.head.profile")
                .font(.title2)
                .foregroundColor(entry.isActive ? .cyan : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                if entry.isActive {
                    Text(entry.habitName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if entry.isPaused {
                        Text("Paused · \(formattedTime)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else if let endDate = entry.timerState?.endDate {
                        Text(timerInterval: Date()...endDate, countsDown: true)
                            .font(.caption)
                            .monospacedDigit()
                    }
                } else {
                    Text("No Active Timer")
                        .font(.headline)
                    
                    Text("Tap to start focus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private var inlineView: some View {
        HStack(spacing: 4) {
            if entry.isActive {
                Image(systemName: entry.isPaused ? "pause.fill" : "brain.head.profile")
                
                if entry.isPaused {
                    Text("Paused \(formattedTime)")
                } else if let endDate = entry.timerState?.endDate {
                    Text(timerInterval: Date()...endDate, countsDown: true)
                }
            } else {
                Image(systemName: "brain.head.profile")
                Text("No timer")
            }
        }
    }
    
    private var formattedTime: String {
        let minutes = entry.remainingSeconds / 60
        let seconds = entry.remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#endif

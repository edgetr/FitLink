import WidgetKit
import SwiftUI

#if os(watchOS)

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let habitName: String?
    let isPlaceholder: Bool
    
    static let placeholder = StreakEntry(
        date: Date(),
        streak: 7,
        habitName: nil,
        isPlaceholder: true
    )
}

struct StreakComplicationProvider: TimelineProvider {
    
    private let defaults = UserDefaults(suiteName: WatchSyncConstants.appGroupIdentifier)
    
    func placeholder(in context: Context) -> StreakEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        let (streak, habitName) = loadStreakData()
        completion(StreakEntry(date: Date(), streak: streak, habitName: habitName, isPlaceholder: false))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let (streak, habitName) = loadStreakData()
        let entry = StreakEntry(date: Date(), streak: streak, habitName: habitName, isPlaceholder: false)
        
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date())!)
        
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }
    
    private func loadStreakData() -> (Int, String?) {
        guard let data = defaults?.data(forKey: WatchSyncConstants.cachedStateKey),
              let payload = try? JSONDecoder().decode(WatchSyncPayload.self, from: data) else {
            return (0, nil)
        }
        
        if let topHabit = payload.habits.max(by: { $0.currentStreak < $1.currentStreak }) {
            return (topHabit.currentStreak, topHabit.name)
        }
        
        return (0, nil)
    }
}

struct StreakComplication: Widget {
    let kind: String = "StreakComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakComplicationProvider()) { entry in
            StreakComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Habit Streak")
        .description("Shows your current habit streak.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

struct StreakComplicationEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: StreakEntry
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        case .accessoryCorner:
            cornerView
        default:
            circularView
        }
    }
    
    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                Text("\(entry.streak)")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
            }
        }
    }
    
    private var rectangularView: some View {
        HStack {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.streak) day streak")
                    .font(.headline)
                
                if let habitName = entry.habitName {
                    Text(habitName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
    }
    
    private var inlineView: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
            Text("\(entry.streak) day streak")
        }
    }
    
    private var cornerView: some View {
        Text("\(entry.streak)")
            .font(.system(.title2, design: .rounded))
            .fontWeight(.bold)
            .widgetLabel {
                Image(systemName: "flame.fill")
            }
    }
}

#endif

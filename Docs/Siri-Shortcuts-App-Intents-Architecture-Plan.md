# Siri Shortcuts & App Intents Architecture Plan for FitLink

## Executive Summary

This document provides a comprehensive implementation plan for Siri Shortcuts and App Intents integration in FitLink. The integration enables voice commands ("Hey Siri, start my focus timer"), Shortcuts app automation, Spotlight suggestions, and parameterized intents.

**Key Features:**
- Voice-controlled Focus Timer (start/stop/pause/resume with duration)
- Habit logging and streak queries via Siri
- Health metrics queries (steps, calories, summary)
- Full Shortcuts app integration for automations
- Visual Siri responses with SwiftUI snippet views

**Target:** iOS 16+ (App Intents framework)
**Timeline:** 4 weeks
**Dependencies:** None (native frameworks only)

## Implementation Status

| Phase | Description | Status |
|-------|-------------|--------|
| Phase 1 | Focus Timer Intents | COMPLETE |
| Phase 2 | Habit Intents | COMPLETE |
| Phase 3 | Health Query Intents | COMPLETE |
| Phase 4 | Full AppShortcutsProvider | COMPLETE |

**Last Updated:** 2025-12-29
**Build Status:** SUCCEEDED

### Files Created

```
FitLink/Intents/
├── AppShortcuts.swift                    # AppShortcutsProvider (10 voice shortcuts)
├── FocusTimer/
│   ├── FocusTimerIntents.swift          # 5 intents: Start, Stop, Pause, Resume, Status
│   └── FocusTimerSnippetViews.swift     # Timer visual responses
├── Habits/
│   ├── HabitEntity.swift                # AppEntity for habit selection
│   ├── HabitIntents.swift               # 3 intents: Log, Status, Streak
│   └── HabitSnippetViews.swift          # Habit visual responses
└── Health/
    ├── HealthIntents.swift              # 3 intents: Steps, Calories, Summary
    └── HealthSnippetViews.swift         # Health visual responses
```

### Implementation Notes

- **iOS Shortcut Limit**: Apple limits apps to 10 voice shortcuts. We prioritized Focus Timer (5) + Habits (3) + Health (2). All 11 intents still work in the Shortcuts app.
- **GetCaloriesIntent**: Available in Shortcuts app but not exposed as a voice shortcut to stay within the 10 limit.

---

## 1. User Stories & Voice Commands

### Priority Matrix

| Priority | Feature | Example Voice Commands |
|----------|---------|------------------------|
| **P0** | Start Focus Timer | "Hey Siri, start my focus timer in FitLink" |
| **P0** | Stop Focus Timer | "Hey Siri, stop my focus session in FitLink" |
| **P0** | Pause/Resume Timer | "Hey Siri, pause my focus in FitLink" |
| **P0** | Timer Status | "Hey Siri, how much focus time left in FitLink?" |
| **P1** | Log Habit | "Hey Siri, log my meditation in FitLink" |
| **P1** | Habit Status | "Hey Siri, what habits have I completed in FitLink?" |
| **P1** | Check Streak | "Hey Siri, what's my meditation streak in FitLink?" |
| **P2** | Parameterized Timer | "Hey Siri, start 45 minute focus session in FitLink" |
| **P2** | Get Steps | "Hey Siri, what's my step count in FitLink?" |
| **P2** | Get Calories | "Hey Siri, how many calories burned in FitLink?" |
| **P2** | Health Summary | "Hey Siri, health summary in FitLink" |

---

## 2. Architecture Overview

### App Intents Framework Structure

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         App Intents Layer                                │
│                                                                          │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐       │
│  │ FocusTimerIntents│  │  HabitIntents    │  │  HealthIntents   │       │
│  │                  │  │                  │  │                  │       │
│  │ • StartFocusTimer│  │ • LogHabit       │  │ • GetSteps       │       │
│  │ • StopFocusTimer │  │ • GetHabitStatus │  │ • GetCalories    │       │
│  │ • PauseFocusTimer│  │ • GetStreak      │  │ • GetHealthSum   │       │
│  │ • ResumeFocusTimer│ │                  │  │                  │       │
│  │ • GetFocusStatus │  │                  │  │                  │       │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘       │
│           │                     │                     │                  │
│           └─────────────────────┼─────────────────────┘                  │
│                                 │                                        │
│                    ┌────────────▼────────────┐                           │
│                    │   FitLinkShortcuts      │                           │
│                    │  (AppShortcutsProvider) │                           │
│                    └────────────┬────────────┘                           │
└─────────────────────────────────┼────────────────────────────────────────┘
                                  │
            ┌─────────────────────┼─────────────────────┐
            │                     │                     │
      ┌─────▼─────┐         ┌─────▼─────┐         ┌─────▼─────┐
      │   Siri    │         │ Shortcuts │         │ Spotlight │
      │           │         │    App    │         │           │
      └───────────┘         └───────────┘         └───────────┘
```

### Integration with Existing Services

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          App Intents                                     │
│  StartFocusTimerIntent  │  LogHabitIntent  │  GetStepsIntent            │
└─────────────┬───────────┴────────┬─────────┴────────┬────────────────────┘
              │                    │                  │
              ▼                    ▼                  ▼
┌─────────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐
│ FocusTimerManager   │  │   HabitStore    │  │  HealthDataCollector    │
│ (@MainActor class)  │  │    (actor)      │  │       (actor)           │
│                     │  │                 │  │                         │
│ • startTimer()      │  │ • loadHabits()  │  │ • fetchTodaySteps()     │
│ • pause()           │  │ • saveHabits()  │  │ • fetchTodayCalories()  │
│ • resume()          │  │                 │  │ • fetchExerciseMinutes()│
│ • stop()            │  │                 │  │                         │
└─────────────────────┘  └─────────────────┘  └─────────────────────────┘
```

---

## 3. File Structure

```
FitLink/
├── Intents/
│   ├── FocusTimer/
│   │   ├── FocusTimerIntents.swift        # All focus timer intents
│   │   └── FocusTimerSnippetViews.swift   # SwiftUI snippet views
│   ├── Habits/
│   │   ├── HabitIntents.swift             # All habit intents
│   │   ├── HabitEntity.swift              # AppEntity for habits
│   │   └── HabitSnippetViews.swift        # SwiftUI snippet views
│   ├── Health/
│   │   ├── HealthIntents.swift            # All health query intents
│   │   └── HealthSnippetViews.swift       # SwiftUI snippet views
│   └── AppShortcuts.swift                 # AppShortcutsProvider
├── Services/
│   ├── FocusTimerManager.swift            # (existing - add convenience methods)
│   ├── HabitStore.swift                   # (existing - add intent helpers)
│   └── HealthDataCollector.swift          # (existing - add today queries)
└── FitLinkApp.swift                       # Register shortcuts provider
```

---

## 4. Implementation Plan

### Phase 1: Focus Timer Intents (Week 1)

#### 4.1.1 FocusTimerIntents.swift

```swift
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
    
    @Parameter(
        title: "Habit",
        description: "Optional habit to associate with this session",
        optionsProvider: HabitOptionsProvider()
    )
    var habit: HabitEntity?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$durationMinutes) minute focus session") {
            \.$habit
        }
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
        
        // Start the timer
        let duration = durationMinutes * 60
        manager.startTimer(duration: duration, habitId: habit?.id, habitName: habit?.name ?? "Focus Session")
        
        return .result(
            dialog: "Started \(durationMinutes) minute focus session. Stay focused! 🧠"
        ) {
            FocusTimerSnippetView(
                timeRemaining: duration,
                totalTime: duration,
                state: .running,
                habitName: habit?.name ?? "Focus Session"
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
                dialog: "Focus session stopped. You focused on \(habitName) for \(minutesFocused) minutes. Great work! 💪"
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
            dialog: "Focus timer paused with \(minutesLeft) minutes remaining. ⏸️"
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
            dialog: "Focus timer resumed. \(minutesLeft) minutes remaining. Let's go! ▶️"
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
```

#### 4.1.2 FocusTimerSnippetViews.swift

```swift
import SwiftUI

// MARK: - Focus Timer Snippet View

struct FocusTimerSnippetView: View {
    let timeRemaining: Int
    let totalTime: Int
    let state: TimerDisplayState
    let habitName: String
    
    enum TimerDisplayState {
        case running, paused, onBreak, finished
        
        var icon: String {
            switch self {
            case .running: return "brain.head.profile"
            case .paused: return "pause.circle.fill"
            case .onBreak: return "cup.and.saucer.fill"
            case .finished: return "checkmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .running: return .cyan
            case .paused: return .orange
            case .onBreak: return .blue
            case .finished: return .green
            }
        }
        
        var label: String {
            switch self {
            case .running: return "Focusing"
            case .paused: return "Paused"
            case .onBreak: return "On Break"
            case .finished: return "Complete"
            }
        }
    }
    
    private var progress: Double {
        guard totalTime > 0 else { return 0 }
        return 1.0 - (Double(timeRemaining) / Double(totalTime))
    }
    
    private var formattedTime: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(state.color.opacity(0.2), lineWidth: 6)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(state.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: state.icon)
                    .font(.title2)
                    .foregroundStyle(state.color)
            }
            .frame(width: 56, height: 56)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(habitName)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(formattedTime)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                
                Text(state.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Empty Timer Snippet View

struct EmptyTimerSnippetView: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("No Active Timer")
                    .font(.headline)
                
                Text("Say \"Start focus timer\" to begin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
}
```

---

### Phase 2: Habit Intents (Week 2)

#### 4.2.1 HabitEntity.swift

```swift
import AppIntents

// MARK: - Habit Entity

struct HabitEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"
    
    static var defaultQuery = HabitEntityQuery()
    
    let id: String
    let name: String
    let icon: String
    let category: String
    let currentStreak: Int
    
    var displayRepresentation: DisplayRepresentation {
        var subtitle: String? = nil
        if currentStreak > 0 {
            subtitle = "🔥 \(currentStreak) day streak"
        }
        
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: subtitle.map { LocalizedStringResource(stringLiteral: $0) },
            image: .init(systemName: icon)
        )
    }
    
    init(id: String, name: String, icon: String, category: String = "productivity", currentStreak: Int = 0) {
        self.id = id
        self.name = name
        self.icon = icon
        self.category = category
        self.currentStreak = currentStreak
    }
    
    init(from habit: Habit) {
        self.id = habit.id.uuidString
        self.name = habit.name
        self.icon = habit.icon
        self.category = habit.category.rawValue
        self.currentStreak = habit.currentStreak
    }
}

// MARK: - Habit Entity Query

struct HabitEntityQuery: EntityQuery {
    
    func entities(for identifiers: [String]) async throws -> [HabitEntity] {
        let habits = try await HabitStore.shared.loadHabits(userId: nil)
        return habits
            .filter { identifiers.contains($0.id.uuidString) }
            .map { HabitEntity(from: $0) }
    }
    
    func suggestedEntities() async throws -> [HabitEntity] {
        let habits = try await HabitStore.shared.loadHabits(userId: nil)
        // Prioritize habits with active streaks
        let sorted = habits.sorted { $0.currentStreak > $1.currentStreak }
        return sorted.map { HabitEntity(from: $0) }
    }
    
    func defaultResult() async -> HabitEntity? {
        // Return the habit with the longest streak as default
        let habits = try? await HabitStore.shared.loadHabits(userId: nil)
        guard let topHabit = habits?.max(by: { $0.currentStreak < $1.currentStreak }) else {
            return nil
        }
        return HabitEntity(from: topHabit)
    }
}

// MARK: - Habit Entity String Query (for search)

extension HabitEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [HabitEntity] {
        let habits = try await HabitStore.shared.loadHabits(userId: nil)
        let lowercasedQuery = string.lowercased()
        
        return habits
            .filter { $0.name.lowercased().contains(lowercasedQuery) }
            .map { HabitEntity(from: $0) }
    }
}

// MARK: - Habit Options Provider

struct HabitOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [HabitEntity] {
        let habits = try await HabitStore.shared.loadHabits(userId: nil)
        return habits.map { HabitEntity(from: $0) }
    }
}
```

#### 4.2.2 HabitIntents.swift

```swift
import AppIntents
import SwiftUI

// MARK: - Log Habit Intent

struct LogHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Habit"
    static var description = IntentDescription("Mark a habit as complete for today")
    
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Habit")
    var habit: HabitEntity
    
    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$habit) as complete")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        var habits = try await HabitStore.shared.loadHabits(userId: nil)
        
        guard let index = habits.firstIndex(where: { $0.id.uuidString == habit.id }) else {
            return .result(dialog: "Couldn't find habit '\(habit.name)'. It may have been deleted.") {
                EmptyView()
            }
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        let isAlreadyCompleted = habits[index].completionDates.contains { 
            Calendar.current.isDate($0, inSameDayAs: today) 
        }
        
        if isAlreadyCompleted {
            let streak = habits[index].currentStreak
            return .result(
                dialog: "\(habit.name) is already logged for today! You're on a \(streak)-day streak! 🔥"
            ) {
                HabitCompletionSnippetView(
                    habitName: habit.name,
                    habitIcon: habit.icon,
                    streak: streak,
                    isNewCompletion: false
                )
            }
        }
        
        // Mark as complete
        habits[index].completionDates.append(today)
        try await HabitStore.shared.saveHabits(habits, userId: nil)
        
        let newStreak = habits[index].currentStreak
        let celebrationMessage: String
        
        if newStreak >= 7 {
            celebrationMessage = "Incredible! \(newStreak)-day streak! 🏆"
        } else if newStreak >= 3 {
            celebrationMessage = "Amazing! \(newStreak)-day streak! 🔥"
        } else if newStreak > 1 {
            celebrationMessage = "Nice! \(newStreak) days in a row! ⭐"
        } else {
            celebrationMessage = "Great start! Keep it going! ✨"
        }
        
        return .result(
            dialog: "\(habit.name) logged! \(celebrationMessage)"
        ) {
            HabitCompletionSnippetView(
                habitName: habit.name,
                habitIcon: habit.icon,
                streak: newStreak,
                isNewCompletion: true
            )
        }
    }
}

// MARK: - Get Habit Status Intent

struct GetHabitStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Habit Status"
    static var description = IntentDescription("Check your habit completion status for today")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let habits = try await HabitStore.shared.loadHabits(userId: nil)
        
        guard !habits.isEmpty else {
            return .result(
                dialog: "You haven't set up any habits yet. Open FitLink to create your first habit."
            ) {
                EmptyView()
            }
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        let completed = habits.filter { habit in
            habit.completionDates.contains { Calendar.current.isDate($0, inSameDayAs: today) }
        }
        let remaining = habits.filter { habit in
            !habit.completionDates.contains { Calendar.current.isDate($0, inSameDayAs: today) }
        }
        
        let completedCount = completed.count
        let totalCount = habits.count
        
        let dialog: String
        if completedCount == totalCount {
            dialog = "🎉 Amazing! You've completed all \(totalCount) habits today!"
        } else if completedCount == 0 {
            dialog = "You have \(totalCount) habits to complete today. Let's get started!"
        } else {
            let remainingNames = remaining.prefix(2).map { $0.name }.joined(separator: " and ")
            let moreText = remaining.count > 2 ? " and \(remaining.count - 2) more" : ""
            dialog = "You've completed \(completedCount) of \(totalCount) habits. Still to do: \(remainingNames)\(moreText)."
        }
        
        return .result(dialog: dialog) {
            HabitStatusSnippetView(
                completedCount: completedCount,
                totalCount: totalCount,
                habits: habits
            )
        }
    }
}

// MARK: - Get Streak Intent

struct GetStreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Habit Streak"
    static var description = IntentDescription("Check your current habit streaks")
    
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Habit", optionsProvider: HabitOptionsProvider())
    var habit: HabitEntity?
    
    static var parameterSummary: some ParameterSummary {
        When(\.$habit, .hasAnyValue) {
            Summary("Check streak for \(\.$habit)")
        } otherwise: {
            Summary("Check all habit streaks")
        }
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let habits = try await HabitStore.shared.loadHabits(userId: nil)
        
        if let habitEntity = habit {
            // Specific habit streak
            guard let foundHabit = habits.first(where: { $0.id.uuidString == habitEntity.id }) else {
                return .result(dialog: "Couldn't find that habit.") { EmptyView() }
            }
            
            let streak = foundHabit.currentStreak
            let longestStreak = foundHabit.longestStreak
            
            if streak > 0 {
                return .result(
                    dialog: "Your \(habitEntity.name) streak is \(streak) days! Your longest streak was \(longestStreak) days. 🔥"
                ) {
                    StreakSnippetView(habitName: habitEntity.name, currentStreak: streak, longestStreak: longestStreak)
                }
            } else {
                return .result(
                    dialog: "No active streak for \(habitEntity.name). Complete it today to start one!"
                ) {
                    StreakSnippetView(habitName: habitEntity.name, currentStreak: 0, longestStreak: longestStreak)
                }
            }
        } else {
            // All habits summary
            guard !habits.isEmpty else {
                return .result(dialog: "No habits set up yet.") { EmptyView() }
            }
            
            let activeStreaks = habits.filter { $0.currentStreak > 0 }
            let longestCurrent = habits.map { $0.currentStreak }.max() ?? 0
            let topHabit = habits.max { $0.currentStreak < $1.currentStreak }
            
            if activeStreaks.isEmpty {
                return .result(
                    dialog: "No active streaks right now. Complete a habit today to start building momentum!"
                ) {
                    AllStreaksSnippetView(habits: habits)
                }
            } else {
                return .result(
                    dialog: "You have \(activeStreaks.count) active streak\(activeStreaks.count == 1 ? "" : "s"). Your longest is \(longestCurrent) days for \(topHabit?.name ?? "a habit"). 🔥"
                ) {
                    AllStreaksSnippetView(habits: habits)
                }
            }
        }
    }
}
```

---

### Phase 3: Health Query Intents (Week 3)

#### 4.3.1 HealthIntents.swift

```swift
import AppIntents
import SwiftUI
import HealthKit

// MARK: - Get Steps Intent

struct GetStepsIntent: AppIntent {
    static var title: LocalizedStringResource = "Step Count"
    static var description = IntentDescription("Get your step count for today")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        do {
            let steps = try await HealthKitRepository.shared.fetchTodaySteps()
            let goal = 10_000 // Could be user-configurable
            let percentage = min(100, Int((Double(steps) / Double(goal)) * 100))
            
            let dialog: String
            if steps >= goal {
                dialog = "🎉 You crushed your step goal with \(steps.formatted()) steps today!"
            } else {
                let remaining = goal - steps
                dialog = "You have \(steps.formatted()) steps today. Just \(remaining.formatted()) more to hit your goal!"
            }
            
            return .result(dialog: dialog) {
                HealthMetricSnippetView(
                    title: "Steps",
                    value: steps.formatted(),
                    icon: "figure.walk",
                    color: .green,
                    progress: Double(percentage) / 100,
                    goal: "\(goal.formatted()) goal"
                )
            }
        } catch {
            return .result(
                dialog: "I couldn't get your step count. Make sure Health access is enabled in Settings."
            ) {
                HealthErrorSnippetView(metric: "Steps")
            }
        }
    }
}

// MARK: - Get Calories Intent

struct GetCaloriesIntent: AppIntent {
    static var title: LocalizedStringResource = "Calories Burned"
    static var description = IntentDescription("Get your active calories burned today")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        do {
            let calories = try await HealthKitRepository.shared.fetchTodayActiveCalories()
            let goal = 500 // Could be user-configurable
            let percentage = min(100, Int((calories / Double(goal)) * 100))
            
            let dialog: String
            if Int(calories) >= goal {
                dialog = "🔥 Great work! You've burned \(Int(calories)) active calories today!"
            } else {
                let remaining = goal - Int(calories)
                dialog = "You've burned \(Int(calories)) active calories. \(remaining) more to reach your goal."
            }
            
            return .result(dialog: dialog) {
                HealthMetricSnippetView(
                    title: "Active Calories",
                    value: "\(Int(calories))",
                    icon: "flame.fill",
                    color: .orange,
                    progress: min(1, calories / Double(goal)),
                    goal: "\(goal) kcal goal"
                )
            }
        } catch {
            return .result(
                dialog: "I couldn't get your calorie data. Make sure Health access is enabled."
            ) {
                HealthErrorSnippetView(metric: "Calories")
            }
        }
    }
}

// MARK: - Get Health Summary Intent

struct GetHealthSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Health Summary"
    static var description = IntentDescription("Get an overview of today's health metrics")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        do {
            async let stepsValue = HealthKitRepository.shared.fetchTodaySteps()
            async let caloriesValue = HealthKitRepository.shared.fetchTodayActiveCalories()
            async let exerciseValue = HealthKitRepository.shared.fetchTodayExerciseMinutes()
            
            let (steps, calories, exercise) = try await (stepsValue, caloriesValue, exerciseValue)
            
            return .result(
                dialog: "Today you've taken \(steps.formatted()) steps, burned \(Int(calories)) active calories, and exercised for \(exercise) minutes."
            ) {
                HealthSummarySnippetView(
                    steps: steps,
                    calories: Int(calories),
                    exerciseMinutes: exercise
                )
            }
        } catch {
            return .result(
                dialog: "I couldn't get your health summary. Please check Health permissions in Settings."
            ) {
                HealthErrorSnippetView(metric: "Health Data")
            }
        }
    }
}
```

---

### Phase 4: AppShortcutsProvider (Week 4)

#### 4.4.1 AppShortcuts.swift

```swift
import AppIntents

// MARK: - FitLink Shortcuts Provider

struct FitLinkShortcuts: AppShortcutsProvider {
    
    static var appShortcuts: [AppShortcut] {
        
        // MARK: - Focus Timer Shortcuts
        
        AppShortcut(
            intent: StartFocusTimerIntent(),
            phrases: [
                "Start focus timer in \(.applicationName)",
                "Start my focus session in \(.applicationName)",
                "Begin focus mode with \(.applicationName)",
                "Start \(\.$durationMinutes) minute focus in \(.applicationName)",
                "Focus for \(\.$durationMinutes) minutes with \(.applicationName)",
                "Start focusing in \(.applicationName)"
            ],
            shortTitle: "Start Focus",
            systemImageName: "brain.head.profile"
        )
        
        AppShortcut(
            intent: StopFocusTimerIntent(),
            phrases: [
                "Stop focus timer in \(.applicationName)",
                "End my focus session in \(.applicationName)",
                "Stop focusing in \(.applicationName)",
                "End focus mode in \(.applicationName)"
            ],
            shortTitle: "Stop Focus",
            systemImageName: "stop.circle"
        )
        
        AppShortcut(
            intent: PauseFocusTimerIntent(),
            phrases: [
                "Pause focus timer in \(.applicationName)",
                "Pause my focus session in \(.applicationName)",
                "Take a break in \(.applicationName)"
            ],
            shortTitle: "Pause Focus",
            systemImageName: "pause.circle"
        )
        
        AppShortcut(
            intent: ResumeFocusTimerIntent(),
            phrases: [
                "Resume focus timer in \(.applicationName)",
                "Continue my focus session in \(.applicationName)",
                "Resume focusing in \(.applicationName)"
            ],
            shortTitle: "Resume Focus",
            systemImageName: "play.circle"
        )
        
        AppShortcut(
            intent: GetFocusStatusIntent(),
            phrases: [
                "How much focus time left in \(.applicationName)",
                "Focus timer status in \(.applicationName)",
                "Check my focus session in \(.applicationName)",
                "What's my focus status in \(.applicationName)"
            ],
            shortTitle: "Focus Status",
            systemImageName: "timer"
        )
        
        // MARK: - Habit Shortcuts
        
        AppShortcut(
            intent: LogHabitIntent(),
            phrases: [
                "Log \(\.$habit) in \(.applicationName)",
                "Complete \(\.$habit) in \(.applicationName)",
                "Mark \(\.$habit) done in \(.applicationName)",
                "I did \(\.$habit) in \(.applicationName)",
                "Log my \(\.$habit) habit in \(.applicationName)"
            ],
            shortTitle: "Log Habit",
            systemImageName: "checkmark.circle"
        )
        
        AppShortcut(
            intent: GetHabitStatusIntent(),
            phrases: [
                "What habits have I completed in \(.applicationName)",
                "Habit status in \(.applicationName)",
                "Check my habits in \(.applicationName)",
                "How am I doing with habits in \(.applicationName)",
                "My habits today in \(.applicationName)"
            ],
            shortTitle: "Habit Status",
            systemImageName: "list.bullet.circle"
        )
        
        AppShortcut(
            intent: GetStreakIntent(),
            phrases: [
                "What's my habit streak in \(.applicationName)",
                "Check my streak in \(.applicationName)",
                "How long is my \(\.$habit) streak in \(.applicationName)",
                "My streaks in \(.applicationName)"
            ],
            shortTitle: "Check Streak",
            systemImageName: "flame"
        )
        
        // MARK: - Health Shortcuts
        
        AppShortcut(
            intent: GetStepsIntent(),
            phrases: [
                "What's my step count in \(.applicationName)",
                "How many steps in \(.applicationName)",
                "Steps today in \(.applicationName)",
                "Check my steps in \(.applicationName)"
            ],
            shortTitle: "Step Count",
            systemImageName: "figure.walk"
        )
        
        AppShortcut(
            intent: GetCaloriesIntent(),
            phrases: [
                "How many calories burned in \(.applicationName)",
                "Active calories in \(.applicationName)",
                "Calories today in \(.applicationName)",
                "Check my calories in \(.applicationName)"
            ],
            shortTitle: "Calories Burned",
            systemImageName: "flame.fill"
        )
        
        AppShortcut(
            intent: GetHealthSummaryIntent(),
            phrases: [
                "Health summary in \(.applicationName)",
                "How am I doing today in \(.applicationName)",
                "Today's health in \(.applicationName)",
                "My activity summary in \(.applicationName)"
            ],
            shortTitle: "Health Summary",
            systemImageName: "heart.fill"
        )
    }
}
```

---

## 5. Testing Strategy

### 5.1 Siri Voice Testing

| Test Case | Voice Command | Expected Result |
|-----------|---------------|-----------------|
| Start default timer | "Hey Siri, start focus timer in FitLink" | 25-min timer starts, confirmation dialog |
| Start custom timer | "Hey Siri, start 45 minute focus in FitLink" | 45-min timer starts |
| Stop timer | "Hey Siri, stop focus timer in FitLink" | Timer stops, shows elapsed time |
| Pause timer | "Hey Siri, pause focus in FitLink" | Timer pauses |
| Resume timer | "Hey Siri, resume focus in FitLink" | Timer resumes |
| Timer status | "Hey Siri, how much focus time left in FitLink" | Shows remaining time with snippet |
| Log habit | "Hey Siri, log meditation in FitLink" | Habit marked complete, streak shown |
| Habit status | "Hey Siri, check my habits in FitLink" | Shows completion summary |
| Check streak | "Hey Siri, what's my streak in FitLink" | Shows streak info |
| Get steps | "Hey Siri, steps today in FitLink" | Shows step count with progress |
| Health summary | "Hey Siri, health summary in FitLink" | Shows all metrics |

### 5.2 Shortcuts App Testing

1. Open Shortcuts app
2. Tap "+" to create new shortcut
3. Search "FitLink" - verify all intents appear
4. Test each intent with various parameter combinations
5. Create automations (e.g., "Start focus timer when Focus mode activates")

---

## 6. Timeline & Milestones

| Week | Phase | Deliverables | Effort |
|------|-------|--------------|--------|
| 1 | Focus Timer Intents | `StartFocusTimerIntent`, `StopFocusTimerIntent`, `PauseFocusTimerIntent`, `ResumeFocusTimerIntent`, `GetFocusStatusIntent`, snippet views | Medium (1-2d) |
| 2 | Habit Intents | `HabitEntity`, `HabitEntityQuery`, `LogHabitIntent`, `GetHabitStatusIntent`, `GetStreakIntent`, snippet views | Medium (1-2d) |
| 3 | Health Intents | `GetStepsIntent`, `GetCaloriesIntent`, `GetHealthSummaryIntent`, repository extensions | Short (1-4h) |
| 4 | Integration & Testing | `FitLinkShortcuts` provider, unit tests, Siri testing, documentation | Medium (1-2d) |

**Total Effort:** ~2 weeks active development

---

## 7. Privacy & Security Considerations

### Data Access
- **Health Data**: Intents access HealthKit through existing authorized `HealthDataCollector` actor
- **Habit Data**: Local file storage via `HabitStore` actor, no external network calls
- **Focus Timer**: In-memory state via singleton, persisted to UserDefaults

### Siri Privacy
- No sensitive data (passwords, financial info) exposed via dialog responses
- Habit names and health metrics shown only to authenticated user
- No external API calls during intent execution

### Permissions
- Health intents require existing HealthKit authorization
- No additional permissions needed for Siri/Shortcuts integration

---

## Summary

This architecture enables comprehensive Siri Shortcuts integration for FitLink:

- **11 App Intents** covering Focus Timer, Habits, and Health
- **6 SwiftUI Snippet Views** for rich visual responses
- **Full Shortcuts App integration** with parameterized intents
- **Production-ready code** matching existing FitLink patterns
- **4-week implementation timeline** with clear milestones

The implementation leverages the existing `FocusTimerManager`, `HabitStore`, and `HealthDataCollector` services while adding minimal new code through the App Intents framework.

# Apple Watch Companion App Architecture Plan for FitLink

**Version:** 1.0
**Date:** 2025-12-29
**Status:** Proposed

---

## Table of Contents

1. [Executive Summary & User Stories](#1-executive-summary--user-stories)
2. [Architecture Overview](#2-architecture-overview)
3. [Technical Requirements](#3-technical-requirements)
4. [Implementation Plan](#4-implementation-plan)
5. [Complete Swift Code Examples](#5-complete-swift-code-examples)
6. [File Structure](#6-file-structure)
7. [Data Synchronization Strategy](#7-data-synchronization-strategy)
8. [Testing Strategy](#8-testing-strategy)
9. [Estimated Timeline](#9-estimated-timeline)
10. [Risks & Mitigations](#10-risks--mitigations)

---

## 1. Executive Summary & User Stories

### 1.1 Executive Summary

The FitLink Apple Watch companion app extends the core iOS experience to users' wrists, enabling quick focus timer control, instant habit logging, health metrics at a glance, and timely haptic reminders. The app leverages WatchConnectivity for real-time bidirectional sync with the iPhone app while maintaining independent operation when the phone is unavailable.

**Key Value Propositions:**
- **Focus Timer from Wrist**: Start, pause, stop focus sessions without reaching for iPhone
- **Glanceable Habits**: See today's habits and complete them with a single tap
- **Health Dashboard**: Steps, calories, and active minutes right on the watch
- **Haptic Nudges**: Gentle wrist taps for habit reminders
- **Rich Complications**: At-a-glance streak counts and timer status

### 1.2 User Stories

#### P0 - Must Have (Launch Blockers)

| ID | User Story | Acceptance Criteria |
|----|------------|---------------------|
| W-001 | As a user, I want to start/pause/stop my focus timer from my watch so I can manage focus sessions without my phone | Timer state syncs within 1s; controls work offline with sync on reconnect |
| W-002 | As a user, I want to see my current focus timer status so I know how much time remains | Shows habit name, remaining time, progress ring; updates in real-time |
| W-003 | As a user, I want to mark habits as complete from my watch so I can quickly log progress | Tap-to-complete; haptic confirmation; syncs to iPhone immediately |
| W-004 | As a user, I want to see today's habits on my watch so I know what I need to complete | Shows habit list with icons, completion status, and streak count |
| W-005 | As a user, I want my watch and phone habit data to stay in sync so I have a consistent view | Bidirectional sync; handles conflict resolution via timestamp |

#### P1 - Should Have (Launch Goals)

| ID | User Story | Acceptance Criteria |
|----|------------|---------------------|
| W-006 | As a user, I want to see my health metrics (steps/calories/minutes) on my watch so I track progress | Pulls from Watch HealthKit; updates every 15 minutes |
| W-007 | As a user, I want a complication showing my current streak so I stay motivated | WidgetKit complication; updates on habit completion |
| W-008 | As a user, I want a complication showing focus timer status so I see it from watch face | Shows running/paused/idle state with remaining time |
| W-009 | As a user, I want haptic reminders for scheduled habits so I don't miss them | Local notifications with haptic; honors Do Not Disturb |
| W-010 | As a user, I want the watch app to work without my phone nearby so I can leave my phone behind | Offline mode with pending action queue; syncs on reconnect |

#### P2 - Nice to Have (Post-Launch)

| ID | User Story | Acceptance Criteria |
|----|------------|---------------------|
| W-011 | As a user, I want to start a break from my watch so I can take timed breaks | 5-minute break timer with haptic on completion |
| W-012 | As a user, I want to see weekly habit trends so I track my consistency | Bar chart showing 7-day completion history |
| W-013 | As a user, I want voice input to log habits via Siri so I can use hands-free | App Intents integration for "Hey Siri, log my meditation" |

---

## 2. Architecture Overview

### 2.1 High-Level System Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              APPLE WATCH                                     │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                         FitLinkWatch App                               │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  │  │
│  │  │FocusTimer   │  │HabitsWatch  │  │HealthSummary│  │ Complications│  │  │
│  │  │WatchView    │  │View         │  │WatchView    │  │ (WidgetKit)  │  │  │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └───────┬──────┘  │  │
│  │         │                │                │                  │         │  │
│  │         └────────────────┼────────────────┼──────────────────┘         │  │
│  │                          ▼                ▼                            │  │
│  │              ┌───────────────────────────────────────────┐             │  │
│  │              │          WatchSessionManager              │             │  │
│  │              │    (WatchConnectivity Coordinator)        │             │  │
│  │              └────────────────────┬──────────────────────┘             │  │
│  │                                   │                                    │  │
│  │  ┌────────────────────────────────┼────────────────────────────────┐   │  │
│  │  │                                │                                │   │  │
│  │  ▼                                ▼                                ▼   │  │
│  │ ┌──────────────┐  ┌───────────────────────────┐  ┌──────────────────┐  │  │
│  │ │WatchTimer    │  │WatchHabitStore            │  │WatchHealth       │  │  │
│  │ │State         │  │(Local Cache)              │  │Collector         │  │  │
│  │ └──────────────┘  └───────────────────────────┘  └──────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                         WatchConnectivity
                    ┌──────────────────┴──────────────────┐
                    │  • Application Context (state sync) │
                    │  • Message (real-time commands)     │
                    │  • User Info Transfer (queued data) │
                    └──────────────────┬──────────────────┘
                                       │
┌──────────────────────────────────────┴──────────────────────────────────────┐
│                               iPHONE                                         │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                            FitLink App                                 │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │              WatchConnectivityService (iPhone side)             │  │  │
│  │  │         Bridges Watch ↔ Existing Services                       │  │  │
│  │  └───────────────┬───────────────────────────────────┬─────────────┘  │  │
│  │                  │                                   │                │  │
│  │                  ▼                                   ▼                │  │
│  │  ┌───────────────────────────┐       ┌────────────────────────────┐   │  │
│  │  │   FocusTimerManager       │       │      HabitStore            │   │  │
│  │  │   (Existing Singleton)    │       │   (Existing Actor)         │   │  │
│  │  └───────────────────────────┘       └────────────────────────────┘   │  │
│  │                                                                       │  │
│  │  ┌───────────────────────────────────────────────────────────────┐    │  │
│  │  │                   Firebase Firestore                          │    │  │
│  │  │              (Source of Truth for Habits)                     │    │  │
│  │  └───────────────────────────────────────────────────────────────┘    │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Technical Requirements

### 3.1 Framework Dependencies

| Framework | Purpose | Min Version |
|-----------|---------|-------------|
| **WatchConnectivity** | Bidirectional iPhone ↔ Watch communication | watchOS 10.0 |
| **WatchKit** | Watch app lifecycle & runtime | watchOS 10.0 |
| **SwiftUI** | Watch UI (native for watchOS 10+) | watchOS 10.0 |
| **WidgetKit** | Watch complications (accessory families) | watchOS 10.0 |
| **HealthKit** | Direct health data on Watch | watchOS 10.0 |
| **UserNotifications** | Haptic habit reminders | watchOS 10.0 |

### 3.2 Deployment Targets

| Platform | Minimum Version | Reason |
|----------|-----------------|--------|
| iOS | 18.0 | Main app target compatibility |
| watchOS | 10.0 | WidgetKit complications, SwiftUI 5 |
| Xcode | 16.0+ | Required for watchOS 10 SDK |

### 3.3 App Group Configuration

```
App Group: group.com.edgetr.FitLink

Shared between:
- FitLink (iOS App)
- FitLinkWatch (Watch App)  
- FitLinkLiveActivity (Widget Extension) [existing]
- FitLinkWatchComplications (Watch Widget Extension)
```

### 3.4 Entitlements Required

**Watch App (FitLinkWatch.entitlements):**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
          "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.edgetr.FitLink</string>
    </array>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array>
        <string>health-records</string>
    </array>
</dict>
</plist>
```

---

## 4. Implementation Plan

### Phase 1: Project Setup & WatchConnectivityService (Week 1)

#### 4.1.1 Goals
- Create Watch App target in Xcode
- Establish WatchConnectivity infrastructure on both sides
- Define shared data types
- Implement basic connectivity health monitoring

#### 4.1.2 Tasks

| Task | Effort | Owner |
|------|--------|-------|
| Add Watch App target to FitLink.xcodeproj | Short (1-2h) | Dev |
| Configure App Group entitlements for Watch | Quick (<1h) | Dev |
| Create shared types framework/module | Short (2-3h) | Dev |
| Implement `WatchConnectivityService` (iPhone) | Medium (4-6h) | Dev |
| Implement `WatchSessionManager` (Watch) | Medium (4-6h) | Dev |
| Add connectivity status UI indicator | Quick (<1h) | Dev |

---

### Phase 2: Watch UI Implementation (Week 2)

#### 4.2.1 Goals
- Build three main Watch views
- Integrate with `WatchSessionManager` for data
- Implement local state management with sync

#### 4.2.2 Views

| View | Description | Priority |
|------|-------------|----------|
| `FocusTimerWatchView` | Timer ring, time display, Start/Pause/Stop buttons | P0 |
| `HabitsWatchView` | Today's habits list, tap-to-complete | P0 |
| `HealthSummaryWatchView` | Steps, calories, active minutes cards | P1 |

#### 4.2.3 Navigation Structure

```
WatchTabView (NavigationSplitView on watchOS 10)
├── Tab 1: FocusTimerWatchView
│   └── Active Timer View (when running)
├── Tab 2: HabitsWatchView
│   └── Habit Detail (on tap, for info)
└── Tab 3: HealthSummaryWatchView
    └── Metric Detail (on tap)
```

---

### Phase 3: Watch Complications (Week 3)

#### 4.3.1 Goals
- Implement WidgetKit-based complications
- Support multiple complication families
- Timeline-based updates

#### 4.3.2 Supported Complication Families

| Family | Content | Priority |
|--------|---------|----------|
| `accessoryCircular` | Streak count with flame icon | P1 |
| `accessoryRectangular` | Timer status + remaining time | P1 |
| `accessoryCorner` | Streak number | P2 |
| `accessoryInline` | "🔥 7 day streak" text | P2 |

---

### Phase 4: Haptic Feedback & Polish (Week 4)

#### 4.4.1 Goals
- Implement haptic reminders for habits
- Add error handling and edge cases
- Performance optimization
- UI polish and animations

---

## 5. Complete Swift Code Examples

### 5.1 Shared Types (`Shared/WatchSyncTypes.swift`)

```swift
import Foundation

// MARK: - Watch Sync Payload

/// Payload sent from iPhone to Watch via Application Context
struct WatchSyncPayload: Codable {
    let timestamp: Date
    let timerState: TimerSyncState?
    let habits: [HabitSyncData]
    let healthSummary: HealthSummaryData?
    
    static let contextKey = "watchSyncPayload"
}

// MARK: - Timer Sync State

struct TimerSyncState: Codable, Equatable {
    let isActive: Bool
    let isPaused: Bool
    let isOnBreak: Bool
    let remainingSeconds: Int
    let totalSeconds: Int
    let habitId: String?
    let habitName: String?
    let habitIcon: String?
    let endDate: Date?
    
    var isRunning: Bool { isActive && !isPaused }
    
    static let idle = TimerSyncState(
        isActive: false,
        isPaused: false,
        isOnBreak: false,
        remainingSeconds: 0,
        totalSeconds: 0,
        habitId: nil,
        habitName: nil,
        habitIcon: nil,
        endDate: nil
    )
}

// MARK: - Habit Sync Data

struct HabitSyncData: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String
    let category: String
    let currentStreak: Int
    let isCompletedToday: Bool
    let suggestedDurationMinutes: Int
    let completionDates: [Date]
}

// MARK: - Health Summary Data

struct HealthSummaryData: Codable, Equatable {
    let steps: Int
    let activeCalories: Int
    let exerciseMinutes: Int
    let lastUpdated: Date
}

// MARK: - Watch Commands

enum WatchCommand: String, Codable {
    case startTimer = "start_timer"
    case pauseTimer = "pause_timer"
    case resumeTimer = "resume_timer"
    case stopTimer = "stop_timer"
    case completeHabit = "complete_habit"
    case uncompleteHabit = "uncomplete_habit"
    case requestSync = "request_sync"
}

struct WatchCommandPayload: Codable {
    let command: WatchCommand
    let habitId: String?
    let durationMinutes: Int?
    let timestamp: Date
    
    init(command: WatchCommand, habitId: String? = nil, durationMinutes: Int? = nil) {
        self.command = command
        self.habitId = habitId
        self.durationMinutes = durationMinutes
        self.timestamp = Date()
    }
}
```

### 5.2 iPhone: WatchConnectivityService

```swift
import Foundation
import WatchConnectivity
import Combine

// MARK: - WatchConnectivityService

/// Manages WatchConnectivity session on iPhone side.
/// Bridges Watch commands to existing FitLink services.
@MainActor
final class WatchConnectivityService: NSObject, ObservableObject {
    
    static let shared = WatchConnectivityService()
    
    // MARK: - Published State
    
    @Published private(set) var isWatchAppInstalled: Bool = false
    @Published private(set) var isWatchReachable: Bool = false
    @Published private(set) var isPaired: Bool = false
    @Published private(set) var lastSyncDate: Date?
    
    // MARK: - Dependencies
    
    private let focusTimerManager = FocusTimerManager.shared
    private var session: WCSession?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupSession()
        observeTimerChanges()
    }
    
    // MARK: - Session Setup
    
    private func setupSession() {
        guard WCSession.isSupported() else { return }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    // MARK: - Push State to Watch
    
    func pushStateToWatch() async {
        guard let session = session,
              session.activationState == .activated,
              session.isWatchAppInstalled else { return }
        
        let timerState = createTimerSyncState()
        let habits = await loadHabitSyncData()
        
        let payload = WatchSyncPayload(
            timestamp: Date(),
            timerState: timerState,
            habits: habits,
            healthSummary: nil
        )
        
        do {
            let data = try JSONEncoder().encode(payload)
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            
            try session.updateApplicationContext([WatchSyncPayload.contextKey: dict])
            lastSyncDate = Date()
        } catch {
            print("[WatchConnectivityService] Failed to push state: \(error)")
        }
    }
    
    private func createTimerSyncState() -> TimerSyncState {
        TimerSyncState(
            isActive: focusTimerManager.isRunning,
            isPaused: !focusTimerManager.isRunning && focusTimerManager.timeRemainingSeconds > 0,
            isOnBreak: focusTimerManager.isOnBreak,
            remainingSeconds: focusTimerManager.timeRemainingSeconds,
            totalSeconds: focusTimerManager.totalDuration,
            habitId: focusTimerManager.currentHabitId,
            habitName: focusTimerManager.currentHabitName,
            habitIcon: "brain.head.profile",
            endDate: focusTimerManager.isRunning ? Date().addingTimeInterval(TimeInterval(focusTimerManager.timeRemainingSeconds)) : nil
        )
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            isPaired = session.isPaired
            isWatchAppInstalled = session.isWatchAppInstalled
            isWatchReachable = session.isReachable
            await pushStateToWatch()
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
            if session.isReachable {
                await pushStateToWatch()
            }
        }
    }
    
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            await handleIncomingMessage(message)
            replyHandler(["status": "ok"])
        }
    }
}
```

### 5.3 Watch: FocusTimerWatchView

```swift
import SwiftUI
import WatchKit

// MARK: - FocusTimerWatchView

struct FocusTimerWatchView: View {
    
    @StateObject private var viewModel = FocusTimerWatchViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isTimerActive {
                    activeTimerView
                } else {
                    selectHabitView
                }
            }
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Active Timer View
    
    private var activeTimerView: some View {
        VStack(spacing: 8) {
            Text(viewModel.habitName)
                .font(.headline)
                .foregroundStyle(.secondary)
            
            // Timer Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        viewModel.isOnBreak ? Color.blue : Color.cyan,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: viewModel.progress)
                
                VStack(spacing: 2) {
                    Text(viewModel.formattedTime)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    
                    Text(viewModel.stateLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, height: 120)
            
            // Control Buttons
            HStack(spacing: 16) {
                Button {
                    viewModel.stopTimer()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                
                Button {
                    viewModel.togglePause()
                } label: {
                    Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.cyan))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        }
        .padding()
    }
    
    // MARK: - Select Habit View
    
    private var selectHabitView: some View {
        List {
            ForEach(viewModel.habits.filter { !$0.isCompletedToday }) { habit in
                HabitStartRowView(habit: habit) {
                    viewModel.startTimer(for: habit)
                }
            }
        }
        .listStyle(.carousel)
    }
}
```

### 5.4 Watch: HabitsWatchView

```swift
import SwiftUI
import WatchKit

// MARK: - HabitsWatchView

struct HabitsWatchView: View {
    
    @StateObject private var viewModel = HabitsWatchViewModel()
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.habits) { habit in
                    HabitWatchRowView(
                        habit: habit,
                        isLoading: viewModel.loadingHabitId == habit.id
                    ) {
                        viewModel.toggleCompletion(for: habit)
                    }
                }
            }
            .listStyle(.carousel)
            .navigationTitle("Habits")
            .refreshable {
                viewModel.requestSync()
            }
        }
    }
}

// MARK: - Habit Watch Row View

struct HabitWatchRowView: View {
    let habit: HabitSyncData
    let isLoading: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: habit.icon)
                    .font(.title3)
                    .foregroundColor(.cyan)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("\(habit.currentStreak)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: habit.isCompletedToday ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(habit.isCompletedToday ? .green : .gray)
                        .symbolEffect(.bounce, value: habit.isCompletedToday)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}
```

### 5.5 Watch Complications

```swift
import WidgetKit
import SwiftUI

// MARK: - Streak Complication Entry

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let isPlaceholder: Bool
    
    static let placeholder = StreakEntry(date: Date(), streak: 7, isPlaceholder: true)
}

// MARK: - Streak Complication Provider

struct StreakComplicationProvider: TimelineProvider {
    
    private let defaults = UserDefaults(suiteName: "group.com.edgetr.FitLink")
    
    func placeholder(in context: Context) -> StreakEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        let streak = loadCurrentStreak()
        completion(StreakEntry(date: Date(), streak: streak, isPlaceholder: false))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let streak = loadCurrentStreak()
        let entry = StreakEntry(date: Date(), streak: streak, isPlaceholder: false)
        
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date())!)
        
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }
    
    private func loadCurrentStreak() -> Int {
        guard let data = defaults?.data(forKey: "watchCachedState"),
              let payload = try? JSONDecoder().decode(WatchSyncPayload.self, from: data) else {
            return 0
        }
        return payload.habits.map(\.currentStreak).max() ?? 0
    }
}

// MARK: - Streak Widget

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
```

---

## 6. File Structure

### 6.1 New Files to Create

```
FitLink/                                          # Existing iOS App
├── Services/
│   └── WatchConnectivityService.swift           # NEW - iPhone WC bridge
│
Shared/                                           # NEW - Shared code module
├── WatchSyncTypes.swift                         # NEW - Sync payload types
│
FitLinkWatch/                                     # NEW - Watch App target
├── FitLinkWatchApp.swift                        # NEW - Watch app entry point
├── ContentView.swift                            # NEW - Root tab view
│
├── Views/
│   ├── FocusTimerWatchView.swift               # NEW - Timer UI
│   ├── HabitsWatchView.swift                   # NEW - Habits list
│   └── HealthSummaryWatchView.swift            # NEW - Health metrics
│
├── ViewModels/
│   ├── FocusTimerWatchViewModel.swift          # NEW - Timer logic
│   ├── HabitsWatchViewModel.swift              # NEW - Habits logic
│   └── HealthSummaryWatchViewModel.swift       # NEW - Health logic
│
├── Services/
│   ├── WatchSessionManager.swift               # NEW - Watch WC manager
│   └── HapticReminderService.swift             # NEW - Haptic notifications
│
├── Assets.xcassets/                             # NEW - Watch assets
├── FitLinkWatch.entitlements                    # NEW - Entitlements
└── Info.plist                                   # NEW - Watch Info.plist
│
FitLinkWatchComplications/                        # NEW - Widget Extension
├── FitLinkWatchComplicationsBundle.swift        # NEW - Widget bundle
├── StreakComplicationProvider.swift             # NEW - Streak widget
├── TimerComplicationProvider.swift              # NEW - Timer widget
└── Info.plist                                   # NEW - Widget Info.plist
```

---

## 7. Data Synchronization Strategy

### 7.1 Communication Methods

| Method | Use Case | Characteristics |
|--------|----------|-----------------|
| **Application Context** | Full state sync | Latest-only, survives reboot, ~262KB limit |
| **sendMessage** | Real-time commands | Immediate, requires reachability, reply handler |
| **transferUserInfo** | Queued data (offline) | FIFO queue, guaranteed delivery, background |

### 7.2 Sync Triggers

| Event | Direction | Method | Data |
|-------|-----------|--------|------|
| App launch (iPhone) | iPhone → Watch | Application Context | Full payload |
| Timer state change | iPhone → Watch | Application Context | Timer + habits |
| Habit completion (iPhone) | iPhone → Watch | Application Context | Updated habits |
| Timer command (Watch) | Watch → iPhone | sendMessage | Command payload |
| Habit complete (Watch online) | Watch → iPhone | sendMessage | Habit ID |
| Habit complete (Watch offline) | Watch → iPhone | transferUserInfo | Pending queue |
| Watch app foreground | Watch → iPhone | sendMessage | Request sync |

### 7.3 Conflict Resolution

**Timer State:** iPhone is source of truth. Watch displays optimistic state but defers to iPhone confirmation.

**Habit Completions:** 
- Deduplicated by (habitId + calendar day)
- Multiple completions on same day = single completion
- iPhone merges pending completions from Watch on reconnect

---

## 8. Testing Strategy

### 8.1 Unit Tests

| Test Suite | Coverage |
|------------|----------|
| `WatchSyncPayloadTests` | Encoding/decoding, edge cases |
| `TimerSyncStateTests` | State transitions, computed properties |
| `WatchSessionManagerTests` | Mock WCSession, command queueing |
| `HapticReminderServiceTests` | Notification scheduling |

### 8.2 Manual Test Scenarios

| Scenario | Steps | Expected |
|----------|-------|----------|
| Cold start sync | Kill Watch app, reopen | Habits load within 2s |
| Airplane mode | Enable airplane on Watch, complete habit | Haptic confirms; syncs on reconnect |
| Timer control | Start/pause/stop from Watch | iPhone timer matches |
| Complication tap | Tap timer complication | Opens to FocusTimerWatchView |

### 8.3 Device Matrix

| Device | Priority |
|--------|----------|
| Apple Watch Series 9 (45mm) | P0 |
| Apple Watch Ultra 2 | P1 |
| Apple Watch SE (2nd gen) | P1 |
| Apple Watch Series 8 (41mm) | P2 |

---

## 9. Estimated Timeline

### 9.1 Four-Week Schedule

```
Week 1: Foundation
├── Day 1-2: Project setup, targets, entitlements
├── Day 3-4: WatchConnectivityService (iPhone)
├── Day 4-5: WatchSessionManager (Watch)
└── Day 5:   Shared types, basic connectivity test

Week 2: Core UI
├── Day 1-2: FocusTimerWatchView + ViewModel
├── Day 2-3: HabitsWatchView + ViewModel
├── Day 3-4: HealthSummaryWatchView + WatchHealthCollector
├── Day 4-5: Local caching, offline support
└── Day 5:   Integration testing

Week 3: Complications
├── Day 1-2: Widget Extension setup
├── Day 2-3: StreakComplicationProvider
├── Day 3-4: TimerComplicationProvider
├── Day 4-5: Timeline refresh, App Group data flow
└── Day 5:   Complication testing on watch faces

Week 4: Polish & Launch
├── Day 1-2: HapticReminderService
├── Day 2-3: Error states, loading states, edge cases
├── Day 3-4: Accessibility (VoiceOver, labels)
├── Day 4:   Performance profiling
└── Day 5:   Final QA, documentation
```

### 9.2 Effort Summary

| Phase | Effort |
|-------|--------|
| Phase 1: Setup & Connectivity | Medium (1 week) |
| Phase 2: Watch UI | Medium (1 week) |
| Phase 3: Complications | Medium (1 week) |
| Phase 4: Polish | Medium (1 week) |
| **Total** | **4 weeks** |

---

## 10. Risks & Mitigations

### 10.1 Risk Matrix

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **WCSession unreliable** | Medium | High | Implement robust queuing, optimistic local state, App Group fallback |
| **HealthKit authorization on Watch** | Low | Medium | Clear onboarding, graceful degradation if denied |
| **Complication data stale** | Medium | Medium | Trigger `WidgetCenter.reloadTimelines()` on state changes |
| **Battery drain** | Medium | High | Batch updates, reduce sync frequency, use Application Context over Messages |
| **App Group data corruption** | Low | High | JSON schema versioning, defensive decoding with fallbacks |
| **Watch simulator limitations** | High | Low | Test on physical devices for WCSession, rely on previews for UI |

### 10.2 Performance Considerations

| Concern | Mitigation |
|---------|------------|
| Memory on Watch | Keep habit list ≤50 items; lazy load details |
| Network efficiency | Use Application Context (latest-only) over queued transfers |
| UI responsiveness | Optimistic updates; local timer countdown |
| Background execution | Leverage complication timeline; avoid background tasks |

### 10.3 Backward Compatibility

- Watch app requires watchOS 10.0+
- iPhone app (iOS 18+) already ships; Watch adds optional capability
- Users without Watch: No impact; `WCSession.isSupported()` check
- Users with older watchOS: Watch app unavailable; no degradation on iPhone

---

## Summary

This architecture plan provides a comprehensive roadmap for building a production-ready Apple Watch companion app for FitLink:

- **4-week implementation timeline** with clear phase deliverables
- **WatchConnectivity infrastructure** for real-time bidirectional sync
- **Offline support** with pending action queue and sync on reconnect
- **WidgetKit complications** for at-a-glance streak and timer info
- **Production-ready Swift code** matching existing FitLink patterns

**Next Step:** Create `feature/apple-watch-companion` branch and begin Phase 1

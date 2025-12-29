# LiveActivity & Dynamic Island Architecture Plan

## Executive Summary

This document outlines the identified bugs, architectural issues, and implementation plan for fixing the FitLink Focus Timer LiveActivity and Dynamic Island features.

---

## Table of Contents

1. [Identified Bugs](#identified-bugs)
2. [Root Cause Analysis](#root-cause-analysis)
3. [Architecture Overview](#architecture-overview)
4. [Implementation Plan](#implementation-plan)
5. [File Change Summary](#file-change-summary)
6. [Testing Strategy](#testing-strategy)

---

## Identified Bugs

### Critical Issues

#### BUG-001: Dynamic Island Shows Static "25 Minutes" Instead of Actual Timer
**Severity**: Critical  
**Location**: `FitLinkLiveActivityLiveActivity.swift`, `LiveActivityManager.swift`  
**Symptoms**:
- Dynamic Island always displays 25:00 regardless of actual timer duration
- Timer value does not count down in real-time

**Root Cause**: 
The implementation uses a static `formattedTime` computed property that displays `timeRemaining` from `ContentState`, but:
1. The initial state hardcodes `totalTime: 25 * 60` in `initialFocusState()`
2. Updates only occur every 15 seconds (see `FocusTimerManager.swift:218`)
3. No use of SwiftUI's native `Text(timerInterval:)` which handles real-time countdown automatically

#### BUG-002: No Cancel/Stop Button in Dynamic Island
**Severity**: High  
**Location**: `FitLinkLiveActivityLiveActivity.swift`  
**Symptoms**:
- Users cannot stop the LiveActivity from Dynamic Island
- No interactive buttons in expanded Dynamic Island view
- Must open app to cancel focus session

**Root Cause**:
- `StopFocusTimerIntent` exists in `FitLinkLiveActivityControl.swift` but is not used in the Dynamic Island UI
- No `Button(intent:)` components in `DynamicIsland` regions
- The `widgetURL` only navigates to the app, doesn't provide quick actions

### Secondary Issues

#### BUG-003: Timer State Inconsistency Between App and Widget
**Severity**: Medium  
**Location**: `LiveActivityManager.swift`, `FocusTimerManager.swift`, `HabitTrackerViewModel.swift`  
**Symptoms**:
- Three separate timer implementations exist with no single source of truth
- `FocusTimerManager`, `HabitTrackerViewModel`, and `LiveActivityManager` all maintain timer state
- Race conditions possible when app enters foreground

**Root Cause**:
- Duplicate timer logic in `HabitTrackerViewModel.startTimer()` and `FocusTimerManager.startCountdown()`
- Both run independent `Timer.publish` instances
- `LiveActivityManager` relies on explicit `updateActivity()` calls rather than a reactive data flow

#### BUG-004: Widget Command Processing Not Connected
**Severity**: Medium  
**Location**: `LiveActivityManager.swift:210-218`, `FocusTimerManager.swift`  
**Symptoms**:
- `ToggleFocusTimerIntent` writes commands to App Group but nothing reads them
- `LiveActivityManager.processWidgetCommand()` exists but is never called

**Root Cause**:
- Missing polling or notification mechanism to check for widget commands
- No `BackgroundTasks` registration for processing widget intents

#### BUG-005: Stale LiveActivity After App Termination
**Severity**: Medium  
**Location**: `LiveActivityManager.swift`  
**Symptoms**:
- LiveActivity may remain visible after app is force-quit
- No `staleDate` set in `ActivityContent`

**Root Cause**:
- `ActivityContent` initialization uses `staleDate: nil` instead of a sensible timeout
- No cleanup mechanism when app terminates unexpectedly

#### BUG-006: Duplicate Type Definitions
**Severity**: Low  
**Location**: Multiple files  
**Symptoms**:
- `FocusTimerState` enum exists in both `FocusTimerSharedState.swift` and as `FitLinkLiveActivityAttributes.TimerState`
- `FocusTimerStateRaw` in `LiveActivityManager.swift` duplicates the same concept
- Potential for state mapping bugs

---

## Root Cause Analysis

### Architectural Problems

1. **No Real-Time Timer Rendering**
   - Current: Manual updates every 15 seconds via `Timer.publish`
   - Apple Best Practice: Use `Text(timerInterval: startDate...endDate, countsDown: true)` for automatic OS-managed countdown

2. **Missing LiveActivityIntent for User Interactions**
   - Current: Only `AppIntent` defined for Control Widget
   - Required: `LiveActivityIntent` protocol for Dynamic Island button interactions

3. **Three-Way Timer State Split**
   - `HabitTrackerViewModel`: UI timer for FocusView
   - `FocusTimerManager`: Persistence and lifecycle
   - `LiveActivityManager`: Widget updates
   - This creates sync issues and update lag

4. **No Bidirectional Communication**
   - Widget can write commands but app doesn't poll for them
   - No push notification integration for remote updates

---

## Architecture Overview

### Current Architecture (Problematic)

```
+---------------------+     +----------------------+     +------------------------+
| HabitTrackerViewModel| --> | FocusTimerManager    | --> | LiveActivityManager    |
| (Timer.publish 1s)   |     | (Timer.publish 1s)   |     | (update every 15s)     |
+---------------------+     +----------------------+     +------------------------+
                                     |                            |
                                     v                            v
                            +------------------+         +-------------------+
                            | UserDefaults     |         | Activity<>        |
                            | (persistence)    |         | (ContentState)    |
                            +------------------+         +-------------------+
```

### Proposed Architecture

```
+---------------------+
| FocusTimerManager   |  <-- Single Source of Truth
| (Timer + State)     |
+----------+----------+
           |
           | @Published properties
           v
+----------+----------+     +------------------------+
| HabitTrackerViewModel|     | LiveActivityManager    |
| (observes, no timer) |     | (observes, updates LA) |
+---------------------+     +------------------------+
                                      |
                                      v
                            +-------------------+
                            | Activity<>        |
                            | with timerInterval|
                            +-------------------+
                                      |
                                      v
                            +-------------------+
                            | Dynamic Island    |
                            | + Stop Button     |
                            +-------------------+
```

---

## Implementation Plan

### Phase 1: Fix Timer Display (BUG-001)

#### Step 1.1: Add Timer Date Range to ContentState

**File**: `FitLink/Models/FitLinkLiveActivityAttributes.swift`

```swift
public struct ContentState: Codable, Hashable {
    var timerState: TimerState
    var timeRemaining: Int  // Keep for backwards compatibility
    var totalTime: Int
    var emoji: String
    
    // NEW: Add date-based timer for real-time countdown
    var timerEndDate: Date?
    var timerStartDate: Date?
    
    var timerRange: ClosedRange<Date>? {
        guard let start = timerStartDate, let end = timerEndDate else { return nil }
        return start...end
    }
    
    // Update factory methods to include dates
    static func initialFocusState(totalTime: Int, startDate: Date = Date()) -> ContentState {
        ContentState(
            timerState: .running,
            timeRemaining: totalTime,
            totalTime: totalTime,
            emoji: "brain",
            timerEndDate: startDate.addingTimeInterval(TimeInterval(totalTime)),
            timerStartDate: startDate
        )
    }
    // ... update other factory methods similarly
}
```

#### Step 1.2: Update Dynamic Island to Use timerInterval

**File**: `FitLinkLiveActivity/FitLinkLiveActivityLiveActivity.swift`

```swift
// In DynamicIslandExpandedRegion(.trailing)
VStack(alignment: .trailing) {
    if let range = context.state.timerRange, context.state.timerState == .running {
        // Real-time countdown managed by OS
        Text(timerInterval: range, countsDown: true)
            .font(.title2.monospacedDigit())
            .fontWeight(.bold)
    } else {
        // Fallback for paused/finished states
        Text(context.state.formattedTime)
            .font(.title2.monospacedDigit())
            .fontWeight(.bold)
    }
    Text(context.state.timerState.displayName)
        .font(.caption)
}

// Same pattern for compactTrailing
compactTrailing: {
    if let range = context.state.timerRange, context.state.timerState == .running {
        Text(timerInterval: range, countsDown: true)
            .font(.caption.monospacedDigit())
            .fontWeight(.semibold)
    } else {
        Text(context.state.formattedTime)
            .font(.caption.monospacedDigit())
            .fontWeight(.semibold)
    }
}
```

#### Step 1.3: Update LiveActivityManager to Pass Dates

**File**: `FitLink/Services/LiveActivityManager.swift`

```swift
func startFocusActivity(
    habitId: String,
    habitName: String,
    habitIcon: String = "brain.head.profile",
    totalSeconds: Int = 25 * 60
) {
    // ... existing code ...
    
    let now = Date()
    let endDate = now.addingTimeInterval(TimeInterval(totalSeconds))
    
    let initialState = FitLinkLiveActivityAttributes.ContentState(
        timerState: .running,
        timeRemaining: totalSeconds,
        totalTime: totalSeconds,
        emoji: "brain",
        timerEndDate: endDate,
        timerStartDate: now
    )
    // ... rest of method
}

func updateActivity(timeRemaining: Int, isRunning: Bool, isOnBreak: Bool, totalTime: Int? = nil) {
    // Calculate new end date based on current state
    let endDate: Date? = isRunning ? Date().addingTimeInterval(TimeInterval(timeRemaining)) : nil
    let startDate: Date? = isRunning ? Date() : nil
    
    let newState = FitLinkLiveActivityAttributes.ContentState(
        timerState: timerState,
        timeRemaining: max(0, timeRemaining),
        totalTime: effectiveTotalTime,
        emoji: emoji,
        timerEndDate: endDate,
        timerStartDate: startDate
    )
    // ... rest of method
}
```

---

### Phase 2: Add Stop Button to Dynamic Island (BUG-002)

#### Step 2.1: Create LiveActivityIntent for Stop Action

**File**: `FitLinkLiveActivity/FitLinkLiveActivityControl.swift` (or new file `FitLinkLiveActivityIntents.swift`)

```swift
import AppIntents
import ActivityKit

// LiveActivityIntent allows execution without launching app
@available(iOS 17.0, *)
struct EndFocusSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End Focus Session"
    static var description = IntentDescription("Ends the current focus session")
    
    func perform() async throws -> some IntentResult {
        // End all FitLink live activities
        if #available(iOS 16.2, *) {
            for activity in Activity<FitLinkLiveActivityAttributes>.activities {
                let finalState = FitLinkLiveActivityAttributes.ContentState.finishedState()
                let content = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(content, dismissalPolicy: .immediate)
            }
        }
        
        // Write stop command for app to process
        FocusTimerCommand.stop.write()
        
        return .result()
    }
}

@available(iOS 17.0, *)
struct PauseFocusSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause Focus Session"
    
    func perform() async throws -> some IntentResult {
        FocusTimerCommand.pause.write()
        // Trigger widget reload to reflect paused state
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusTimerWidget")
        return .result()
    }
}

@available(iOS 17.0, *)
struct ResumeFocusSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Resume Focus Session"
    
    func perform() async throws -> some IntentResult {
        FocusTimerCommand.resume.write()
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusTimerWidget")
        return .result()
    }
}
```

#### Step 2.2: Add Interactive Buttons to Dynamic Island

**File**: `FitLinkLiveActivity/FitLinkLiveActivityLiveActivity.swift`

```swift
DynamicIslandExpandedRegion(.bottom) {
    HStack(spacing: 20) {
        // Progress bar
        ProgressView(value: context.state.progress)
            .tint(timerColor(for: context.state.timerState))
        
        // Stop button (iOS 17+ only)
        if #available(iOS 17.0, *) {
            Button(intent: EndFocusSessionIntent()) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
    .padding(.horizontal)
}

// Alternative: Add to trailing region
DynamicIslandExpandedRegion(.trailing) {
    VStack(alignment: .trailing, spacing: 8) {
        // Timer display
        if let range = context.state.timerRange, context.state.timerState == .running {
            Text(timerInterval: range, countsDown: true)
                .font(.title2.monospacedDigit())
                .fontWeight(.bold)
        } else {
            Text(context.state.formattedTime)
                .font(.title2.monospacedDigit())
                .fontWeight(.bold)
        }
        
        // Pause/Resume + Stop buttons (iOS 17+)
        if #available(iOS 17.0, *) {
            HStack(spacing: 12) {
                if context.state.timerState == .running {
                    Button(intent: PauseFocusSessionIntent()) {
                        Image(systemName: "pause.fill")
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                } else if context.state.timerState == .paused {
                    Button(intent: ResumeFocusSessionIntent()) {
                        Image(systemName: "play.fill")
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(intent: EndFocusSessionIntent()) {
                    Image(systemName: "stop.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
```

---

### Phase 3: Consolidate Timer State (BUG-003)

#### Step 3.1: Make FocusTimerManager the Single Source of Truth

**File**: `FitLink/Services/FocusTimerManager.swift`

Remove duplicate timer from `HabitTrackerViewModel` and have it observe `FocusTimerManager`:

```swift
@MainActor
final class FocusTimerManager: ObservableObject {
    // ... existing properties ...
    
    // NEW: Combine publisher for LiveActivityManager to observe
    var statePublisher: AnyPublisher<TimerStateSnapshot, Never> {
        Publishers.CombineLatest4(
            $remainingSeconds,
            $isPaused,
            $isOnBreak,
            $totalSeconds
        )
        .map { remaining, paused, onBreak, total in
            TimerStateSnapshot(
                remainingSeconds: remaining,
                isPaused: paused,
                isOnBreak: onBreak,
                totalSeconds: total,
                endDate: paused ? nil : Date().addingTimeInterval(TimeInterval(remaining))
            )
        }
        .eraseToAnyPublisher()
    }
}

struct TimerStateSnapshot {
    let remainingSeconds: Int
    let isPaused: Bool
    let isOnBreak: Bool
    let totalSeconds: Int
    let endDate: Date?
}
```

#### Step 3.2: Simplify HabitTrackerViewModel

**File**: `FitLink/ViewModels/HabitTrackerViewModel.swift`

Remove internal timer and delegate to `FocusTimerManager`:

```swift
// Remove these properties:
// - timerCancellable
// - focusTimeRemainingSeconds (derive from FocusTimerManager)
// - isFocusTimerRunning (derive from FocusTimerManager)

// Add computed properties instead:
var focusTimeRemainingSeconds: Int {
    FocusTimerManager.shared.remainingSeconds
}

var isFocusTimerRunning: Bool {
    FocusTimerManager.shared.isActive && !FocusTimerManager.shared.isPaused
}

// Remove startTimer() and stopTimer() private methods
// Keep public API but delegate to FocusTimerManager
```

#### Step 3.3: Subscribe LiveActivityManager to State Changes

**File**: `FitLink/Services/LiveActivityManager.swift`

```swift
final class LiveActivityManager: @unchecked Sendable {
    // ... existing code ...
    
    private var stateSubscription: AnyCancellable?
    
    func startObservingTimer() {
        stateSubscription = FocusTimerManager.shared.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.handleTimerStateChange(snapshot)
            }
    }
    
    private func handleTimerStateChange(_ snapshot: TimerStateSnapshot) {
        guard currentActivity != nil else { return }
        
        let newState = FitLinkLiveActivityAttributes.ContentState(
            timerState: mapTimerState(snapshot),
            timeRemaining: snapshot.remainingSeconds,
            totalTime: snapshot.totalSeconds,
            emoji: emojiFor(snapshot),
            timerEndDate: snapshot.endDate,
            timerStartDate: snapshot.endDate != nil ? Date() : nil
        )
        
        Task {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: newState, staleDate: nil)
                await currentActivity?.update(content)
            }
        }
    }
}
```

---

### Phase 4: Fix Widget Command Processing (BUG-004)

#### Step 4.1: Poll for Widget Commands on Foreground

**File**: `FitLink/Services/FocusTimerManager.swift`

```swift
private func handleAppWillEnterForeground() {
    // ... existing code ...
    
    // NEW: Process any pending widget commands
    processWidgetCommands()
}

private func processWidgetCommands() {
    #if canImport(ActivityKit)
    guard #available(iOS 16.1, *) else { return }
    
    if let command = LiveActivityManager.shared.processWidgetCommand() {
        switch command {
        case .start:
            // Widget can't start without habit context, ignore
            break
        case .pause:
            pause()
        case .resume:
            resume()
        case .stop:
            stop()
        }
        log("Processed widget command: \(command)")
    }
    #endif
}
```

#### Step 4.2: Add Scene Phase Observer

**File**: `FitLink/FitLinkApp.swift`

```swift
private func handleScenePhaseChange(_ phase: ScenePhase) {
    switch phase {
    case .active:
        // ... existing code ...
        
        // NEW: Process widget commands
        FocusTimerManager.shared.checkWidgetCommands()
        
    // ... rest of method
    }
}
```

---

### Phase 5: Add Stale Date Handling (BUG-005)

#### Step 5.1: Set Stale Date on Activity Content

**File**: `FitLink/Services/LiveActivityManager.swift`

```swift
func startFocusActivity(...) {
    // ... existing code ...
    
    // Set stale date to 5 minutes after expected end
    let staleDate = Date().addingTimeInterval(TimeInterval(totalSeconds + 300))
    
    do {
        if #available(iOS 16.2, *) {
            let content = ActivityContent(state: initialState, staleDate: staleDate)
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        }
        // ... rest of method
    }
}

func updateActivity(...) {
    // ... existing code ...
    
    // Update stale date on each update
    let staleDate = timeRemaining > 0 ? Date().addingTimeInterval(TimeInterval(timeRemaining + 300)) : nil
    
    Task {
        if #available(iOS 16.2, *) {
            let content = ActivityContent(state: newState, staleDate: staleDate)
            await activity.update(content)
        }
    }
}
```

---

### Phase 6: Consolidate Type Definitions (BUG-006)

#### Step 6.1: Create Single Shared Types File

**File**: `FitLink/Models/FocusTimerTypes.swift` (NEW)

```swift
import Foundation

/// Unified timer state used across app and widget extension
public enum FocusTimerState: String, Codable, Hashable {
    case running
    case paused
    case breakTime
    case finished
    
    public var displayName: String { ... }
    public var icon: String { ... }
    public var tintColorName: String { ... }
}

/// Commands that can be sent from widget to app
public enum FocusTimerCommand: String, Codable {
    case start
    case pause
    case resume
    case stop
}

/// Shared state structure for App Group communication
public struct SharedFocusTimerState: Codable {
    public let isActive: Bool
    public let habitId: String?
    public let habitName: String
    public let timeRemaining: Int
    public let timerState: FocusTimerState
    public let timerEndDate: Date?
    public let lastUpdated: Date
    
    public static let appGroupIdentifier = "group.com.edgetr.FitLink"
    public static let stateKey = "focusTimerState"
    public static let commandKey = "focusTimerCommand"
}
```

#### Step 6.2: Update All Files to Use Shared Types

- Remove `FocusTimerState` from `FocusTimerSharedState.swift`
- Remove `FocusTimerStateRaw` from `LiveActivityManager.swift`
- Update `FitLinkLiveActivityAttributes.TimerState` to be a typealias or use `FocusTimerState` directly
- Ensure the new file is added to both main app and widget extension targets

---

## File Change Summary

| File | Action | Priority |
|------|--------|----------|
| `FitLink/Models/FitLinkLiveActivityAttributes.swift` | Modify: Add `timerEndDate`, `timerStartDate`, `timerRange` | P0 |
| `FitLinkLiveActivity/FitLinkLiveActivityLiveActivity.swift` | Modify: Use `Text(timerInterval:)`, add stop button | P0 |
| `FitLink/Services/LiveActivityManager.swift` | Modify: Pass dates, add stale date, subscribe to state | P1 |
| `FitLinkLiveActivity/FitLinkLiveActivityControl.swift` | Modify: Add `LiveActivityIntent` implementations | P0 |
| `FitLink/Services/FocusTimerManager.swift` | Modify: Add state publisher, process widget commands | P1 |
| `FitLink/ViewModels/HabitTrackerViewModel.swift` | Modify: Remove duplicate timer, use computed properties | P2 |
| `FitLink/FitLinkApp.swift` | Modify: Add widget command check on foreground | P2 |
| `FitLink/Models/FocusTimerTypes.swift` | Create: Unified type definitions | P3 |
| `FitLinkLiveActivity/FocusTimerSharedState.swift` | Modify: Use shared types | P3 |

---

## Testing Strategy

### Unit Tests

1. **ContentState Timer Range Calculation**
   - Test `timerRange` returns correct `ClosedRange<Date>`
   - Test `nil` handling when timer is paused

2. **Intent Execution**
   - Test `EndFocusSessionIntent` ends all activities
   - Test `PauseFocusSessionIntent` writes correct command
   - Test `ResumeFocusSessionIntent` writes correct command

3. **State Synchronization**
   - Test `FocusTimerManager` publishes state changes correctly
   - Test `LiveActivityManager` receives and applies updates

### Integration Tests

1. **End-to-End Timer Flow**
   - Start focus session -> Verify LiveActivity shows correct time
   - Wait 30 seconds -> Verify Dynamic Island countdown is accurate
   - Tap stop in Dynamic Island -> Verify session ends and app state updates

2. **Background/Foreground Transitions**
   - Start timer -> Enter background -> Return to foreground
   - Verify timer state is consistent across transitions

### Manual Testing Checklist

- [ ] Start 5-minute focus session, verify Dynamic Island shows "05:00" initially
- [ ] Observe countdown in Dynamic Island for 30 seconds
- [ ] Expand Dynamic Island, tap Stop button
- [ ] Verify focus session ends and LiveActivity dismisses
- [ ] Test pause/resume from expanded Dynamic Island (iOS 17+)
- [ ] Force-quit app during timer, relaunch, verify state is restored
- [ ] Test with different timer durations (5, 15, 25, 45 minutes)

---

## Appendix: Apple Documentation References

1. [Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
2. [Updating and ending your Live Activity with ActivityKit push notifications](https://developer.apple.com/documentation/activitykit/updating-and-ending-your-live-activity-with-activitykit-push-notifications)
3. [App Intents - LiveActivityIntent](https://developer.apple.com/documentation/appintents/liveactivityintent)
4. [Text(timerInterval:countsDown:)](https://developer.apple.com/documentation/swiftui/text/init(timerinterval:pausetime:countsdown:showshours:))
5. [WWDC23 - Bring widgets to life](https://developer.apple.com/videos/play/wwdc2023/10027/)

---

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-28 | AI Assistant | Initial architecture plan |

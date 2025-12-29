# Watch-Firebase Data Sync Architecture

**Created:** 2025-12-30
**Status:** Planning
**Related:** Apple-Watch-App-Architecture-Plan.md

## Problem Statement

Firebase SDK does not support watchOS. The Watch app needs to:
1. Display user data (habits, health metrics, timer state)
2. Complete habits and control timers
3. Show the same values as the iPhone app (seamless UX)
4. Persist changes to Firestore for cross-device sync

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DATA FLOW ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                         CLOUD LAYER                              │  │
│   │                                                                  │  │
│   │                    ┌─────────────────┐                          │  │
│   │                    │    Firebase     │                          │  │
│   │                    │   Firestore     │                          │  │
│   │                    │                 │                          │  │
│   │                    │  users/{uid}/   │                          │  │
│   │                    │  habits/{id}    │                          │  │
│   │                    │  health_metrics │                          │  │
│   │                    └────────┬────────┘                          │  │
│   │                             │                                    │  │
│   └─────────────────────────────┼────────────────────────────────────┘  │
│                                 │                                       │
│                                 │ Firestore SDK                         │
│                                 │ (iOS only)                            │
│                                 ▼                                       │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                        iPHONE LAYER                              │  │
│   │                                                                  │  │
│   │  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐  │  │
│   │  │  HabitStore │◄──►│ Firestore   │◄──►│ WatchConnectivity   │  │  │
│   │  │  (Firestore)│    │   Sync      │    │     Service         │  │  │
│   │  └─────────────┘    └─────────────┘    └──────────┬──────────┘  │  │
│   │                                                   │              │  │
│   │  ┌─────────────┐    ┌─────────────┐              │              │  │
│   │  │FocusTimer   │◄──►│   Health    │              │              │  │
│   │  │  Manager    │    │   Service   │              │              │  │
│   │  └─────────────┘    └─────────────┘              │              │  │
│   │                                                   │              │  │
│   └───────────────────────────────────────────────────┼──────────────┘  │
│                                                       │                 │
│                            WatchConnectivity          │                 │
│                         (bidirectional sync)          │                 │
│                                                       ▼                 │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                        WATCH LAYER                               │  │
│   │                                                                  │  │
│   │  ┌─────────────────┐         ┌─────────────────────────────┐   │  │
│   │  │ WatchSession    │◄───────►│       Watch Views           │   │  │
│   │  │   Manager       │         │  - FocusTimerWatchView      │   │  │
│   │  │                 │         │  - HabitsWatchView          │   │  │
│   │  │ (local state +  │         │  - HealthSummaryWatchView   │   │  │
│   │  │  command queue) │         └─────────────────────────────┘   │  │
│   │  └─────────────────┘                                            │  │
│   │                                                                  │  │
│   │  ┌─────────────────┐         ┌─────────────────────────────┐   │  │
│   │  │ WatchHealth     │         │    Complications            │   │  │
│   │  │  Collector      │         │  (cached from App Group)    │   │  │
│   │  │ (local HealthKit)│        └─────────────────────────────┘   │  │
│   │  └─────────────────┘                                            │  │
│   │                                                                  │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Core Principle: iPhone as Single Source of Truth

The Watch NEVER writes directly to Firebase. All data mutations follow this flow:

```
Watch Action → Command to iPhone → iPhone updates Firestore → Sync back to Watch
```

This ensures:
- Single source of truth (no conflicts)
- Offline support (commands queue on Watch)
- Consistent data across devices
- No Firebase SDK needed on watchOS

## Data Sync Categories

### 1. Habits (Firestore-backed)

**Current State:** Local JSON files
**Target State:** Firestore with real-time sync

#### Firestore Schema
```
users/{userId}/
  habits/
    {habitId}/
      id: string
      name: string
      icon: string
      category: string
      currentStreak: number
      bestStreak: number
      suggestedDurationMinutes: number
      completionDates: array<timestamp>
      reminderTime: timestamp?
      createdAt: timestamp
      updatedAt: timestamp
```

#### Sync Flow
```
iPhone                              Watch
   │                                  │
   │◄────── requestSync ──────────────│
   │                                  │
   │  [Load from Firestore]           │
   │                                  │
   │─────── HabitSyncData[] ─────────►│
   │                                  │
   │                           [Display]
   │                                  │
   │◄────── completeHabit ────────────│
   │                                  │
   │  [Update Firestore]              │
   │  [Recalculate streak]            │
   │                                  │
   │─────── Updated HabitSyncData ───►│
   │                                  │
   │                           [Update UI]
```

### 2. Focus Timer (In-memory + Firestore sessions)

**Current State:** In-memory with Live Activity
**Target State:** Same, plus session history in Firestore

#### Timer State Sync
```swift
struct TimerSyncState: Codable {
    let isActive: Bool
    let isPaused: Bool
    let remainingSeconds: Int
    let totalSeconds: Int
    let habitId: String?
    let habitName: String?
    let habitIcon: String?
    let endDate: Date?  // For Watch local countdown
}
```

The Watch runs a local timer based on `endDate` for smooth UI updates, but defers to iPhone state on sync.

#### Session Persistence (New)
```
users/{userId}/
  focus_sessions/
    {sessionId}/
      habitId: string
      habitName: string
      startedAt: timestamp
      endedAt: timestamp
      durationSeconds: number
      wasCompleted: bool
```

### 3. Health Metrics (HealthKit + Firestore)

**Current State:** HealthKit → Firestore via HealthSyncScheduler
**Watch Behavior:** Read from local Watch HealthKit

Health data is NOT synced via WatchConnectivity because:
- Watch has its own HealthKit with more accurate real-time data
- iPhone syncs to Firestore on its own schedule
- HealthKit handles cross-device sync natively

### 4. User Profile (Firestore)

Synced on session start, cached in App Group for complications.

```swift
struct UserSyncData: Codable {
    let userId: String
    let displayName: String
    let photoURL: String?
}
```

## Implementation Plan

### Phase 1: Migrate HabitStore to Firestore

**Files to Modify:**
- `FitLink/Services/HabitStore.swift` - Add Firestore operations
- `FitLink/Models/Habit.swift` - Add Firestore serialization

**New Files:**
- `FitLink/Services/HabitFirestoreService.swift` - Firestore CRUD

**Changes:**

1. Create `HabitFirestoreService`:
```swift
actor HabitFirestoreService {
    static let shared = HabitFirestoreService()
    
    private let db = Firestore.firestore()
    
    func loadHabits(userId: String) async throws -> [Habit]
    func saveHabit(_ habit: Habit, userId: String) async throws
    func updateHabitCompletion(_ habitId: String, userId: String, date: Date, completed: Bool) async throws
    func deleteHabit(_ habitId: String, userId: String) async throws
    func observeHabits(userId: String) -> AsyncStream<[Habit]>
}
```

2. Update `HabitStore` to use Firestore:
```swift
actor HabitStore {
    private let firestoreService = HabitFirestoreService.shared
    private var cachedHabits: [Habit] = []
    
    func loadHabits(userId: String?) async throws -> [Habit] {
        guard let userId = userId else { return cachedHabits }
        cachedHabits = try await firestoreService.loadHabits(userId: userId)
        return cachedHabits
    }
    
    func toggleCompletion(_ habit: Habit, userId: String?) async throws {
        guard let userId = userId else { return }
        // Update Firestore
        // Update local cache
        // Trigger Watch sync
    }
}
```

3. Add real-time listener for cross-device sync:
```swift
func startObserving(userId: String) {
    Task {
        for await habits in firestoreService.observeHabits(userId: userId) {
            self.cachedHabits = habits
            await WatchConnectivityService.shared.pushStateToWatch()
        }
    }
}
```

### Phase 2: Update WatchConnectivityService

**Changes:**

1. Use Firestore-backed HabitStore:
```swift
private func toggleHabitCompletion(id: String, complete: Bool) async {
    guard let uuid = UUID(uuidString: id),
          let userId = SessionManager.shared.currentUserID else { return }
    
    do {
        // This now writes to Firestore
        try await HabitStore.shared.toggleCompletion(
            habitId: uuid,
            userId: userId,
            complete: complete
        )
        
        // Push updated state to Watch
        await pushStateToWatch()
        
        log("Habit completion synced to Firestore and Watch")
    } catch {
        log("Failed to sync habit: \(error)")
    }
}
```

2. Add session persistence for focus timer:
```swift
private func saveFocusSession(_ session: FocusSession) async {
    guard let userId = SessionManager.shared.currentUserID else { return }
    
    try? await Firestore.firestore()
        .collection("users")
        .document(userId)
        .collection("focus_sessions")
        .document(session.id)
        .setData(session.toDictionary())
}
```

### Phase 3: Handle Offline & Conflicts

**Firestore Offline:**
- Firestore SDK handles offline writes automatically
- Writes queue locally and sync when online
- No additional code needed for iPhone

**Watch Offline:**
- Commands queue in `WatchSessionManager.pendingCommands`
- Sent via `transferUserInfo` (guaranteed delivery)
- iPhone processes when connected

**Conflict Resolution:**
- Last-write-wins for habit completion (Firestore default)
- Timer state always from iPhone (authoritative)
- Health metrics from respective device's HealthKit

### Phase 4: Add Focus Session History

**New Model:**
```swift
struct FocusSession: Identifiable, Codable {
    let id: String
    let habitId: String
    let habitName: String
    let habitIcon: String
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Int
    let wasCompleted: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case habitName = "habit_name"
        case habitIcon = "habit_icon"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationSeconds = "duration_seconds"
        case wasCompleted = "was_completed"
    }
}
```

**Integration with FocusTimerManager:**
```swift
func stop() {
    guard isActive else { return }
    
    let session = FocusSession(
        id: UUID().uuidString,
        habitId: activeHabit?.id.uuidString ?? "",
        habitName: activeHabit?.name ?? "Focus",
        habitIcon: activeHabit?.icon ?? "brain.head.profile",
        startedAt: sessionStartTime,
        endedAt: Date(),
        durationSeconds: totalSeconds - remainingSeconds,
        wasCompleted: remainingSeconds == 0
    )
    
    Task {
        await saveFocusSession(session)
    }
    
    // ... existing stop logic
}
```

## Migration Strategy

### Step 1: Dual-Write (Safe Migration)
1. Keep existing local JSON storage
2. Add Firestore writes alongside
3. Read from Firestore, fallback to local
4. Verify data consistency

### Step 2: Migrate Existing Data
1. On app launch, check for local habits
2. If local exists and Firestore empty, upload
3. Mark migration complete in UserDefaults
4. Remove local file after successful migration

### Step 3: Remove Local Storage
1. Remove local JSON read/write code
2. Update HabitStore to Firestore-only
3. Keep local cache for performance

## Error Handling

### Network Errors
- Firestore queues writes offline
- Show subtle "syncing" indicator
- Don't block UI on sync failures

### Auth Errors
- Re-authenticate if token expired
- Queue operations until authenticated
- Clear local data on sign out

### Watch Disconnected
- Commands queue automatically
- Show "pending" state on Watch
- Sync on reconnection

## Testing Checklist

- [ ] Create habit on iPhone, appears on Watch
- [ ] Complete habit on Watch, updates iPhone and Firestore
- [ ] Start timer on Watch, visible on iPhone
- [ ] Pause/resume timer from either device
- [ ] Airplane mode on iPhone, Watch shows cached data
- [ ] Airplane mode on Watch, commands queue
- [ ] Sign out clears all data
- [ ] Sign in syncs existing habits
- [ ] Multiple devices stay in sync

## Files to Create/Modify

### New Files
- `FitLink/Services/HabitFirestoreService.swift`
- `FitLink/Services/FocusSessionService.swift`
- `FitLink/Models/FocusSession.swift`

### Modified Files
- `FitLink/Services/HabitStore.swift`
- `FitLink/Services/WatchConnectivityService.swift`
- `FitLink/Services/FocusTimerManager.swift`
- `FitLink/ViewModels/HabitTrackerViewModel.swift`

## Security Rules (Firestore)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /habits/{habitId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /focus_sessions/{sessionId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

## Timeline Estimate

| Phase | Effort | Dependencies |
|-------|--------|--------------|
| Phase 1: Firestore HabitStore | 4-6 hours | None |
| Phase 2: WatchConnectivity Update | 2-3 hours | Phase 1 |
| Phase 3: Offline Handling | 2-3 hours | Phase 1, 2 |
| Phase 4: Focus Session History | 2-3 hours | Phase 1 |
| Testing & Bug Fixes | 3-4 hours | All |
| **Total** | **13-19 hours** | |

## Success Metrics

- Habit completion reflects on both devices within 2 seconds (when online)
- No data loss during offline usage
- Timer state consistent across devices
- Complications show current data (within 15 min refresh)

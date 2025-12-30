# Bug Fix: Diet Planner App Freeze

**Created:** 2025-12-30
**Status:** Planning
**Priority:** Critical
**Affected Files:**
- `FitLink/ViewModels/DietPlannerViewModel.swift`
- `FitLink/Services/GeminiAIService.swift`
- `FitLink/Utils/AppLogger.swift`
- `FitLink/Utils/ErrorHandler.swift`
- `FitLink/Views/Shared/ChatConversationView.swift`

## Problem Description

User reports: "In diet planner, the whole app froze after some chats."

The app becomes unresponsive during the AI chat flow, requiring force-quit.

## Root Cause Analysis

### Issue 1: Notification Observer Memory Leak (CRITICAL)

**Location**: `DietPlannerViewModel.swift` lines 117-127

```swift
private func setupNotificationObservers() {
    NotificationCenter.default.addObserver(
        forName: .planGenerationCompleted,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        Task { @MainActor [weak self] in
            self?.handleGenerationCompletedNotification(notification)
        }
    }
}

deinit {
    NotificationCenter.default.removeObserver(self)  // DOES NOT WORK FOR BLOCK-BASED OBSERVERS
}
```

**The Bug**: The block-based `addObserver(forName:object:queue:using:)` returns an opaque observer token (`NSObjectProtocol`) that MUST be stored and explicitly removed. Calling `removeObserver(self)` does **nothing** for block-based observers.

**Impact**: Every time the user navigates to DietPlannerView:
1. A new `DietPlannerViewModel` is created
2. A new observer is registered
3. The old ViewModel is never fully deallocated (retained by the closure)

After 10 navigations, 10 "zombie" ViewModels simultaneously react to `.planGenerationCompleted`, each spawning Tasks on the Main Actor, causing thread contention and freezes.

### Issue 2: Synchronous JSON on Main Thread (HIGH)

**Location**: `DietPlannerViewModel.swift` lines 834-843

```swift
private func saveConversationState() {
    if let data = try? JSONEncoder().encode(chatMessages) {  // BLOCKS MAIN THREAD
        UserDefaults.standard.set(data, forKey: "diet_planner_chat_messages")
    }
    // ... more UserDefaults writes
}
```

**The Bug**: `saveConversationState()` is called after **every message** in the chat. As the conversation grows (10+ messages with large AI responses), the `JSONEncoder().encode()` operation blocks the main thread for noticeable durations.

**Same issue in**: `restoreConversationState()` with `JSONDecoder().decode()`

### Issue 3: Expensive DateFormatter Initialization (MEDIUM)

**Locations**:
- `GeminiAIService.swift` line 622-626: `ISO8601DateFormatter()` created per log call
- `AppLogger.swift`: Similar pattern
- `ErrorHandler.swift`: Similar pattern

```swift
private func log(_ message: String) {
    #if DEBUG
    let timestamp = ISO8601DateFormatter().string(from: Date())  // EXPENSIVE
    print("[\\(timestamp)] [GeminiAIService] \\(message)")
    #endif
}
```

**Impact**: `DateFormatter` initialization is expensive (~0.5-2ms per call). During heavy AI interaction with many log statements, this adds up.

### Issue 4: Actor Contention Pattern (MEDIUM)

The `@MainActor` ViewModel awaits the `GeminiAIService` actor:

```swift
@MainActor
class DietPlannerViewModel {
    func sendMessage(_ text: String) async {
        // ...
        let response = try await geminiService.sendDietConversation(...)  // Await actor
        // Main actor waits here
    }
}
```

While this is correct async/await usage, when combined with the other issues (leaked observers, synchronous JSON work), the Main Actor queue becomes overwhelmed and the UI freezes.

## Solution Architecture

### Fix 1: Properly Store and Remove Notification Observer

```swift
// DietPlannerViewModel.swift

private var notificationObserver: NSObjectProtocol?

private func setupNotificationObservers() {
    notificationObserver = NotificationCenter.default.addObserver(
        forName: .planGenerationCompleted,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        Task { @MainActor [weak self] in
            self?.handleGenerationCompletedNotification(notification)
        }
    }
}

deinit {
    if let observer = notificationObserver {
        NotificationCenter.default.removeObserver(observer)
    }
}
```

### Fix 2: Move JSON Work Off Main Thread

```swift
private func saveConversationState() {
    let messages = chatMessages
    let generationId = currentGenerationId
    let prefs = preferences
    let summary = readySummary
    let isReady = viewState == .readyToGenerate
    let isGenerating = viewState == .generating
    
    Task.detached(priority: .utility) {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: "diet_planner_chat_messages")
        }
        UserDefaults.standard.set(generationId, forKey: "diet_planner_generation_id")
        UserDefaults.standard.set(prefs, forKey: "diet_planner_preferences")
        UserDefaults.standard.set(summary, forKey: "diet_planner_ready_summary")
        UserDefaults.standard.set(isReady, forKey: "diet_planner_is_ready")
        UserDefaults.standard.set(isGenerating, forKey: "diet_planner_is_generating")
    }
}
```

For restoration, load on background then update UI:

```swift
private func restoreConversationState() {
    Task.detached(priority: .userInitiated) { [weak self] in
        guard let data = UserDefaults.standard.data(forKey: "diet_planner_chat_messages"),
              let messages = try? JSONDecoder().decode([ChatMessage].self, from: data) else {
            return
        }
        
        let generationId = UserDefaults.standard.string(forKey: "diet_planner_generation_id")
        let preferences = UserDefaults.standard.string(forKey: "diet_planner_preferences") ?? ""
        let readySummary = UserDefaults.standard.string(forKey: "diet_planner_ready_summary")
        let isGenerating = UserDefaults.standard.bool(forKey: "diet_planner_is_generating")
        let isReady = UserDefaults.standard.bool(forKey: "diet_planner_is_ready")
        
        await MainActor.run {
            guard let self = self, !messages.isEmpty else { return }
            
            self.chatMessages = messages
            self.currentGenerationId = generationId
            self.preferences = preferences
            self.readySummary = readySummary
            
            if isGenerating {
                self.viewState = .generating
            } else if isReady {
                self.viewState = .readyToGenerate
            } else {
                self.viewState = .conversing
            }
        }
    }
}
```

### Fix 3: Use Static DateFormatter

```swift
// GeminiAIService.swift
private static let logDateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    return formatter
}()

private func log(_ message: String) {
    #if DEBUG
    let timestamp = Self.logDateFormatter.string(from: Date())
    print("[\(timestamp)] [GeminiAIService] \(message)")
    #endif
}
```

Apply same pattern to:
- `AppLogger.swift`
- `ErrorHandler.swift`
- Any other service with logging

### Fix 4: Add Throttling to State Persistence

Instead of saving after every message, debounce saves:

```swift
private var saveWorkItem: DispatchWorkItem?

private func scheduleConversationStateSave() {
    saveWorkItem?.cancel()
    
    let workItem = DispatchWorkItem { [weak self] in
        self?.saveConversationState()
    }
    saveWorkItem = workItem
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
}
```

## Implementation Steps

1. [ ] Fix notification observer leak in `DietPlannerViewModel`
2. [ ] Fix notification observer leak in `WorkoutsViewModel` (same pattern)
3. [ ] Move `saveConversationState()` JSON work to background thread
4. [ ] Move `restoreConversationState()` JSON work to background thread
5. [ ] Add static DateFormatter to `GeminiAIService`
6. [ ] Add static DateFormatter to `AppLogger`
7. [ ] Add static DateFormatter to `ErrorHandler`
8. [ ] Add debouncing to conversation state saves
9. [ ] Test with Instruments (Time Profiler, Allocations) to verify fixes

## Testing Checklist

- [ ] Navigate to Diet Planner 20+ times, no memory growth
- [ ] Send 15+ messages in conversation, no UI lag
- [ ] Check Instruments: no retained ViewModels after navigation
- [ ] Check Instruments: Main thread never blocked > 16ms
- [ ] Long conversation (20+ messages) remains responsive

## Estimated Effort

3-4 hours including testing with Instruments

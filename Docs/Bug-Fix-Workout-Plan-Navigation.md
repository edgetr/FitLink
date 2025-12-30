# Bug Fix: Workout Plan Navigation After Generation

**Created:** 2025-12-30
**Status:** Planning
**Priority:** High
**Affected Files:**
- `FitLink/ViewModels/WorkoutsViewModel.swift`
- `FitLink/Views/WorkoutsView.swift`
- `FitLink/Utils/AppRouter.swift`
- `FitLink/Views/DashboardView.swift`
- `FitLink/FitLinkApp.swift`

## Problem Description

User reports: "I tried creating workouts, but it didn't work. I chatted with the model and it started creating both plans, then it sent me a notification telling me it's done, but when I opened that page (or clicked the notification), it was back to the initial AI Workouts page."

## Root Cause Analysis

### Issue 1: State Desync Between Local and Remote Generation

When the user navigates away during generation, two competing mechanisms try to update the state:

1. **Local TaskGroup**: `WorkoutsViewModel.startGeneration(for:)` runs `generateHomePlan` and `generateGymPlan` in parallel
2. **Background Sync**: `FitLinkApp.checkAndDisplayCompletedGenerations()` posts `.planGenerationCompleted` on app foreground

**Race Condition**: If the app goes to background during generation, the local TaskGroup may be suspended. When the app returns:
- `FitLinkApp` posts `.planGenerationCompleted` 
- `WorkoutsViewModel.handleGenerationCompletedNotification()` receives it and sets `flowState = .planReady`
- But the local TaskGroup may also still be running and can overwrite the state

### Issue 2: Navigation Not Actually Happening

Looking at the notification flow:

```
Notification tapped
  → NotificationService.didReceive() posts .navigateToPlan
  → AppRouter.handlePlanNavigationNotification() sets pendingRoute = .workouts
  → DashboardView.onChange(of: router.pendingRoute) appends to navigationPath
```

**The Problem**: The navigation pushes to `WorkoutsView()`, but `WorkoutsView` creates a **new** `@StateObject private var viewModel = WorkoutsViewModel()`. This new ViewModel:
1. Has no knowledge of the completed plan
2. Starts with `flowState = .idle`
3. `hasActivePlans` is `false` until `loadAllPlansForUser()` completes
4. Shows `WorkoutInputView` (the initial page) until plans are loaded

### Issue 3: Plan Loading Race with View Display

In `WorkoutsView.onAppear`:
```swift
.onAppear {
    if let userId = sessionManager.currentUserID {
        viewModel.userId = userId  // Triggers loadAllPlansForUser()
        Task {
            await viewModel.checkPendingGenerations()
        }
    }
}
```

The view renders immediately with `flowState = .idle`, showing `WorkoutInputView`. Then `loadAllPlansForUser()` runs asynchronously and may take time to complete.

## Solution Architecture

### Fix 1: Ensure Plan Loading Completes Before Showing Initial State

Modify `WorkoutsView` to show a loading state until `loadAllPlansForUser()` completes:

```swift
// WorkoutsView.swift
@ViewBuilder
private var contentView: some View {
    if viewModel.isLoadingPlans {
        WorkoutLoadingView(message: "Loading your workout plans...")
    } else if viewModel.isGenerating {
        // ... existing code
```

**Already implemented** - but the issue is `isLoadingPlans` is set to `false` by default and `loadAllPlansForUser()` sets it to `true` only when it starts.

**Fix**: Initialize `isLoadingPlans = true` or check if plans have been loaded at least once.

### Fix 2: Prevent State Overwrite from Stale TaskGroup

Add a generation ID to prevent stale TaskGroup results from overwriting newer state:

```swift
// WorkoutsViewModel.swift
private var activeGenerationUUID: UUID?

func startGeneration(for planTypes: [WorkoutPlanType]) async {
    let generationUUID = UUID()
    activeGenerationUUID = generationUUID
    
    // ... generation code ...
    
    // Before setting state, check if this generation is still active
    guard activeGenerationUUID == generationUUID else {
        log("Generation superseded, discarding results")
        return
    }
    
    if homePlan != nil || gymPlan != nil {
        flowState = .planReady
    }
}
```

### Fix 3: Improve Notification Completion Handler

The `handleGenerationCompletedNotification` should reload plans before transitioning state:

```swift
private func handleGenerationCompletedNotification(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let planTypeRaw = userInfo["planType"] as? String,
          let planType = GenerationPlanType(rawValue: planTypeRaw) else {
        return
    }
    
    guard planType == .workoutHome || planType == .workoutGym else { return }
    
    guard let resultPlanId = userInfo["resultPlanId"] as? String,
          !resultPlanId.isEmpty else {
        return
    }
    
    // Cancel any active generation since we have a completed plan
    activeGenerationUUID = nil
    isGeneratingHome = false
    isGeneratingGym = false
    
    Task { @MainActor in
        do {
            if let doc = try await workoutPlanService.loadPlan(byId: resultPlanId) {
                switch doc.planType {
                case .home:
                    homePlanDocument = doc
                    homePlan = doc.plan
                case .gym:
                    gymPlanDocument = doc
                    gymPlan = doc.plan
                }
                flowState = .planReady
                clearConversationState()
            }
        } catch {
            log("Error loading completed plan: \(error)")
            // Fallback: try loading all plans
            await loadAllPlansForUser()
        }
    }
}
```

### Fix 4: Add "Loaded" Tracking to Prevent Showing Input Before Data Loads

```swift
// WorkoutsViewModel.swift
@Published var hasLoadedInitialData = false

func loadAllPlansForUser() async {
    guard let userId = userId else { return }
    
    isLoadingPlans = true
    
    defer {
        isLoadingPlans = false
        hasLoadedInitialData = true
    }
    
    // ... existing load logic ...
}
```

```swift
// WorkoutsView.swift
@ViewBuilder
private var contentView: some View {
    if !viewModel.hasLoadedInitialData || viewModel.isLoadingPlans {
        WorkoutLoadingView(message: "Loading your workout plans...")
    } else if viewModel.isGenerating {
        // ... rest of cases
    }
}
```

## Implementation Steps

1. [ ] Add `hasLoadedInitialData` flag to `WorkoutsViewModel`
2. [ ] Add `activeGenerationUUID` to prevent stale state updates
3. [ ] Update `contentView` in `WorkoutsView` to wait for initial load
4. [ ] Improve `handleGenerationCompletedNotification` to cancel active generations
5. [ ] Add logging to trace the state transitions for debugging
6. [ ] Test scenarios:
   - Generate plan while staying in app
   - Generate plan, go to background, return via notification
   - Generate plan, go to background, return via app icon
   - Generate both plans with one failing

## Testing Checklist

- [ ] Start workout generation, stay in app → shows results
- [ ] Start workout generation, leave app, tap notification → shows results
- [ ] Start workout generation, leave app, return via icon → shows results
- [ ] Generate "Both" plans, one fails → shows partial success
- [ ] Tap notification for completed plan when already on Workouts page → shows results

## Estimated Effort

2-3 hours including testing

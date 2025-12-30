# Bug Fix: Watch Pairing Code Re-entry

**Created:** 2025-12-30
**Status:** Planning
**Priority:** Medium
**Affected Files:**
- `FitLinkWatch Watch App/Views/WatchPairingView.swift`
- `FitLinkWatch Watch App/Services/WatchSessionManager.swift`

## Problem Description

User reports: "In the Watch App, there is only 'Retry' after some time, but there is no way to enter the new code if the code changes until it's time to 'Retry'."

## Root Cause Analysis

### Current Flow

1. User enters 6-digit code on Watch
2. After 6th digit, `submitPairingCode()` is called
3. `pairingState` transitions to `.waitingForConfirmation`
4. UI switches from `inputView` to `waitingView`
5. `waitingView` shows "Verifying..." spinner
6. After 10 seconds with no response, shows "No Response" with "Retry" button

### The Problem

**In `waitingView`** (lines 65-96 of `WatchPairingView.swift`):

```swift
private var waitingView: some View {
    VStack(spacing: 12) {
        if waitingTimeoutSeconds < 10 {
            ProgressView()
                .tint(.accentColor)
                .scaleEffect(1.5)
            
            Text("Verifying...")
                .font(.system(.body, design: .rounded))
                .foregroundColor(.gray)
        } else {
            // Shows "Retry" button only
            Image(systemName: "exclamationmark.triangle.fill")
            Text("No Response")
            Button {
                retryPairing()  // Re-sends SAME code
            } label: {
                Text("Retry")
            }
        }
    }
}
```

**Issues**:

1. **No Cancel Button**: User cannot abort verification and go back to re-enter a different code
2. **Retry Uses Same Code**: `retryPairing()` just resends `enteredCode` without clearing it
3. **10-Second Wait Required**: User must wait 10 seconds before any action is possible
4. **Code Might Have Changed**: The TOTP code on iPhone rotates every 60 seconds. If user enters wrong code or code expires during verification, they're stuck.

### The `retryPairing()` Function

```swift
private func retryPairing() {
    stopWaitingTimer()
    sessionManager.submitPairingCode(enteredCode)  // Same code!
    startWaitingTimer()
}
```

This resends the **same previously entered code**, which may now be invalid if the TOTP window has passed.

## Solution Architecture

### Fix 1: Add "Cancel" Button to Waiting View

Allow user to abort verification at any time and return to code entry:

```swift
private var waitingView: some View {
    VStack(spacing: 12) {
        if waitingTimeoutSeconds < 10 {
            ProgressView()
                .tint(.accentColor)
                .scaleEffect(1.5)
            
            Text("Verifying...")
                .font(.system(.body, design: .rounded))
                .foregroundColor(.gray)
            
            // ADD: Cancel button even while verifying
            Button {
                cancelVerification()
            } label: {
                Text("Cancel")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            
        } else {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.yellow)
            
            Text("No Response")
                .font(.system(.footnote, design: .rounded))
                .foregroundColor(.gray)
            
            HStack(spacing: 12) {
                Button {
                    cancelVerification()
                } label: {
                    Text("New Code")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .buttonStyle(.bordered)
                
                Button {
                    retryPairing()
                } label: {
                    Text("Retry")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    .transition(.opacity)
    .onAppear { startWaitingTimer() }
    .onDisappear { stopWaitingTimer() }
}
```

### Fix 2: Add `cancelVerification()` Method

```swift
private func cancelVerification() {
    stopWaitingTimer()
    enteredCode = ""  // Clear the entered code
    sessionManager.resetPairingState()  // Go back to .notPaired
}
```

### Fix 3: Allow Code Clearing in Input View After Partial Entry

Currently, if user enters 5 digits and realizes they made a mistake, they must delete one by one. Add a "Clear All" gesture:

```swift
private var inputView: some View {
    VStack(spacing: 4) {
        // ... existing header
        
        HStack(spacing: 6) {
            ForEach(0..<6) { index in
                Circle()
                    .fill(index < enteredCode.count ? Color.white : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.bottom, 2)
        .onLongPressGesture(minimumDuration: 0.5) {
            // Long press to clear all
            enteredCode = ""
            WKInterfaceDevice.current().play(.click)
        }
        
        // ... existing numpad
    }
}
```

### Fix 4: Show Remaining TOTP Time Hint (Optional Enhancement)

On the iPhone side, show how much time remains for the current code:

```swift
// In iPhone's WatchPairingView, show countdown
Text("Code expires in \(remainingSeconds)s")
    .font(.caption)
    .foregroundStyle(.secondary)
```

This helps users know if they should wait for a new code before entering.

## Alternative: Swipe-to-Cancel Gesture

Add a swipe gesture to the waiting view for quick cancel:

```swift
private var waitingView: some View {
    VStack(spacing: 12) {
        // ... existing content
    }
    .gesture(
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                if value.translation.width > 50 {
                    // Swipe right to cancel
                    cancelVerification()
                }
            }
    )
}
```

## Implementation Steps

1. [ ] Add `cancelVerification()` method to `WatchPairingView`
2. [ ] Add "Cancel" button to `waitingView` (visible during verification)
3. [ ] Change "Retry" timeout view to show both "New Code" and "Retry" buttons
4. [ ] Add long-press gesture to code dots for "Clear All"
5. [ ] (Optional) Add swipe-to-cancel gesture
6. [ ] (Optional) Show TOTP countdown on iPhone pairing view
7. [ ] Test on Watch simulator

## State Machine Update

```
Current:
.notPaired → [enter 6 digits] → .waitingForConfirmation → [10s timeout] → Retry only
                                                        → [response] → .paired/.denied

Proposed:
.notPaired → [enter 6 digits] → .waitingForConfirmation → [Cancel] → .notPaired (clear code)
                                                        → [10s timeout] → "New Code" → .notPaired
                                                                       → "Retry" → .waitingForConfirmation
                                                        → [response] → .paired/.denied
```

## Testing Checklist

- [ ] Enter correct code → successful pairing
- [ ] Enter wrong code → denied → can enter new code
- [ ] Enter code, tap Cancel while verifying → returns to input with empty code
- [ ] Enter code, wait 10s, tap "New Code" → returns to input with empty code
- [ ] Enter code, wait 10s, tap "Retry" → re-verifies same code
- [ ] Long press on code dots → clears all entered digits
- [ ] Code expires during verification → Cancel works, can enter new code

## Estimated Effort

1-2 hours including Watch simulator testing

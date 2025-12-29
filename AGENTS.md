# FitLink Agent Guidelines

**Generated:** 2025-12-29
**Commit:** c35894c
**Branch:** main

## Overview

iOS 18+ fitness/health app with AI-powered diet/workout planning, habit tracking, and social features. Uses Gemini AI (Flash for chat, Pro for generation), Firebase Firestore, HealthKit, and iOS 26 Liquid Glass UI.

## Commands

```bash
# Build (always use iPhone 17 Pro)
xcodebuild -project FitLink.xcodeproj -scheme FitLink \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Build (filter output)
xcodebuild ... 2>&1 | grep -E "(BUILD|error:|warning:.*FitLink/)"

# Test all
xcodebuild -project FitLink.xcodeproj -scheme FitLink \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Test single class
xcodebuild test -project FitLink.xcodeproj -scheme FitLink \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FitLinkTests/TestClassName

# Test single method
xcodebuild test -project FitLink.xcodeproj -scheme FitLink \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FitLinkTests/TestClassName/testMethodName

# Security scan
./scripts/scan-secrets.sh --all

# XcodeBuildMCP (preferred): Use session-set-defaults + build_sim/build_run_sim
```

**Git**: Always use Graphite (`gt`) for branching, commits, and PRs.

## Structure

```
FitLink/
├── Models/           # Codable structs, snake_case CodingKeys for Firestore
├── Services/         # actors (thread-safe) or @MainActor classes (UI-bound)
├── ViewModels/       # @MainActor class + ObservableObject + @Published
├── Views/            # SwiftUI views using GlassTokens design system
│   ├── Auth/         # Authentication flow
│   ├── Dashboard/    # Activity patterns
│   ├── Onboarding/   # Health permissions, tour overlay
│   ├── Settings/     # Profile editors, memories
│   ├── Shared/       # Reusable components (ChatConversation, EmptyState)
│   └── Social/       # Friends, profile, settings
└── Utils/            # Glass UI components, extensions, managers
FitLinkLiveActivity/  # Widget extension for Focus Timer Dynamic Island
scripts/              # Security scanning
```

## Code Style

### Type Patterns
```swift
// Services: actor for thread-safety
actor GeminiAIService {
    static let shared = GeminiAIService()
    func generatePlan(...) async throws -> Plan
}

// Services with UI binding: final class @MainActor
@MainActor
final class SessionManager: ObservableObject { ... }

// ViewModels: @MainActor class
@MainActor
class DietPlannerViewModel: ObservableObject {
    @Published var viewState: DietPlannerViewState = .idle
}

// Models: struct with Codable, snake_case CodingKeys
struct User: Identifiable, Codable {
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case photoURL = "photo_url"
    }
    func toDictionary() -> [String: Any] { ... }
    static func fromDictionary(_ data: [String: Any], id: String) -> User? { ... }
}
```

### Imports & Organization
```swift
import SwiftUI
import Combine          // Required for @Published
import FirebaseFirestore
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Section Name
// Use MARK comments extensively for code organization
```

### Naming Conventions
- **Services**: `*Service`, `*Manager`, `*Coordinator`
- **ViewModels**: `*ViewModel`
- **Protocols**: `*Protocol` suffix for DI (e.g., `DietPlanServiceProtocol`)
- **Enums**: PascalCase names, camelCase cases
- **Firestore keys**: snake_case in CodingKeys

### Error Handling
```swift
// Use ErrorHandler for unified error handling
let appError = ErrorHandler.shared.handle(error, category: .network)

// Use AppLogger for categorized logging
AppLogger.shared.info("Message", category: .health)
AppLogger.shared.error("Failed: \(error)", category: .ai)

// Never use empty catch blocks
do { try action() } catch { AppLogger.shared.error("Failed: \(error)") }
```

### Glass UI (GlassTokens)
```swift
// Spacing
GlassTokens.Padding.small     // 8pt - related elements
GlassTokens.Padding.standard  // 16pt - default
GlassTokens.Padding.section   // 24pt - sections
GlassTokens.Layout.pageHorizontalPadding  // 20pt

// Corner radii
GlassTokens.Radius.small   // 8pt - buttons
GlassTokens.Radius.card    // 16pt - cards
GlassTokens.Radius.overlay // 20pt - sheets
GlassTokens.Radius.pill    // 24pt - capsules

// Use .symmetricPadding() NOT .padding(horizontal:vertical:) - iOS 26 conflict
view.symmetricPadding(horizontal: 20, vertical: 12)

// iOS 26+ native glass
@available(iOS 26.0, *)
view.glassEffect(.regular.interactive(), in: Capsule())
```

## Anti-Patterns (NEVER Do)

| Pattern | Why | Alternative |
|---------|-----|-------------|
| Force unwraps `!` | Crashes | `guard let`, `if let`, `??` |
| `as any`, type erasure | Type safety | Fix actual type |
| Empty catch blocks | Silent failures | Log and handle |
| Direct styling values | Inconsistent UI | Use `GlassTokens.*` |
| `.padding(horizontal:vertical:)` | iOS 26 conflict | `.symmetricPadding()` |
| Blocking main thread | UI freeze | `async/await` with actors |
| `Task {}` in actors without `@Sendable` | Concurrency bug | Use `@Sendable` closures |
| Commit sensitive files | Security leak | Listed in `.gitignore` |

**Sensitive files (never commit)**: `APIConfig.local.plist`, `GoogleService-Info.plist`, `.env*`, `*.secret`

## Key Patterns

### Service Access (Dual Pattern)
```swift
DietPlanService.shared           // Quick access
appEnvironment.dietPlanService   // Testable via DI
```

### ViewModel State Machine
```swift
enum DietPlannerViewState: Equatable {
    case idle, loading, generating, conversing, ...
}
@Published var viewState: DietPlannerViewState = .idle
```

### AI Model Routing (GeminiAIService)
- **Flash**: Conversational chat, minimal thinking
- **Pro**: Plan generation, high thinking
- Task types: `.conversationalGathering`, `.dietPlanGeneration`, `.workoutPlanGeneration`

### Health Data Flow
```
HealthKit → HealthDataCollector (actor)
         → HealthKitRepository (actor, anchored queries)
         → HealthMetricsService → Firestore
         → HealthSyncScheduler (BGTaskScheduler)
```

## Where to Look

| Task | Location | Notes |
|------|----------|-------|
| Add AI feature | `Services/GeminiAIService.swift` | Actor, model routing |
| Add plan type | `Services/PlanGenerationCoordinator.swift` | State machine |
| Modify diet flow | `ViewModels/DietPlannerViewModel.swift` | viewState enum |
| Add glass component | `Utils/Glass*.swift` | Follow GlassTokens |
| Health data sync | `Services/HealthDataCollector.swift` | Actor, batch ops |
| Add notification | `Services/NotificationService.swift` | Categories defined |
| Firebase CRUD | Model's `toDictionary()`/`fromDictionary()` | snake_case keys |
| Live Activity | `FitLinkLiveActivity/` | Shared attributes in Models/ |
| Error handling | `Utils/ErrorHandler.swift` | Categorized, user-friendly |
| Logging | `Utils/AppLogger.swift` | Category-based |

## Notes

- **Simulator**: Always `iPhone 17 Pro`
- **XcodeBuildMCP**: Preferred for building/testing
- **Firebase**: 100MB Firestore cache in `FitLinkApp.swift`
- **Background sync**: `HealthSyncScheduler` uses BGTaskScheduler
- **Live Activities**: App Group `group.com.fitlink.shared`
- **Encryption**: `ChatEncryptionService` uses X25519 + AES-256-GCM, keys in Keychain

See `UI_practices.md` for complete Liquid Glass design patterns.
See `Services/SERVICES_AGENTS.md` and `Utils/UTILS_AGENTS.md` for detailed module guidance.

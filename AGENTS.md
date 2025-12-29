# FitLink Agent Guidelines

**Generated:** 2025-12-29
**Commit:** ec5c3aa
**Branch:** 12-28-feat_comprehensive_app_enhancements_with_health_tracking_diet_planning_and_social_features

## Overview

iOS 18+ fitness/health app with AI-powered diet/workout planning, habit tracking, and social features. Uses Gemini AI for conversational plan generation, Firebase Firestore for persistence, HealthKit for metrics, and iOS 26 Liquid Glass UI.

## Structure

```
FitLink/
├── Models/           # Data models (Codable structs, CodingKeys for Firestore)
├── Services/         # Business logic (actors for thread-safety, singletons + DI)
├── ViewModels/       # @MainActor ObservableObject with @Published state
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

## Where to Look

| Task | Location | Notes |
|------|----------|-------|
| Add AI feature | `Services/GeminiAIService.swift` | Actor-based, model routing by task type |
| Add new plan type | `Services/PlanGenerationCoordinator.swift` | State machine pattern |
| Modify diet flow | `ViewModels/DietPlannerViewModel.swift` | viewState enum is source of truth |
| Add glass component | `Utils/Glass*.swift` | Follow GlassTokens spacing/radii |
| Health data sync | `Services/HealthDataCollector.swift` | Actor, batch operations |
| Add notification | `Services/NotificationService.swift` | Categories defined, schedule methods |
| Firebase persistence | Model's `toDictionary()`/`fromDictionary()` | snake_case CodingKeys |
| Live Activity | `FitLinkLiveActivity/` | Shared attributes in Models/ |

## Commands

```bash
# Build
xcodebuild -project FitLink.xcodeproj -scheme FitLink -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Test all
xcodebuild -project FitLink.xcodeproj -scheme FitLink -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Test single
xcodebuild test -project FitLink.xcodeproj -scheme FitLink -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FitLinkTests/TestClassName/testMethodName

# Filter build output (FitLink errors/warnings only)
xcodebuild ... 2>&1 | grep -E "(BUILD|error:|warning:.*FitLink/)"

# Security scan
./scripts/scan-secrets.sh --all
```

## Conventions

### Type Patterns
- **Services**: `actor` for thread-safe services (`GeminiAIService`, `HealthDataCollector`, `MemoryService`)
- **Services with UI binding**: `final class` with `@MainActor` (`SessionManager`, `FocusTimerManager`)
- **ViewModels**: `@MainActor class` + `ObservableObject` + `@Published`
- **Models**: `struct` with `Codable`, `CodingKeys` use `snake_case` for Firestore

### Service Access Pattern
```swift
// Dual access: singleton for convenience, injection via AppEnvironment
DietPlanService.shared  // Quick access
appEnvironment.dietPlanService  // For testability
```

### ViewModel State Machine
```swift
// Single source of truth via viewState enum
enum DietPlannerViewState {
    case idle, loading, generating, conversing, ...
}
@Published var viewState: DietPlannerViewState = .idle
```

### iOS Version Handling
- Target iOS 18+, Liquid Glass APIs require iOS 26
- Use `@available(iOS 26.0, *)` checks for native glass
- `LiquidGlass*` components auto-fallback to material on older iOS

### Code Organization
- Use `// MARK: -` sections extensively
- Imports: `SwiftUI`, `Combine` (for `@Published`), `#if canImport(UIKit)`

## Anti-Patterns (NEVER Do)

| Pattern | Why | Alternative |
|---------|-----|-------------|
| `as any`, `@ts-ignore` | Type safety violation | Fix the actual type |
| Force unwraps `!` | Crashes | `guard let`, `if let`, `??` |
| Empty catch blocks | Silent failures | Log and handle errors |
| Direct styling without GlassTokens | Inconsistent UI | Use `GlassTokens.Radius.*`, `GlassTokens.Padding.*` |
| Blocking main thread for network | UI freeze | `async/await` with actors |
| Committing `APIConfig.local.plist`, `GoogleService-Info.plist` | Security leak | Listed in `.gitignore` |

## Unique Patterns

### AI Plan Generation Flow
1. User starts conversation → `PlanGenerationCoordinator` manages state machine
2. Conversation persisted to Firestore via `PlanGenerationService`
3. `GeminiAIService` routes to appropriate model (Flash for chat, Pro for generation)
4. Response validated via `DietPlanResponseValidator` / extracted JSON
5. Partial success handled by `DietPlanPartialSuccessHandler`

### Health Data Architecture
```
HealthKit → HealthDataCollector (actor)
         → HealthKitRepository (actor, anchored queries)
         → HealthMetricsService → Firestore
         → HealthSyncScheduler (background refresh)
```

### Memory System
`MemoryService` (actor) stores user preferences, learned patterns, conversation context to Firestore. Used by `ContextAwarePromptBuilder` to personalize AI responses.

## Notes

- **Simulator**: Always use `iPhone 17 Pro` for builds
- **Graphite**: Use `gt` commands for git operations (branching, commits, PRs)
- **XcodeBuildMCP**: Preferred for building/testing via simulator interaction
- **Firebase**: 100MB Firestore cache configured in `FitLinkApp.swift`
- **Background sync**: `HealthSyncScheduler` uses BGTaskScheduler for health data refresh
- **Live Activities**: Focus timer state shared via App Group `group.com.fitlink.shared`

See `UI_practices.md` for complete Liquid Glass design patterns.

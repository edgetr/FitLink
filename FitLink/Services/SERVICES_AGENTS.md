# FitLink/Services

Business logic layer with thread-safe actors and singleton services.

## Type Classification

| Type | Pattern | Examples |
|------|---------|----------|
| `actor` | Thread-safe, no UI binding | `GeminiAIService`, `HealthDataCollector`, `MemoryService`, `HabitStore`, `HabitAIService` |
| `final class @MainActor` | UI-bound ObservableObject | `SessionManager`, `FocusTimerManager`, `NotificationService` |
| `final class` | Singleton, Firestore ops | `DietPlanService`, `WorkoutPlanService`, `UserService` |
| `struct` | Stateless utilities | `ContextAwarePromptBuilder`, `PatternAnalyzer`, `DietPlanResponseValidator` |

## Where to Look

| Task | File | Notes |
|------|------|-------|
| AI chat/generation | `GeminiAIService.swift` | Model routing: Flash (chat), Pro (generation) |
| Plan state machine | `PlanGenerationCoordinator.swift` | `BasePlanGenerationCoordinator` base class |
| Diet plan CRUD | `DietPlanService.swift` | Firestore, `DietPlanServiceProtocol` |
| Workout plan CRUD | `WorkoutPlanService.swift` | Firestore, `WorkoutPlanServiceProtocol` |
| Health data sync | `HealthDataCollector.swift` | HealthKit → Firestore, batch ops |
| Incremental health queries | `HealthKitRepository.swift` | Anchored queries, multi-day aggregates |
| Background refresh | `HealthSyncScheduler.swift` | BGTaskScheduler registration |
| User context for AI | `UserContextProvider.swift` | Cached LLM context building |
| Memory/preferences | `MemoryService.swift` | User preferences, learned patterns |
| Focus timer | `FocusTimerManager.swift` | Live Activity integration |
| Permissions | `PermissionCoordinator.swift` | Health, location, notifications |
| Diet validation | `DietPlanResponseValidator.swift` | JSON extraction, validation |
| Partial success | `DietPlanPartialSuccessHandler.swift` | Handle incomplete AI responses |

## Key Patterns

### Actor Isolation
```swift
actor GeminiAIService {
    static let shared = GeminiAIService()
    func generatePlan(...) async throws -> Plan
}
// Usage: await GeminiAIService.shared.generatePlan(...)
```

### Service Protocol + DI
```swift
// Protocol in AppEnvironment.swift
protocol DietPlanServiceProtocol: AnyObject { ... }

// Service conforms
class DietPlanService: DietPlanServiceProtocol { ... }

// Dual access
DietPlanService.shared  // Quick
appEnvironment.dietPlanService  // Testable
```

### AI Model Routing (GeminiAIService)
- **Flash**: Conversational chat, low thinking
- **Pro**: Plan generation, high thinking
- Task types: `.conversationalChat`, `.planGeneration`, `.validation`

### Health Data Flow
```
HealthKit → HealthDataCollector.collectAllMetrics()
         → HealthKitRepository.collectHourlyData()  
         → HealthMetricsService.saveDailyMetrics()
         → Firestore users/{uid}/healthMetrics/
```

## Anti-Patterns

- Never call actor methods from `@MainActor` without `await`
- Never use `Task { }` in actors without `@Sendable` closures
- Never store UIKit references in actors

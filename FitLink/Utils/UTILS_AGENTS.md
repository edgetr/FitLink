# FitLink/Utils

Reusable utilities, Glass UI components, and SwiftUI extensions.

## Glass Design System

All glass components auto-fallback: native `.glassEffect()` on iOS 26+, `.ultraThinMaterial` on earlier.

| Component | Usage |
|-----------|-------|
| `GlassCard` | Content containers with optional tint |
| `GlassIconButton` | Circle icon buttons |
| `GlassTextPillButton` | CTA buttons (regular/prominent) |
| `GlassHelpButton` | Floating help trigger |
| `LiquidGlassDateStrip` | Horizontal date picker |
| `LiquidGlassSegmentedPicker` | Segmented control with morph |

## GlassTokens Reference

```swift
// Corner radii
GlassTokens.Radius.small   // 8pt - buttons
GlassTokens.Radius.card    // 16pt - cards
GlassTokens.Radius.overlay // 20pt - sheets
GlassTokens.Radius.pill    // 24pt - capsules

// Padding
GlassTokens.Padding.small    // 8pt - related elements
GlassTokens.Padding.compact  // 12pt - compact mode
GlassTokens.Padding.standard // 16pt - default
GlassTokens.Padding.section  // 24pt - sections
GlassTokens.Padding.large    // 32pt - breaks

// Layout
GlassTokens.Layout.pageHorizontalPadding // 20pt
GlassTokens.Layout.cardSpacing(for: screenHeight) // Adaptive
```

## Where to Look

| Task | File |
|------|------|
| Add glass component | `Glass*.swift`, follow GlassTokens |
| Conditional modifiers | `View+If.swift` - `.if()`, `.ifLet()` |
| Onboarding tour | `OnboardingTour/OnboardingTourCoordinator.swift` |
| Deep links | `AppRouter.swift` - URL handling |
| Logging | `AppLogger.swift` - category-based |
| Caching | `CacheManager.swift` - images, responses |
| Streaks | `StreakManager.swift` - habit streaks |
| Network status | `NetworkManager.swift` - connectivity |
| Feature flags | `FeatureFlags.swift` - toggles |
| Error display | `UserFriendlyErrorMessages.swift` |

## View Extensions (View+If.swift)

```swift
// Conditional modifier
view.if(condition) { $0.opacity(0.5) }

// With else branch
view.if(condition, ifTrue: { $0.foregroundColor(.green) }, ifFalse: { $0.foregroundColor(.red) })

// Optional binding
view.ifLet(optionalValue) { view, value in view.badge(value) }

// Symmetric padding (avoids iOS 26 conflict)
view.symmetricPadding(horizontal: 20, vertical: 12)
```

## Anti-Patterns

- Never hardcode spacing/radii - use GlassTokens
- Never use `.padding(horizontal:vertical:)` - conflicts with iOS 26, use `.symmetricPadding()`
- Never skip `@available(iOS 26.0, *)` for native glass APIs

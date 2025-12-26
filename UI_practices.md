# FitLink UI Design & Development Practices

This document outlines the UI patterns, design tokens, and development conventions for the FitLink iOS app. Following these guidelines ensures a consistent visual experience across all screens and iOS versions.

## Design Tokens (GlassTokens)

All layout and styling constants should be referenced from `GlassTokens`.

### Radius Values
Use these standard corner radii for consistent rounding:
- **Small (8pt):** Buttons, small interactive elements.
- **Card (16pt):** Primary content cards (standard).
- **Overlay (20pt):** Sheets, modals, and large overlay elements.
- **Pill (24pt):** Capsule-shaped buttons and status indicators.

### Layout Constants
- **Page Horizontal Padding:** `GlassTokens.Layout.pageHorizontalPadding` (20pt).
- **Page Bottom Inset:** `GlassTokens.Layout.pageBottomInset` (16pt).
- **Card Spacing:** 16pt (standard). Use `GlassTokens.Layout.cardSpacing(for: screenHeight)` for adaptive layouts.

---

## iOS Version Compatibility

### iOS 26+ Native Liquid Glass
On iOS 26 and later, use Apple's **native** Liquid Glass APIs for authentic glass appearance:

**Core APIs:**
- `.glassEffect(.regular, in: Shape())` — Apply glass effect to any view
- `.glassEffect(.regular.interactive(), in: Shape())` — Interactive glass that responds to touch
- `GlassEffectContainer` — Groups glass elements for morphing animations
- `.glassEffectID("id", in: namespace)` — Enables smooth morphing between glass elements
- `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)` — Native glass button styles

**Example - Native Glass Segmented Picker:**
```swift
@available(iOS 26.0, *)
struct NativeGlassPicker: View {
    @Binding var selection: Int
    @Namespace private var namespace
    
    var body: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<3) { index in
                    Button { selection = index } label: {
                        Text("Option \(index)")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .modifier(GlassSelectionModifier(
                        isSelected: selection == index,
                        namespace: namespace
                    ))
                }
            }
        }
    }
}

@available(iOS 26.0, *)
struct GlassSelectionModifier: ViewModifier {
    let isSelected: Bool
    let namespace: Namespace.ID
    
    func body(content: Content) -> some View {
        if isSelected {
            content
                .glassEffect(.regular.interactive(), in: Capsule())
                .glassEffectID("selection", in: namespace)
        } else {
            content
        }
    }
}
```

**Key Principles for Native Glass:**
1. Apply `.glassEffect()` only to the SELECTED element, not all elements
2. Use `GlassEffectContainer` to enable morphing between selections
3. Use `.glassEffectID()` with a shared namespace for smooth animation
4. Wrap selection changes in `withAnimation(.spring())` for fluid motion
5. Use `.interactive()` for elements that respond to touch

### iOS 18-25 Material Fallback
On earlier iOS versions, use `.ultraThinMaterial` with overlays:
```swift
.background(
    RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous)
                .fill(tintColor?.opacity(0.1) ?? Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
        )
)
.shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
```

### Version-Specific API Usage
When an API conflict exists with iOS 26, rename custom extensions:
```swift
// AVOID: Conflicts with iOS 26 SwiftUI padding overload
func padding(horizontal: CGFloat, vertical: CGFloat) -> some View

// USE: Unique name that won't conflict
func symmetricPadding(horizontal: CGFloat, vertical: CGFloat) -> some View
```

---

## Color Conventions

FitLink uses a combination of system colors and glass effects.

### System Colors
- **App Background:** `UIColor.systemGroupedBackground` for scrollable views.
- **Content Background:** `UIColor.systemBackground` for secondary surfaces.

### Gradient Patterns
Vibrant gradients for primary icons and active states:
```swift
LinearGradient(
    colors: [.blue, .purple],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```

---

## Spacing & Layout

### Horizontal Spacing
- **20pt** for page edges (breathable content).
- **16pt** for internal card padding (12pt in compact modes).

### Vertical Spacing Scale
- **8pt:** Between related elements (Title/Subtitle).
- **12pt:** Compact card spacing.
- **16pt:** Standard component spacing.
- **24pt:** Section spacing.
- **32pt:** Large layout breaks.

### Fit to Screen Requirement
Primary pages should fit on screen without scrolling when possible:
- Use `GeometryReader` to calculate available height.
- Implement **Compact Mode** for smaller screens (<700pt height).
- Compact mode: reduce spacing, decrease icon sizes, hide secondary descriptions.

---

## Typography Hierarchy

| Style | Weight | Usage |
| :--- | :--- | :--- |
| `.largeTitle` | `.bold` | Primary page headers |
| `.title` / `.title2` | `.bold` / `.semibold` | Section headers |
| `.headline` | `.semibold` | Card titles, button text |
| `.subheadline` | `.medium` / `.regular` | Secondary text, descriptions |
| `.caption` | `.medium` | Meta data, supplementary info |
| `.caption2` | `.medium` | Tiny labels (date strips) |

---

## Component Patterns

### Glass Components
All glass components automatically use Material fallback on iOS <26:

| Component | Description |
| :--- | :--- |
| `GlassCard` | Container for grouped content with optional tint |
| `GlassIconButton` | Circle button for single actions |
| `GlassTextPillButton` | Pill-shaped CTA button (regular/prominent) |
| `GlassHelpButton` | Floating help/info trigger |
| `LiquidGlassDateStrip` | Horizontal date picker with fluid selection |
| `LiquidGlassSegmentedPicker` | Segmented control with native glass selection (iOS 26) / material fallback |

### Liquid Glass Design Guidelines

#### iOS 26+ (Native APIs)
On iOS 26, **always prefer native `.glassEffect()` APIs** over custom implementations:

```swift
// Native glass - automatically handles refraction, blur, and interactivity
Text("Option")
    .glassEffect(.regular.interactive(), in: Capsule())
```

The native API provides:
- True refraction and depth effects
- Automatic light/dark mode adaptation
- Built-in interactive animations (shimmer, scale on press)
- Seamless system integration

#### Pre-iOS 26 (Material Fallback)
On earlier iOS versions, approximate glass with materials and overlays:

1. **Use thicker materials**: Prefer `.regularMaterial` over `.ultraThinMaterial` for more visible blur depth.

2. **Inner highlight gradients**: Simulate light refraction with top-to-center gradients:
   ```swift
   .overlay(
       Capsule()
           .fill(
               LinearGradient(
                   colors: [
                       Color.white.opacity(colorScheme == .dark ? 0.15 : 0.6),
                       Color.white.opacity(colorScheme == .dark ? 0.05 : 0.2),
                       Color.clear
                   ],
                   startPoint: .top,
                   endPoint: .center
               )
           )
   )
   ```

3. **Gradient borders**: Use gradient strokes instead of solid colors for liquid edges:
   ```swift
   .strokeBorder(
       LinearGradient(
           colors: [
               Color.white.opacity(colorScheme == .dark ? 0.3 : 0.7),
               Color.white.opacity(colorScheme == .dark ? 0.1 : 0.3),
               Color.primary.opacity(0.1)
           ],
           startPoint: .top,
           endPoint: .bottom
       ),
       lineWidth: 1
   )
   ```

4. **Layered shadows**: Use multiple shadows for realistic depth:
   ```swift
   .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)  // Tight shadow
   .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)  // Diffuse shadow
   ```

5. **Spring animations**: Use spring animations for fluid motion:
   ```swift
   withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
       selection = newValue
   }
   ```

6. **Adapt to color scheme**: Always check `colorScheme` and adjust opacities (higher in light mode, lower in dark mode).

#### Version-Adaptive Components
All `LiquidGlass*` components in FitLink automatically use native APIs on iOS 26+ and fall back to styled materials on earlier versions. No version checks needed in calling code:

```swift
// Works on all iOS versions - native glass on 26+, material fallback on older
LiquidGlassSegmentedPicker(
    selection: $selection,
    options: [(0, "Option A"), (1, "Option B")],
    namespace: namespace
)
```

### Using Glass Components
```swift
// Card with tint
GlassCard(tint: .blue) {
    Text("Content")
        .padding()
}

// Icon button
GlassIconButton(systemName: "gear", tint: .primary) {
    showSettings()
}

// Pill button (prominent)
GlassTextPillButton("Continue", icon: "arrow.right", tint: .blue, isProminent: true) {
    nextStep()
}
```

---

## Navigation & Transitions

### Navigation Patterns
- Use `NavigationStack` with `.navigationBarTitleDisplayMode(.inline)`.
- Use `ScrollView` with `.frame(minHeight: geometry.size.height)` for full-screen backgrounds.

### Animations
- **Interactions:** `.bouncy(duration: 0.3)` for button presses.
- **Transitions:** `.smooth(duration: 0.3)` for view changes.
- **Fluid UI:** `@Namespace` and `.matchedGeometryEffect` for card-to-detail transitions.

---

## Required Imports

Files using `@Published` or `ObservableObject` must import Combine:
```swift
import SwiftUI
import Combine
```

---

## Launch Screen Configuration

The app must have a launch screen to support modern device sizes. Add to Info.plist:
```xml
<key>UILaunchScreen</key>
<dict/>
```

Or use the Xcode build setting:
```
INFOPLIST_KEY_UILaunchScreen_Generation = YES
```

Without this, the app displays in letterboxed compatibility mode with black bars.

---

## Haptic Feedback

Use `.sensoryFeedback()` for interactive elements:
```swift
Button(action: action) {
    // content
}
.sensoryFeedback(.selection, trigger: UUID())
```

---

## Accessibility

Use the `accessibilityConfigured` helper for common patterns:
```swift
view.accessibilityConfigured(
    label: "Description",
    hint: "Double tap to activate",
    traits: .isButton
)
```

---

## View Extensions

### Conditional Modifiers
```swift
// Apply modifier conditionally
view.if(condition) { $0.opacity(0.5) }

// Apply different modifiers based on condition
view.if(condition, ifTrue: { $0.foregroundColor(.green) }, ifFalse: { $0.foregroundColor(.red) })

// Apply modifier with unwrapped optional
view.ifLet(optionalValue) { view, value in
    view.badge(value)
}
```

### Symmetric Padding
```swift
// Apply horizontal and vertical padding separately
view.symmetricPadding(horizontal: 20, vertical: 12)
```

---

## File Organization

```
FitLink/
├── Models/           # Data models
├── ViewModels/       # ObservableObject view models
├── Views/            # SwiftUI views
│   ├── Auth/         # Authentication views
│   └── Social/       # Social features
├── Services/         # API and system services
├── Utils/            # Utilities and extensions
│   ├── GlassCard.swift
│   ├── GlassIconButton.swift
│   ├── GlassTextPillButton.swift
│   ├── GlassHelpButton.swift
│   ├── GlassTokens.swift
│   └── View+If.swift
└── Assets.xcassets/  # Images and colors
```

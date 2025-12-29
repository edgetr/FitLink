# Lottie Animations Architecture Plan for FitLink

## Executive Summary

This document outlines a phased approach to integrate Lottie animations into FitLink, enhancing user delight through celebration feedback, loading states, and empty state illustrations. The implementation prioritizes performance, accessibility, and seamless integration with the existing Liquid Glass design system.

**Scope**: 12 animation types across 4 categories
**Timeline**: 4 weeks (16 dev-days)
**Priority**: P0 animations ship Week 2, full feature Week 4

---

## Animation Inventory

| Animation Name | Category | Trigger | View(s) | Priority | Size Target |
|---------------|----------|---------|---------|----------|-------------|
| `confetti-celebration` | Celebration | Streak milestone (7, 30, 100 days) | HabitTrackerView | P0 | < 100KB |
| `success-checkmark` | Celebration | Habit completion | HabitRow | P0 | < 50KB |
| `trophy-spin` | Celebration | All daily habits complete | HabitTrackerView | P1 | < 80KB |
| `fitness-loader` | Loading | General loading states | All views | P0 | < 60KB |
| `brain-thinking` | Loading | AI generation in progress | DietPlannerView, WorkoutsView | P0 | < 80KB |
| `person-stretching` | Empty State | No workouts scheduled | WorkoutsView | P1 | < 100KB |
| `empty-plate` | Empty State | No diet plan | DietPlannerView | P1 | < 100KB |
| `meditation-calm` | Empty State | No habits | HabitTrackerView | P1 | < 100KB |
| `heart-pulse` | Micro-feedback | Heart rate sync | DashboardView | P2 | < 30KB |
| `fire-growing` | Micro-feedback | Streak increase | HabitRow | P2 | < 40KB |
| `steps-walking` | Micro-feedback | Steps milestone | DashboardView | P2 | < 40KB |
| `sleep-zzz` | Micro-feedback | Sleep data available | SleepDetailView | P2 | < 30KB |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        SwiftUI View Layer                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐      │
│  │ HabitTrackerView│  │ DietPlannerView │  │   WorkoutsView  │      │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘      │
│           │                    │                    │                │
│  ┌────────▼────────────────────▼────────────────────▼────────┐      │
│  │                    View Modifiers                          │      │
│  │  .confettiOverlay()  .loadingOverlay()  .successCheckmark()│      │
│  └────────────────────────────┬──────────────────────────────┘      │
└───────────────────────────────┼──────────────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────────────┐
│                      Animation Components                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐       │
│  │ ConfettiOverlay │  │ LoadingAnimation│  │EmptyStateAnimat.│       │
│  │   (full-screen) │  │   (centered)    │  │  (with CTA)     │       │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘       │
│           │                    │                    │                 │
│  ┌────────▼────────────────────▼────────────────────▼────────┐       │
│  │                      LottieView                            │       │
│  │         (UIViewRepresentable wrapper)                      │       │
│  └────────────────────────────┬──────────────────────────────┘       │
└───────────────────────────────┼──────────────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────────────┐
│                         LottieManager                                 │
│  ┌─────────────────────────────────────────────────────────────┐     │
│  │  • Singleton with preload queue                              │     │
│  │  • Animation cache (NSCache)                                 │     │
│  │  • Memory pressure handling                                  │     │
│  │  • Reduce Motion fallback coordination                       │     │
│  └─────────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────────────┐
│                    Resources/Animations/                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────┐  │
│  │ celebration/ │  │   loading/   │  │ empty-states/│  │ feedback/│  │
│  │  confetti    │  │  fitness     │  │  stretching  │  │  heart   │  │
│  │  checkmark   │  │  brain       │  │  plate       │  │  fire    │  │
│  │  trophy      │  │              │  │  meditation  │  │  steps   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Implementation Plan

### Phase 1: Foundation Setup (Week 1, Days 1-3)

**Objective**: Add Lottie dependency, create core wrapper components, establish caching infrastructure.

#### 1.1 Add lottie-ios via SPM

Add to `FitLink.xcodeproj`:
- Package: `https://github.com/airbnb/lottie-ios`
- Version: `4.4.0` (minimum)
- Target: `FitLink`

#### 1.2 Create File Structure

```
FitLink/
├── Resources/
│   └── Animations/
│       ├── celebration/
│       │   ├── confetti-celebration.json
│       │   ├── success-checkmark.json
│       │   └── trophy-spin.json
│       ├── loading/
│       │   ├── fitness-loader.json
│       │   └── brain-thinking.json
│       ├── empty-states/
│       │   ├── person-stretching.json
│       │   ├── empty-plate.json
│       │   └── meditation-calm.json
│       └── feedback/
│           ├── heart-pulse.json
│           ├── fire-growing.json
│           ├── steps-walking.json
│           └── sleep-zzz.json
├── Utils/
│   └── Lottie/
│       ├── LottieView.swift
│       ├── LottieManager.swift
│       ├── LottieAnimationType.swift
│       ├── ConfettiOverlay.swift
│       ├── SuccessCheckmark.swift
│       ├── LoadingAnimation.swift
│       ├── EmptyStateAnimation.swift
│       └── View+LottieModifiers.swift
```

#### 1.3 Core Components

**LottieView.swift** - UIViewRepresentable wrapper:

```swift
import SwiftUI
import Lottie

/// A SwiftUI wrapper for Lottie animations with full control over playback.
/// Respects system Reduce Motion settings automatically.
struct LottieView: UIViewRepresentable {
    
    // MARK: - Configuration
    
    let animationName: String
    let bundle: Bundle
    let loopMode: LottieLoopMode
    let contentMode: UIView.ContentMode
    let animationSpeed: CGFloat
    
    @Binding var isPlaying: Bool
    
    var onAnimationComplete: (() -> Void)?
    
    // MARK: - Initialization
    
    init(
        animationName: String,
        bundle: Bundle = .main,
        loopMode: LottieLoopMode = .playOnce,
        contentMode: UIView.ContentMode = .scaleAspectFit,
        animationSpeed: CGFloat = 1.0,
        isPlaying: Binding<Bool> = .constant(true),
        onComplete: (() -> Void)? = nil
    ) {
        self.animationName = animationName
        self.bundle = bundle
        self.loopMode = loopMode
        self.contentMode = contentMode
        self.animationSpeed = animationSpeed
        self._isPlaying = isPlaying
        self.onAnimationComplete = onComplete
    }
    
    // MARK: - UIViewRepresentable
    
    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView()
        animationView.contentMode = contentMode
        animationView.loopMode = loopMode
        animationView.animationSpeed = animationSpeed
        animationView.backgroundBehavior = .pauseAndRestore
        
        // Load from cache or file
        if let cachedAnimation = LottieManager.shared.getCachedAnimation(named: animationName) {
            animationView.animation = cachedAnimation
        } else {
            animationView.animation = LottieAnimation.named(animationName, bundle: bundle)
            if let animation = animationView.animation {
                LottieManager.shared.cacheAnimation(animation, named: animationName)
            }
        }
        
        // Reduce Motion: show static frame instead of animating
        if UIAccessibility.isReduceMotionEnabled {
            animationView.currentProgress = 1.0
        } else if isPlaying {
            animationView.play { finished in
                if finished {
                    DispatchQueue.main.async {
                        self.onAnimationComplete?()
                    }
                }
            }
        }
        
        return animationView
    }
    
    func updateUIView(_ animationView: LottieAnimationView, context: Context) {
        // Skip updates if Reduce Motion is enabled
        guard !UIAccessibility.isReduceMotionEnabled else {
            animationView.stop()
            animationView.currentProgress = 1.0
            return
        }
        
        if isPlaying && !animationView.isAnimationPlaying {
            animationView.play { finished in
                if finished {
                    DispatchQueue.main.async {
                        self.onAnimationComplete?()
                    }
                }
            }
        } else if !isPlaying && animationView.isAnimationPlaying {
            animationView.pause()
        }
    }
    
    static func dismantleUIView(_ animationView: LottieAnimationView, coordinator: ()) {
        animationView.stop()
    }
}

// MARK: - Convenience Initializers

extension LottieView {
    /// Creates a LottieView from a LottieAnimationType enum
    init(
        type: LottieAnimationType,
        loopMode: LottieLoopMode? = nil,
        isPlaying: Binding<Bool> = .constant(true),
        onComplete: (() -> Void)? = nil
    ) {
        self.init(
            animationName: type.fileName,
            bundle: .main,
            loopMode: loopMode ?? type.defaultLoopMode,
            contentMode: .scaleAspectFit,
            animationSpeed: type.defaultSpeed,
            isPlaying: isPlaying,
            onComplete: onComplete
        )
    }
}
```

**LottieManager.swift** - Singleton for preloading and caching:

```swift
import Foundation
import Lottie

/// Centralized manager for Lottie animation caching, preloading, and memory management.
/// Thread-safe singleton that handles animation lifecycle.
final class LottieManager {
    
    // MARK: - Singleton
    
    static let shared = LottieManager()
    
    // MARK: - Private Properties
    
    private let animationCache = NSCache<NSString, LottieAnimationWrapper>()
    private let preloadQueue = DispatchQueue(label: "com.fitlink.lottie.preload", qos: .utility)
    private let cacheAccessQueue = DispatchQueue(label: "com.fitlink.lottie.cache", attributes: .concurrent)
    
    private var isPreloaded = false
    
    // MARK: - Initialization
    
    private init() {
        // Configure cache limits
        animationCache.countLimit = 15  // Max 15 animations in memory
        animationCache.totalCostLimit = 50 * 1024 * 1024  // 50MB limit
        
        // Listen for memory warnings
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        #endif
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public API
    
    /// Preloads P0 animations for instant display. Call during app launch.
    func preloadPriorityAnimations() {
        guard !isPreloaded else { return }
        
        let priorityAnimations: [LottieAnimationType] = [
            .successCheckmark,
            .fitnessLoader,
            .brainThinking
        ]
        
        preloadQueue.async { [weak self] in
            for type in priorityAnimations {
                self?.loadAndCache(type)
            }
            self?.isPreloaded = true
            #if DEBUG
            print("[LottieManager] Preloaded \(priorityAnimations.count) priority animations")
            #endif
        }
    }
    
    /// Preloads all animations in the background. Call after initial UI is displayed.
    func preloadAllAnimations() {
        preloadQueue.async { [weak self] in
            for type in LottieAnimationType.allCases {
                self?.loadAndCache(type)
            }
            #if DEBUG
            print("[LottieManager] Preloaded all \(LottieAnimationType.allCases.count) animations")
            #endif
        }
    }
    
    /// Retrieves a cached animation, if available.
    func getCachedAnimation(named name: String) -> LottieAnimation? {
        var result: LottieAnimation?
        cacheAccessQueue.sync {
            result = animationCache.object(forKey: name as NSString)?.animation
        }
        return result
    }
    
    /// Caches an animation for reuse.
    func cacheAnimation(_ animation: LottieAnimation, named name: String) {
        let wrapper = LottieAnimationWrapper(animation: animation)
        let cost = estimateCost(for: animation)
        cacheAccessQueue.async(flags: .barrier) { [weak self] in
            self?.animationCache.setObject(wrapper, forKey: name as NSString, cost: cost)
        }
    }
    
    /// Clears all cached animations. Use during memory pressure.
    func clearCache() {
        cacheAccessQueue.async(flags: .barrier) { [weak self] in
            self?.animationCache.removeAllObjects()
            self?.isPreloaded = false
        }
        #if DEBUG
        print("[LottieManager] Cache cleared")
        #endif
    }
    
    /// Returns whether Reduce Motion is enabled (for fallback decisions).
    var isReduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
    
    // MARK: - Private Helpers
    
    private func loadAndCache(_ type: LottieAnimationType) {
        guard getCachedAnimation(named: type.fileName) == nil else { return }
        
        if let animation = LottieAnimation.named(type.fileName, bundle: .main) {
            cacheAnimation(animation, named: type.fileName)
        }
    }
    
    private func estimateCost(for animation: LottieAnimation) -> Int {
        // Rough estimate: 100KB per second of animation at 60fps
        let durationSeconds = animation.duration
        return Int(durationSeconds * 100 * 1024)
    }
    
    @objc private func handleMemoryWarning() {
        // Keep only P0 animations, clear the rest
        let priorityNames = Set([
            LottieAnimationType.successCheckmark.fileName,
            LottieAnimationType.fitnessLoader.fileName,
            LottieAnimationType.brainThinking.fileName
        ])
        
        cacheAccessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // NSCache doesn't support iteration, so we clear and reload priorities
            self.animationCache.removeAllObjects()
            
            for name in priorityNames {
                if let animation = LottieAnimation.named(name, bundle: .main) {
                    let wrapper = LottieAnimationWrapper(animation: animation)
                    self.animationCache.setObject(wrapper, forKey: name as NSString)
                }
            }
        }
        
        #if DEBUG
        print("[LottieManager] Memory warning handled - cache reduced to priority animations")
        #endif
    }
}

// MARK: - Cache Wrapper

/// Wrapper class to store LottieAnimation in NSCache (requires reference type).
private final class LottieAnimationWrapper {
    let animation: LottieAnimation
    
    init(animation: LottieAnimation) {
        self.animation = animation
    }
}
```

**LottieAnimationType.swift** - Type-safe animation enum:

```swift
import Lottie
import SwiftUI

/// Type-safe enumeration of all Lottie animations in FitLink.
/// Provides file names, default configurations, and asset paths.
enum LottieAnimationType: String, CaseIterable {
    
    // MARK: - Celebration
    case confettiCelebration = "confetti-celebration"
    case successCheckmark = "success-checkmark"
    case trophySpin = "trophy-spin"
    
    // MARK: - Loading
    case fitnessLoader = "fitness-loader"
    case brainThinking = "brain-thinking"
    
    // MARK: - Empty States
    case personStretching = "person-stretching"
    case emptyPlate = "empty-plate"
    case meditationCalm = "meditation-calm"
    
    // MARK: - Micro-feedback
    case heartPulse = "heart-pulse"
    case fireGrowing = "fire-growing"
    case stepsWalking = "steps-walking"
    case sleepZzz = "sleep-zzz"
    
    // MARK: - Properties
    
    var fileName: String {
        rawValue
    }
    
    var category: AnimationCategory {
        switch self {
        case .confettiCelebration, .successCheckmark, .trophySpin:
            return .celebration
        case .fitnessLoader, .brainThinking:
            return .loading
        case .personStretching, .emptyPlate, .meditationCalm:
            return .emptyState
        case .heartPulse, .fireGrowing, .stepsWalking, .sleepZzz:
            return .feedback
        }
    }
    
    var defaultLoopMode: LottieLoopMode {
        switch self {
        case .confettiCelebration, .successCheckmark, .trophySpin:
            return .playOnce
        case .fitnessLoader, .brainThinking:
            return .loop
        case .personStretching, .emptyPlate, .meditationCalm:
            return .loop
        case .heartPulse, .fireGrowing, .stepsWalking, .sleepZzz:
            return .playOnce
        }
    }
    
    var defaultSpeed: CGFloat {
        switch self {
        case .confettiCelebration:
            return 1.0
        case .successCheckmark:
            return 1.2  // Slightly faster for snappy feedback
        case .trophySpin:
            return 0.8  // Slower for dramatic effect
        case .fitnessLoader, .brainThinking:
            return 1.0
        case .personStretching, .emptyPlate, .meditationCalm:
            return 0.7  // Gentle, relaxed pace
        case .heartPulse:
            return 1.0
        case .fireGrowing:
            return 1.5  // Quick burst of energy
        case .stepsWalking, .sleepZzz:
            return 1.0
        }
    }
    
    var recommendedSize: CGSize {
        switch self {
        case .confettiCelebration:
            return CGSize(width: 300, height: 300)  // Full overlay
        case .successCheckmark:
            return CGSize(width: 28, height: 28)   // Inline with text
        case .trophySpin:
            return CGSize(width: 120, height: 120)
        case .fitnessLoader, .brainThinking:
            return CGSize(width: 80, height: 80)
        case .personStretching, .emptyPlate, .meditationCalm:
            return CGSize(width: 200, height: 200)
        case .heartPulse, .fireGrowing, .stepsWalking, .sleepZzz:
            return CGSize(width: 24, height: 24)   // Small inline
        }
    }
    
    /// Static fallback SF Symbol for Reduce Motion mode
    var fallbackSymbol: String {
        switch self {
        case .confettiCelebration: return "party.popper.fill"
        case .successCheckmark: return "checkmark.circle.fill"
        case .trophySpin: return "trophy.fill"
        case .fitnessLoader: return "figure.run"
        case .brainThinking: return "brain.head.profile"
        case .personStretching: return "figure.flexibility"
        case .emptyPlate: return "fork.knife"
        case .meditationCalm: return "leaf.fill"
        case .heartPulse: return "heart.fill"
        case .fireGrowing: return "flame.fill"
        case .stepsWalking: return "figure.walk"
        case .sleepZzz: return "moon.zzz.fill"
        }
    }
    
    var fallbackColor: Color {
        switch self {
        case .confettiCelebration, .trophySpin: return .yellow
        case .successCheckmark: return .green
        case .fitnessLoader, .stepsWalking: return .blue
        case .brainThinking: return .purple
        case .personStretching: return .orange
        case .emptyPlate: return .green
        case .meditationCalm: return .teal
        case .heartPulse: return .red
        case .fireGrowing: return .orange
        case .sleepZzz: return .indigo
        }
    }
}

// MARK: - Animation Category

enum AnimationCategory: String {
    case celebration
    case loading
    case emptyState
    case feedback
}
```

---

### Phase 2: Celebration Animations (Week 1-2, Days 4-7)

**Objective**: Implement confetti overlay, success checkmark, and trophy animations.

**ConfettiOverlay.swift**:

```swift
import SwiftUI

/// Full-screen confetti celebration overlay.
/// Auto-dismisses after animation completes. Use via `.confettiOverlay()` modifier.
struct ConfettiOverlay: View {
    @Binding var isPresented: Bool
    var onComplete: (() -> Void)?
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            if isPresented {
                // Semi-transparent backdrop (optional)
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                // Confetti animation
                if !LottieManager.shared.isReduceMotionEnabled {
                    LottieView(
                        type: .confettiCelebration,
                        isPlaying: $isAnimating
                    ) {
                        // Animation complete
                        withAnimation(.easeOut(duration: 0.3)) {
                            isPresented = false
                        }
                        onComplete?()
                    }
                    .frame(width: 300, height: 300)
                    .allowsHitTesting(false)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // Reduce Motion fallback: static celebration icon
                    reduceMotionFallback
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented)
        .onChange(of: isPresented) { _, newValue in
            if newValue {
                isAnimating = true
                
                // Haptic feedback
                HapticFeedbackManager.shared.notification(type: .success)
                
                // Auto-dismiss for Reduce Motion after delay
                if LottieManager.shared.isReduceMotionEnabled {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            isPresented = false
                        }
                        onComplete?()
                    }
                }
            } else {
                isAnimating = false
            }
        }
    }
    
    private var reduceMotionFallback: some View {
        VStack(spacing: GlassTokens.Padding.standard) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
            
            Text("🎉 Celebration! 🎉")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding(GlassTokens.Padding.large)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: GlassTokens.Radius.overlay))
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - View Modifier

struct ConfettiOverlayModifier: ViewModifier {
    @Binding var isPresented: Bool
    var onComplete: (() -> Void)?
    
    func body(content: Content) -> some View {
        content.overlay {
            ConfettiOverlay(isPresented: $isPresented, onComplete: onComplete)
        }
    }
}

extension View {
    /// Displays a full-screen confetti celebration animation.
    func confettiOverlay(
        isPresented: Binding<Bool>,
        onComplete: (() -> Void)? = nil
    ) -> some View {
        modifier(ConfettiOverlayModifier(isPresented: isPresented, onComplete: onComplete))
    }
}
```

**SuccessCheckmark.swift**:

```swift
import SwiftUI

/// Animated checkmark for habit completion feedback.
/// Replaces static checkmark icon with smooth animation.
struct SuccessCheckmark: View {
    @Binding var isCompleted: Bool
    var size: CGFloat = 28
    var color: Color = .green
    
    @State private var isAnimating = false
    @State private var showAnimation = false
    
    var body: some View {
        ZStack {
            if showAnimation && !LottieManager.shared.isReduceMotionEnabled {
                LottieView(
                    type: .successCheckmark,
                    isPlaying: $isAnimating
                ) {
                    // Keep showing the final frame
                }
                .frame(width: size, height: size)
            } else {
                // Static icon (initial state or Reduce Motion)
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: size))
                    .foregroundStyle(isCompleted ? color : .secondary.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .onChange(of: isCompleted) { oldValue, newValue in
            // Only animate when transitioning from incomplete to complete
            if !oldValue && newValue && !LottieManager.shared.isReduceMotionEnabled {
                showAnimation = true
                isAnimating = true
                
                // Haptic feedback
                HapticFeedbackManager.shared.impact(style: .light)
            } else if !newValue {
                showAnimation = false
                isAnimating = false
            }
        }
    }
}

// MARK: - View Modifier

extension View {
    /// Appends an animated success checkmark.
    func successCheckmark(
        isCompleted: Binding<Bool>,
        size: CGFloat = 28,
        color: Color = .green
    ) -> some View {
        HStack {
            self
            SuccessCheckmark(isCompleted: isCompleted, size: size, color: color)
        }
    }
}
```

---

### Phase 3: Loading & Empty State Animations (Week 2-3, Days 8-12)

**Objective**: Replace ProgressView spinners with themed loaders; add engaging empty states.

**LoadingAnimation.swift**:

```swift
import SwiftUI

/// Loading animation types for different contexts.
enum LoadingAnimationType: String, CaseIterable {
    case fitness   // General fitness-themed loader
    case aiThinking  // Brain animation for AI generation
    
    var lottieType: LottieAnimationType {
        switch self {
        case .fitness: return .fitnessLoader
        case .aiThinking: return .brainThinking
        }
    }
    
    var defaultMessage: String {
        switch self {
        case .fitness: return "Loading..."
        case .aiThinking: return "AI is thinking..."
        }
    }
}

/// Animated loading indicator with optional message.
struct LoadingAnimation: View {
    let type: LoadingAnimationType
    var message: String?
    var size: CGFloat = 80
    var showBackground: Bool = true
    
    @State private var isAnimating = true
    
    var body: some View {
        VStack(spacing: GlassTokens.Padding.standard) {
            if !LottieManager.shared.isReduceMotionEnabled {
                LottieView(
                    type: type.lottieType,
                    loopMode: .loop,
                    isPlaying: $isAnimating
                )
                .frame(width: size, height: size)
            } else {
                // Reduce Motion fallback: standard ProgressView with icon
                VStack(spacing: GlassTokens.Padding.small) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Image(systemName: type.lottieType.fallbackSymbol)
                        .font(.title2)
                        .foregroundStyle(type.lottieType.fallbackColor)
                }
            }
            
            if let message = message ?? type.defaultMessage {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(showBackground ? GlassTokens.Padding.large : 0)
        .background {
            if showBackground {
                RoundedRectangle(cornerRadius: GlassTokens.Radius.card)
                    .fill(.ultraThinMaterial)
            }
        }
    }
}

// MARK: - View Modifier for Loading Overlay

extension View {
    /// Displays a loading overlay with themed animation.
    func loadingOverlay(
        isLoading: Binding<Bool>,
        type: LoadingAnimationType = .fitness,
        message: String? = nil,
        blocksInteraction: Bool = true
    ) -> some View {
        ZStack {
            self
                .disabled(isLoading.wrappedValue && blocksInteraction)
                .blur(radius: isLoading.wrappedValue ? 2 : 0)
            
            if isLoading.wrappedValue {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                LoadingAnimation(type: type, message: message)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isLoading.wrappedValue)
    }
    
    /// Displays an AI thinking overlay.
    func aiThinkingOverlay(
        isLoading: Binding<Bool>,
        message: String? = nil
    ) -> some View {
        loadingOverlay(
            isLoading: isLoading,
            type: .aiThinking,
            message: message ?? "AI is generating your plan..."
        )
    }
}
```

**EmptyStateAnimation.swift**:

```swift
import SwiftUI

/// Empty state types with context-specific animations and messaging.
enum EmptyStateType {
    case noWorkouts
    case noDietPlan
    case noHabits
    case noFriends
    case noMemories
    
    var lottieType: LottieAnimationType {
        switch self {
        case .noWorkouts: return .personStretching
        case .noDietPlan: return .emptyPlate
        case .noHabits, .noMemories: return .meditationCalm
        case .noFriends: return .personStretching
        }
    }
    
    var title: String {
        switch self {
        case .noWorkouts: return "No workouts yet"
        case .noDietPlan: return "No diet plan"
        case .noHabits: return "No habits yet"
        case .noFriends: return "No friends yet"
        case .noMemories: return "No memories saved"
        }
    }
    
    var subtitle: String {
        switch self {
        case .noWorkouts: return "Create your first workout to get started"
        case .noDietPlan: return "Let AI create a personalized meal plan for you"
        case .noHabits: return "Tap the + button to add your first habit"
        case .noFriends: return "Connect with friends to share your progress"
        case .noMemories: return "Your AI-learned preferences will appear here"
        }
    }
    
    var actionTitle: String? {
        switch self {
        case .noWorkouts: return "Create Workout"
        case .noDietPlan: return "Create Diet Plan"
        case .noHabits: return "Add Habit"
        case .noFriends: return "Find Friends"
        case .noMemories: return nil
        }
    }
}

/// Animated empty state view with Lottie animation and optional CTA.
struct EmptyStateAnimation: View {
    let type: EmptyStateType
    var customTitle: String?
    var customSubtitle: String?
    var action: (() -> Void)?
    
    @State private var isAnimating = true
    
    var body: some View {
        VStack(spacing: GlassTokens.Padding.section) {
            Spacer()
            
            // Animation or fallback
            if !LottieManager.shared.isReduceMotionEnabled {
                LottieView(
                    type: type.lottieType,
                    loopMode: .loop,
                    isPlaying: $isAnimating
                )
                .frame(width: 200, height: 200)
            } else {
                Image(systemName: type.lottieType.fallbackSymbol)
                    .font(.system(size: 60))
                    .foregroundStyle(type.lottieType.fallbackColor.opacity(0.6))
            }
            
            // Text content
            VStack(spacing: GlassTokens.Padding.small) {
                Text(customTitle ?? type.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(customSubtitle ?? type.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, GlassTokens.Padding.large)
            }
            
            // Action button
            if let actionTitle = type.actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.semibold)
                        .padding(.horizontal, GlassTokens.Padding.section)
                        .padding(.vertical, GlassTokens.Padding.compact)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, GlassTokens.Padding.small)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

---

### Phase 4: Integration & Polish (Week 3-4, Days 13-16)

**Objective**: Integrate animations into existing views, add micro-feedback, final polish.

**View+LottieModifiers.swift** - Complete modifier collection:

```swift
import SwiftUI

// MARK: - Streak Milestone Detection

extension View {
    /// Automatically triggers confetti for streak milestones.
    func celebrateStreakMilestone(
        streak: Int,
        milestones: [Int] = [7, 30, 100, 365]
    ) -> some View {
        modifier(StreakMilestoneModifier(streak: streak, milestones: milestones))
    }
}

private struct StreakMilestoneModifier: ViewModifier {
    let streak: Int
    let milestones: [Int]
    
    @State private var showConfetti = false
    @State private var lastCelebratedStreak = 0
    
    func body(content: Content) -> some View {
        content
            .confettiOverlay(isPresented: $showConfetti)
            .onChange(of: streak) { oldValue, newValue in
                if milestones.contains(newValue) && newValue > lastCelebratedStreak {
                    showConfetti = true
                    lastCelebratedStreak = newValue
                }
            }
    }
}

// MARK: - All Habits Complete

extension View {
    /// Triggers trophy animation when all habits are completed.
    func celebrateAllHabitsComplete(
        totalHabits: Int,
        completedHabits: Int
    ) -> some View {
        modifier(AllHabitsCompleteModifier(
            totalHabits: totalHabits,
            completedHabits: completedHabits
        ))
    }
}

private struct AllHabitsCompleteModifier: ViewModifier {
    let totalHabits: Int
    let completedHabits: Int
    
    @State private var showTrophy = false
    @State private var hasShownToday = false
    
    func body(content: Content) -> some View {
        content
            .trophyOverlay(isPresented: $showTrophy)
            .onChange(of: completedHabits) { oldValue, newValue in
                if totalHabits > 0 && newValue == totalHabits && oldValue < totalHabits && !hasShownToday {
                    showTrophy = true
                    hasShownToday = true
                }
            }
    }
}

// MARK: - Fire Growing Animation for Streak Display

/// Inline fire animation for streak counters
struct StreakFireAnimation: View {
    let streak: Int
    var size: CGFloat = 24
    
    @State private var isAnimating = true
    @State private var previousStreak = 0
    
    var body: some View {
        HStack(spacing: 4) {
            if streak > 0 {
                if shouldShowAnimation && !LottieManager.shared.isReduceMotionEnabled {
                    LottieView(
                        type: .fireGrowing,
                        isPlaying: $isAnimating
                    )
                    .frame(width: size, height: size)
                } else {
                    Image(systemName: "flame.fill")
                        .font(.system(size: size * 0.7))
                        .foregroundStyle(.orange)
                }
                
                Text("\(streak)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
            }
        }
        .onChange(of: streak) { oldValue, newValue in
            if newValue > oldValue {
                previousStreak = oldValue
                isAnimating = true
            }
        }
    }
    
    private var shouldShowAnimation: Bool {
        streak > previousStreak && previousStreak > 0
    }
}
```

---

## Performance Considerations

### Memory Management

```swift
// In FitLinkApp.swift, add to app initialization:

@main
struct FitLinkApp: App {
    init() {
        // Preload priority animations on launch
        LottieManager.shared.preloadPriorityAnimations()
    }
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
                .onAppear {
                    // Preload remaining animations after UI is displayed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        LottieManager.shared.preloadAllAnimations()
                    }
                }
        }
    }
}
```

### Battery Optimization

1. **Pause on background**: `backgroundBehavior = .pauseAndRestore` (default in LottieView)
2. **Limit loop updates**: Loading animations update cache every 15 seconds, not every frame
3. **Lazy loading**: Empty state animations only load when view appears
4. **Reduce Motion**: Skip all animation computation when enabled

---

## Accessibility

### Reduce Motion Support

All animation components check `UIAccessibility.isReduceMotionEnabled` and provide fallbacks:

1. **LottieView**: Shows final frame statically
2. **ConfettiOverlay**: Shows static celebration icon with auto-dismiss
3. **SuccessCheckmark**: Uses native `.symbolEffect(.replace)` transition
4. **LoadingAnimation**: Falls back to standard ProgressView
5. **EmptyStateAnimation**: Shows SF Symbol instead of animation

### Testing Reduce Motion

1. Settings > Accessibility > Motion > Reduce Motion: ON
2. Verify all animations show static fallbacks
3. Verify timing-based auto-dismissals still work
4. Verify haptic feedback still triggers

---

## Testing Strategy

### Unit Tests

```swift
import XCTest
@testable import FitLink

final class LottieManagerTests: XCTestCase {
    
    func testPreloadCachesAnimations() async {
        let manager = LottieManager.shared
        manager.clearCache()
        
        manager.preloadPriorityAnimations()
        
        // Wait for async preload
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        XCTAssertNotNil(manager.getCachedAnimation(named: "success-checkmark"))
        XCTAssertNotNil(manager.getCachedAnimation(named: "fitness-loader"))
    }
}
```

### Manual Test Checklist

- [ ] All P0 animations load within 100ms on iPhone 12
- [ ] No frame drops during confetti overlay on iPhone SE
- [ ] Memory stays under 50MB delta with all animations loaded
- [ ] Animations pause when app backgrounds
- [ ] Animations resume correctly on foreground
- [ ] Reduce Motion shows all fallbacks
- [ ] VoiceOver announces appropriate labels
- [ ] Dark mode colors render correctly
- [ ] Haptic feedback triggers on celebrations

---

## Estimated Timeline

| Week | Phase | Deliverables | Effort |
|------|-------|-------------|--------|
| **Week 1** | Phase 1 + Phase 2 Start | SPM setup, LottieView, LottieManager, ConfettiOverlay | Medium (4d) |
| **Week 2** | Phase 2 + Phase 3 Start | SuccessCheckmark, TrophyAnimation, LoadingAnimation | Medium (4d) |
| **Week 3** | Phase 3 + Phase 4 Start | EmptyStateAnimation, View modifiers, Integration | Medium (4d) |
| **Week 4** | Phase 4 + Polish | Full integration, testing, performance tuning | Medium (4d) |

**Total: 16 dev-days across 4 weeks**

---

## File Summary

```
FitLink/
├── Resources/
│   └── Animations/
│       ├── celebration/
│       │   ├── confetti-celebration.json
│       │   ├── success-checkmark.json
│       │   └── trophy-spin.json
│       ├── loading/
│       │   ├── fitness-loader.json
│       │   └── brain-thinking.json
│       ├── empty-states/
│       │   ├── person-stretching.json
│       │   ├── empty-plate.json
│       │   └── meditation-calm.json
│       └── feedback/
│           ├── heart-pulse.json
│           ├── fire-growing.json
│           ├── steps-walking.json
│           └── sleep-zzz.json
└── Utils/
    └── Lottie/
        ├── LottieView.swift              # Core UIViewRepresentable
        ├── LottieManager.swift            # Caching & preloading singleton
        ├── LottieAnimationType.swift      # Type-safe enum
        ├── ConfettiOverlay.swift          # Full-screen celebration
        ├── SuccessCheckmark.swift         # Inline completion animation
        ├── TrophyAnimation.swift          # Trophy celebration
        ├── LoadingAnimation.swift         # Themed loaders
        ├── EmptyStateAnimation.swift      # Animated empty states
        └── View+LottieModifiers.swift     # SwiftUI modifiers
```

---

## Next Steps

1. **Add lottie-ios 4.4.0+ via Xcode SPM** (File > Add Package Dependencies)
2. **Create `Resources/Animations/` folder structure**
3. **Source P0 animations from LottieFiles** (confetti, checkmark, fitness loader, brain)
4. **Implement Phase 1 components** (LottieView, LottieManager)
5. **Integrate into HabitTrackerView** as proof of concept

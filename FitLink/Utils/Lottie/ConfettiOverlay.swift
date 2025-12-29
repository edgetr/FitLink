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
                HapticFeedbackManager.shared.notification(.success)
                
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
            
            Text("Celebration!")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding(GlassTokens.Padding.large)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: GlassTokens.Radius.overlay))
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Trophy Overlay

/// Trophy celebration overlay for completing all daily habits.
struct TrophyOverlay: View {
    @Binding var isPresented: Bool
    var onComplete: (() -> Void)?
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            if isPresented {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                if !LottieManager.shared.isReduceMotionEnabled {
                    LottieView(
                        type: .trophySpin,
                        isPlaying: $isAnimating
                    ) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isPresented = false
                        }
                        onComplete?()
                    }
                    .frame(width: 120, height: 120)
                    .allowsHitTesting(false)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    reduceMotionFallback
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented)
        .onChange(of: isPresented) { _, newValue in
            if newValue {
                isAnimating = true
                HapticFeedbackManager.shared.notification(.success)
                
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
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
            
            Text("All Complete!")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding(GlassTokens.Padding.large)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: GlassTokens.Radius.overlay))
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - View Modifiers

struct ConfettiOverlayModifier: ViewModifier {
    @Binding var isPresented: Bool
    var onComplete: (() -> Void)?
    
    func body(content: Content) -> some View {
        content.overlay {
            ConfettiOverlay(isPresented: $isPresented, onComplete: onComplete)
        }
    }
}

struct TrophyOverlayModifier: ViewModifier {
    @Binding var isPresented: Bool
    var onComplete: (() -> Void)?
    
    func body(content: Content) -> some View {
        content.overlay {
            TrophyOverlay(isPresented: $isPresented, onComplete: onComplete)
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
    
    /// Displays a trophy celebration animation.
    func trophyOverlay(
        isPresented: Binding<Bool>,
        onComplete: (() -> Void)? = nil
    ) -> some View {
        modifier(TrophyOverlayModifier(isPresented: isPresented, onComplete: onComplete))
    }
}

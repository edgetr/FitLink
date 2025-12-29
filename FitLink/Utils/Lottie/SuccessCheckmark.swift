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
                HapticFeedbackManager.shared.impact(.light)
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

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var isCompleted = false
        
        var body: some View {
            VStack(spacing: 40) {
                SuccessCheckmark(isCompleted: $isCompleted, size: 48)
                
                Button(isCompleted ? "Reset" : "Complete") {
                    isCompleted.toggle()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    return PreviewWrapper()
}

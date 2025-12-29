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
            
            let displayMessage = message ?? type.defaultMessage
            Text(displayMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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

// MARK: - Preview

#Preview("Loading Types") {
    VStack(spacing: 40) {
        LoadingAnimation(type: .fitness)
        LoadingAnimation(type: .aiThinking, message: "Generating workout plan...")
    }
}

#Preview("Loading Overlay") {
    struct PreviewWrapper: View {
        @State private var isLoading = true
        
        var body: some View {
            VStack {
                Text("Content behind overlay")
                    .font(.title)
                
                Button("Toggle Loading") {
                    isLoading.toggle()
                }
            }
            .loadingOverlay(isLoading: $isLoading, type: .aiThinking)
        }
    }
    
    return PreviewWrapper()
}

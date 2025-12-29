import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(Lottie)
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

#else

// MARK: - Fallback View (when Lottie not available)

/// Fallback view that shows SF Symbol when Lottie is not installed
struct LottieView: View {
    let animationName: String
    var bundle: Bundle = .main
    @Binding var isPlaying: Bool
    var onComplete: (() -> Void)? = nil
    
    init(
        animationName: String,
        bundle: Bundle = .main,
        loopMode: Any? = nil,
        contentMode: Any? = nil,
        animationSpeed: CGFloat = 1.0,
        isPlaying: Binding<Bool> = .constant(true),
        onComplete: (() -> Void)? = nil
    ) {
        self.animationName = animationName
        self.bundle = bundle
        self._isPlaying = isPlaying
        self.onComplete = onComplete
    }
    
    init(
        type: LottieAnimationType,
        loopMode: Any? = nil,
        isPlaying: Binding<Bool> = .constant(true),
        onComplete: (() -> Void)? = nil
    ) {
        self.animationName = type.fileName
        self._isPlaying = isPlaying
        self.onComplete = onComplete
    }
    
    var body: some View {
        // Show fallback SF Symbol
        if let type = LottieAnimationType(rawValue: animationName) {
            Image(systemName: type.fallbackSymbol)
                .font(.title)
                .foregroundStyle(type.fallbackColor)
        } else {
            Image(systemName: "questionmark.circle")
                .font(.title)
                .foregroundStyle(.secondary)
        }
    }
}

#endif

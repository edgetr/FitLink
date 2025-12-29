import SwiftUI

#if canImport(Lottie)
import Lottie
#endif

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
    
    #if canImport(Lottie)
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
    #endif
    
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

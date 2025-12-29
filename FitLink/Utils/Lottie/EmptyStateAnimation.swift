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

// MARK: - Preview

#Preview("Empty States") {
    TabView {
        EmptyStateAnimation(type: .noWorkouts) {
            print("Create workout tapped")
        }
        .tabItem { Text("Workouts") }
        
        EmptyStateAnimation(type: .noDietPlan) {
            print("Create diet plan tapped")
        }
        .tabItem { Text("Diet") }
        
        EmptyStateAnimation(type: .noHabits) {
            print("Add habit tapped")
        }
        .tabItem { Text("Habits") }
        
        EmptyStateAnimation(type: .noMemories)
            .tabItem { Text("Memories") }
    }
}

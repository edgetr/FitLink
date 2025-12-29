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

// MARK: - Heart Pulse Animation

/// Inline heart pulse for health metrics
struct HeartPulseAnimation: View {
    @Binding var isAnimating: Bool
    var size: CGFloat = 24
    
    var body: some View {
        if isAnimating && !LottieManager.shared.isReduceMotionEnabled {
            LottieView(
                type: .heartPulse,
                isPlaying: $isAnimating
            ) {
                isAnimating = false
            }
            .frame(width: size, height: size)
        } else {
            Image(systemName: "heart.fill")
                .font(.system(size: size * 0.7))
                .foregroundStyle(.red)
        }
    }
}

// MARK: - Steps Walking Animation

/// Inline walking animation for steps display
struct StepsWalkingAnimation: View {
    @Binding var isAnimating: Bool
    var size: CGFloat = 24
    
    var body: some View {
        if isAnimating && !LottieManager.shared.isReduceMotionEnabled {
            LottieView(
                type: .stepsWalking,
                isPlaying: $isAnimating
            ) {
                isAnimating = false
            }
            .frame(width: size, height: size)
        } else {
            Image(systemName: "figure.walk")
                .font(.system(size: size * 0.7))
                .foregroundStyle(.blue)
        }
    }
}

// MARK: - Sleep Animation

/// Inline sleep animation for sleep metrics
struct SleepAnimation: View {
    @Binding var isAnimating: Bool
    var size: CGFloat = 24
    
    var body: some View {
        if isAnimating && !LottieManager.shared.isReduceMotionEnabled {
            LottieView(
                type: .sleepZzz,
                isPlaying: $isAnimating
            ) {
                isAnimating = false
            }
            .frame(width: size, height: size)
        } else {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: size * 0.7))
                .foregroundStyle(.indigo)
        }
    }
}

// MARK: - Preview

#Preview("Streak Fire") {
    struct PreviewWrapper: View {
        @State private var streak = 5
        
        var body: some View {
            VStack(spacing: 20) {
                StreakFireAnimation(streak: streak)
                
                Button("Increase Streak") {
                    streak += 1
                }
            }
        }
    }
    
    return PreviewWrapper()
}

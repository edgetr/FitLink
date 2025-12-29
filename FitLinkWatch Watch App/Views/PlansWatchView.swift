import SwiftUI

#if os(watchOS)

struct PlansWatchView: View {
    
    @EnvironmentObject var sessionManager: WatchSessionManager
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    NavigationLink(destination: DietPlanWatchView()) {
                        planButton(
                            icon: "fork.knife",
                            title: "Diet Plan",
                            subtitle: dietSubtitle,
                            gradientColors: [.orange, .pink],
                            hasContent: !sessionManager.dietPlans.isEmpty
                        )
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink(destination: WorkoutPlanWatchView()) {
                        planButton(
                            icon: "dumbbell.fill",
                            title: "Workout Plan",
                            subtitle: workoutSubtitle,
                            gradientColors: [.cyan, .blue],
                            hasContent: !sessionManager.workoutPlans.isEmpty
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 16)
            }
            .navigationTitle("Plans")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var dietSubtitle: String {
        if let plan = sessionManager.dietPlans.first(where: { $0.isCurrentWeek }) {
            return "\(plan.avgCaloriesPerDay) cal/day"
        } else if !sessionManager.dietPlans.isEmpty {
            return "View your plans"
        }
        return "No active plan"
    }
    
    private var workoutSubtitle: String {
        if let plan = sessionManager.workoutPlans.first(where: { $0.isCurrentWeek }) {
            if let today = plan.todayWorkout {
                return today.isRestDay ? "Rest Day" : today.focus
            }
            return "\(plan.workoutDaysCount) workout days"
        } else if !sessionManager.workoutPlans.isEmpty {
            return "View your plans"
        }
        return "No active plan"
    }
    
    private func planButton(
        icon: String,
        title: String,
        subtitle: String,
        gradientColors: [Color],
        hasContent: Bool
    ) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
            }
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            if !hasContent {
                Text("Create on iPhone")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.15))
        )
    }
}

#endif

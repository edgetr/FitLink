import SwiftUI

#if os(watchOS)

struct DietPlanWatchView: View {
    
    @EnvironmentObject var sessionManager: WatchSessionManager
    
    private var currentPlan: DietPlanSyncData? {
        sessionManager.dietPlans.first(where: { $0.isCurrentWeek })
    }
    
    var body: some View {
        Group {
            if let plan = currentPlan {
                planContentView(plan)
            } else if !sessionManager.dietPlans.isEmpty {
                otherPlansView
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Diet")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func planContentView(_ plan: DietPlanSyncData) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                planHeader(plan)
                
                if plan.todayMeals.isEmpty {
                    noMealsTodayView
                } else {
                    todayMealsSection(plan.todayMeals)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
        }
    }
    
    private func planHeader(_ plan: DietPlanSyncData) -> some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(plan.weekRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                
                Text("\(plan.avgCaloriesPerDay)")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("cal/day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.15))
        )
    }
    
    private var noMealsTodayView: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz.fill")
                .font(.title)
                .foregroundStyle(.secondary)
            
            Text("No meals planned for today")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private func todayMealsSection(_ meals: [MealSyncData]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Meals")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            ForEach(meals) { meal in
                mealRow(meal)
            }
        }
    }
    
    private func mealRow(_ meal: MealSyncData) -> some View {
        HStack(spacing: 10) {
            Image(systemName: meal.typeIcon)
                .font(.title3)
                .foregroundStyle(meal.isDone ? .green : .orange)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.type.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text(meal.recipeName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .strikethrough(meal.isDone, color: .secondary)
                    .foregroundStyle(meal.isDone ? .secondary : .primary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(meal.calories)")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text("cal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.gray.opacity(meal.isDone ? 0.08 : 0.15))
        )
    }
    
    private var otherPlansView: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("No plan for this week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ForEach(sessionManager.dietPlans) { plan in
                    planSummaryRow(plan)
                }
            }
            .padding(.horizontal, 8)
        }
    }
    
    private func planSummaryRow(_ plan: DietPlanSyncData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.weekRange)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                
                Text("\(plan.avgCaloriesPerDay) cal/day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.gray.opacity(0.15))
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            
            Text("No Diet Plan")
                .font(.headline)
            
            Text("Create a diet plan on your iPhone")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#endif

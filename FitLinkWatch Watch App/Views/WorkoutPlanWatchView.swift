import SwiftUI

#if os(watchOS)

struct WorkoutPlanWatchView: View {
    
    @EnvironmentObject var sessionManager: WatchSessionManager
    
    private var currentPlans: [WorkoutPlanSyncData] {
        sessionManager.workoutPlans.filter { $0.isCurrentWeek }
    }
    
    var body: some View {
        Group {
            if !currentPlans.isEmpty {
                plansContentView
            } else if !sessionManager.workoutPlans.isEmpty {
                otherPlansView
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var plansContentView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(currentPlans) { plan in
                    planSection(plan)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
        }
    }
    
    private func planSection(_ plan: WorkoutPlanSyncData) -> some View {
        VStack(spacing: 10) {
            planHeader(plan)
            
            if let todayWorkout = plan.todayWorkout {
                todayWorkoutSection(todayWorkout)
            } else {
                noWorkoutTodayView
            }
        }
    }
    
    private func planHeader(_ plan: WorkoutPlanSyncData) -> some View {
        HStack {
            Image(systemName: plan.planTypeIcon)
                .font(.title3)
                .foregroundStyle(.cyan)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(plan.weekRange)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.cyan.opacity(0.15))
        )
    }
    
    private func todayWorkoutSection(_ workout: WorkoutDaySyncData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if workout.isRestDay {
                    Label("Rest", systemImage: "moon.zzz.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                } else {
                    Text("\(workout.estimatedMinutes) min")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            if workout.isRestDay {
                restDayCard
            } else {
                workoutDetailCard(workout)
            }
        }
    }
    
    private var restDayCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.mind.and.body")
                .font(.title)
                .foregroundStyle(.blue)
            
            Text("Rest & Recovery")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Take it easy today")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.blue.opacity(0.1))
        )
    }
    
    private func workoutDetailCard(_ workout: WorkoutDaySyncData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title3)
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.focus)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("\(workout.exerciseCount) exercises")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            if !workout.exercises.isEmpty {
                Divider()
                
                ForEach(workout.exercises) { exercise in
                    exerciseRow(exercise)
                }
                
                if workout.exerciseCount > workout.exercises.count {
                    Text("+ \(workout.exerciseCount - workout.exercises.count) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.15))
        )
    }
    
    private func exerciseRow(_ exercise: ExerciseSyncData) -> some View {
        HStack {
            Text(exercise.name)
                .font(.caption)
                .lineLimit(1)
            
            Spacer()
            
            if !exercise.setsReps.isEmpty {
                Text(exercise.setsReps)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var noWorkoutTodayView: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.minus")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("No workout scheduled")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var otherPlansView: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("No plan for this week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ForEach(sessionManager.workoutPlans) { plan in
                    planSummaryRow(plan)
                }
            }
            .padding(.horizontal, 8)
        }
    }
    
    private func planSummaryRow(_ plan: WorkoutPlanSyncData) -> some View {
        HStack {
            Image(systemName: plan.planTypeIcon)
                .font(.title3)
                .foregroundStyle(.cyan)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(plan.weekRange)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.gray.opacity(0.15))
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 40))
                .foregroundStyle(.cyan)
            
            Text("No Workout Plan")
                .font(.headline)
            
            Text("Create a workout plan on your iPhone")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#endif

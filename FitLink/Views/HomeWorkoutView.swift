import SwiftUI

struct HomeWorkoutView: View {
    let plan: WeeklyWorkoutPlan
    let planType: WorkoutPlanType
    @Binding var selectedDayIndex: Int
    
    // Internal date formatter for calculations
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
    
    // Binding for date strip
    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: {
                if selectedDayIndex < plan.days.count {
                    let dateStr = plan.days[selectedDayIndex].date
                    return dateFormatter.date(from: dateStr) ?? Date()
                }
                return Date()
            },
            set: { newDate in
                if let index = plan.days.firstIndex(where: {
                    guard let dayDate = dateFormatter.date(from: $0.date) else { return false }
                    return Calendar.current.isDate(dayDate, inSameDayAs: newDate)
                }) {
                    withAnimation {
                        selectedDayIndex = index
                    }
                }
            }
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text(plan.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(plan.weekDateRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 16)
            
            // Date Strip
            LiquidGlassDateStrip(
                selectedDate: selectedDateBinding,
                dateRange: getPlanDateRange(plan)
            )
            .padding(.vertical, 8)
            
            // Daily Content
            ScrollView {
                if selectedDayIndex < plan.days.count {
                    let day = plan.days[selectedDayIndex]
                    
                    VStack(spacing: 20) {
                        // Focus Card
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(day.isRestDay ? "Rest & Recovery" : "Day \(day.day)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                    Spacer()
                                    if !day.isRestDay {
                                        Label("\(day.estimatedDurationMinutes) min", systemImage: "clock")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Text(day.formattedFocus)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                if let notes = day.notes {
                                    Text(notes)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                        }
                        .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                        
                        // Exercises
                        if !day.isRestDay {
                            LazyVStack(spacing: 12) {
                                ForEach(day.exercises) { exercise in
                                    WorkoutExerciseRow(exercise: exercise)
                                }
                            }
                            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                        } else {
                            // Rest Day View
                            RestDayView()
                                .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 80)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private func getPlanDateRange(_ plan: WeeklyWorkoutPlan) -> [Date] {
        let dates = plan.days.compactMap { dateFormatter.date(from: $0.date) }
        guard !dates.isEmpty else { return [] }
        return dates
    }
}

// Subview for Rest Day
struct RestDayView: View {
    var body: some View {
        GlassCard(tint: .green.opacity(0.1)) {
            VStack(spacing: 16) {
                Image(systemName: "figure.mind.and.body")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, 20)
                
                Text("Take it easy today!")
                    .font(.headline)
                
                Text("Recovery is when your muscles grow. Do some light stretching or walking if you feel active.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
        }
    }
}

// Subview for Exercise Row
struct WorkoutExerciseRow: View {
    let exercise: WorkoutExercise
    
    var body: some View {
        GlassCard(isInteractive: true) {
            HStack(spacing: 16) {
                // Icon
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        if !exercise.formattedSetsReps.isEmpty {
                            Label(exercise.formattedSetsReps, systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let rest = exercise.formattedRest {
                            Label(rest, systemImage: "clock.arrow.circlepath")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                if exercise.notes != nil {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
}

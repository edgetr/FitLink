import SwiftUI

// MARK: - Habit Completion Snippet View

struct HabitCompletionSnippetView: View {
    let habitName: String
    let habitIcon: String
    let streak: Int
    let isNewCompletion: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isNewCompletion ? Color.green : Color.blue)
                    .frame(width: 56, height: 56)
                
                Image(systemName: habitIcon)
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(habitName)
                    .font(.headline)
                    .lineLimit(1)
                
                if streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(streak) day streak")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if isNewCompletion {
                    Text("Completed today!")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text("Already done today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if isNewCompletion {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
            }
        }
        .padding()
    }
}

// MARK: - Habit Status Snippet View

struct HabitStatusSnippetView: View {
    let completedCount: Int
    let totalCount: Int
    let habits: [Habit]
    
    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Progress Ring
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 8)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(completedCount)")
                            .font(.title.bold())
                        Text("of \(totalCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 80, height: 80)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Habits")
                        .font(.headline)
                    
                    if completedCount == totalCount {
                        Label("All complete!", systemImage: "star.fill")
                            .font(.subheadline)
                            .foregroundStyle(.yellow)
                    } else {
                        Text("\(totalCount - completedCount) remaining")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Habit Pills
            let today = Calendar.current.startOfDay(for: Date())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(habits.prefix(5)) { habit in
                        let isCompleted = habit.completionDates.contains {
                            Calendar.current.isDate($0, inSameDayAs: today)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: habit.icon)
                                .font(.caption)
                            Text(habit.name)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isCompleted ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        .foregroundStyle(isCompleted ? .green : .secondary)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Streak Snippet View

struct StreakSnippetView: View {
    let habitName: String
    let currentStreak: Int
    let longestStreak: Int
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(currentStreak > 0 ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 64, height: 64)
                
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(currentStreak > 0 ? .white : .gray)
                    Text("\(currentStreak)")
                        .font(.caption.bold())
                        .foregroundStyle(currentStreak > 0 ? .white : .gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(habitName)
                    .font(.headline)
                
                if currentStreak > 0 {
                    Text("\(currentStreak) day streak")
                        .font(.title3.bold())
                        .foregroundStyle(.orange)
                } else {
                    Text("No active streak")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Text("Longest: \(longestStreak) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - All Streaks Snippet View

struct AllStreaksSnippetView: View {
    let habits: [Habit]
    
    private var sortedHabits: [Habit] {
        habits.sorted { $0.currentStreak > $1.currentStreak }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Streaks")
                .font(.headline)
            
            ForEach(sortedHabits.prefix(4)) { habit in
                HStack {
                    Image(systemName: habit.icon)
                        .frame(width: 24)
                        .foregroundStyle(habit.currentStreak > 0 ? .orange : .secondary)
                    
                    Text(habit.name)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if habit.currentStreak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                            Text("\(habit.currentStreak)")
                                .font(.subheadline.bold())
                        }
                        .foregroundStyle(.orange)
                    } else {
                        Text("-")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if habits.count > 4 {
                Text("+ \(habits.count - 4) more habits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Previews

#Preview("Habit Completion - New") {
    HabitCompletionSnippetView(
        habitName: "Meditation",
        habitIcon: "brain.head.profile",
        streak: 5,
        isNewCompletion: true
    )
}

#Preview("Habit Completion - Already Done") {
    HabitCompletionSnippetView(
        habitName: "Exercise",
        habitIcon: "figure.run",
        streak: 12,
        isNewCompletion: false
    )
}

#Preview("Streak View") {
    StreakSnippetView(
        habitName: "Reading",
        currentStreak: 7,
        longestStreak: 14
    )
}

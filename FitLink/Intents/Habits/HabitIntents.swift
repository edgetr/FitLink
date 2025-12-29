import AppIntents
import SwiftUI

// MARK: - Log Habit Intent

struct LogHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Habit"
    static var description = IntentDescription("Mark a habit as complete for today")
    
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Habit")
    var habit: HabitEntity
    
    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$habit) as complete")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        var habits = try await HabitStore.shared.loadHabits(userId: nil)
        
        guard let index = habits.firstIndex(where: { $0.id.uuidString == habit.id }) else {
            return .result(dialog: "Couldn't find habit '\(habit.name)'. It may have been deleted.") {
                EmptyView()
            }
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        let isAlreadyCompleted = habits[index].completionDates.contains { 
            Calendar.current.isDate($0, inSameDayAs: today) 
        }
        
        if isAlreadyCompleted {
            let streak = habits[index].currentStreak
            return .result(
                dialog: "\(habit.name) is already logged for today! You're on a \(streak)-day streak!"
            ) {
                HabitCompletionSnippetView(
                    habitName: habit.name,
                    habitIcon: habit.icon,
                    streak: streak,
                    isNewCompletion: false
                )
            }
        }
        
        // Mark as complete
        habits[index].completionDates.append(today)
        try await HabitStore.shared.saveHabits(habits, userId: nil)
        
        let newStreak = habits[index].currentStreak
        let celebrationMessage: String
        
        if newStreak >= 7 {
            celebrationMessage = "Incredible! \(newStreak)-day streak!"
        } else if newStreak >= 3 {
            celebrationMessage = "Amazing! \(newStreak)-day streak!"
        } else if newStreak > 1 {
            celebrationMessage = "Nice! \(newStreak) days in a row!"
        } else {
            celebrationMessage = "Great start! Keep it going!"
        }
        
        return .result(
            dialog: "\(habit.name) logged! \(celebrationMessage)"
        ) {
            HabitCompletionSnippetView(
                habitName: habit.name,
                habitIcon: habit.icon,
                streak: newStreak,
                isNewCompletion: true
            )
        }
    }
}

// MARK: - Get Habit Status Intent

struct GetHabitStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Habit Status"
    static var description = IntentDescription("Check your habit completion status for today")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let habits = try await HabitStore.shared.loadHabits(userId: nil)
        
        guard !habits.isEmpty else {
            return .result(
                dialog: "You haven't set up any habits yet. Open FitLink to create your first habit."
            ) {
                EmptyView()
            }
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        let completed = habits.filter { habit in
            habit.completionDates.contains { Calendar.current.isDate($0, inSameDayAs: today) }
        }
        let remaining = habits.filter { habit in
            !habit.completionDates.contains { Calendar.current.isDate($0, inSameDayAs: today) }
        }
        
        let completedCount = completed.count
        let totalCount = habits.count
        
        let dialog: String
        if completedCount == totalCount {
            dialog = "Amazing! You've completed all \(totalCount) habits today!"
        } else if completedCount == 0 {
            dialog = "You have \(totalCount) habits to complete today. Let's get started!"
        } else {
            let remainingNames = remaining.prefix(2).map { $0.name }.joined(separator: " and ")
            let moreText = remaining.count > 2 ? " and \(remaining.count - 2) more" : ""
            dialog = "You've completed \(completedCount) of \(totalCount) habits. Still to do: \(remainingNames)\(moreText)."
        }
        
        return .result(dialog: IntentDialog(stringLiteral: dialog)) {
            HabitStatusSnippetView(
                completedCount: completedCount,
                totalCount: totalCount,
                habits: habits
            )
        }
    }
}

// MARK: - Get Streak Intent

struct GetStreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Habit Streak"
    static var description = IntentDescription("Check your current habit streaks")
    
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Habit", optionsProvider: HabitOptionsProvider())
    var habit: HabitEntity?
    
    static var parameterSummary: some ParameterSummary {
        When(\.$habit, .hasAnyValue) {
            Summary("Check streak for \(\.$habit)")
        } otherwise: {
            Summary("Check all habit streaks")
        }
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let habits = try await HabitStore.shared.loadHabits(userId: nil)
        
        if let habitEntity = habit {
            // Specific habit streak
            guard let foundHabit = habits.first(where: { $0.id.uuidString == habitEntity.id }) else {
                return .result(dialog: "Couldn't find that habit.") { EmptyView() }
            }
            
            let streak = foundHabit.currentStreak
            let longestStreak = foundHabit.longestStreak
            
            if streak > 0 {
                return .result(
                    dialog: "Your \(habitEntity.name) streak is \(streak) days! Your longest streak was \(longestStreak) days."
                ) {
                    StreakSnippetView(habitName: habitEntity.name, currentStreak: streak, longestStreak: longestStreak)
                }
            } else {
                return .result(
                    dialog: "No active streak for \(habitEntity.name). Complete it today to start one!"
                ) {
                    StreakSnippetView(habitName: habitEntity.name, currentStreak: 0, longestStreak: longestStreak)
                }
            }
        } else {
            // All habits summary
            guard !habits.isEmpty else {
                return .result(dialog: "No habits set up yet.") { EmptyView() }
            }
            
            let activeStreaks = habits.filter { $0.currentStreak > 0 }
            let longestCurrent = habits.map { $0.currentStreak }.max() ?? 0
            let topHabit = habits.max { $0.currentStreak < $1.currentStreak }
            
            if activeStreaks.isEmpty {
                return .result(
                    dialog: "No active streaks right now. Complete a habit today to start building momentum!"
                ) {
                    AllStreaksSnippetView(habits: habits)
                }
            } else {
                return .result(
                    dialog: "You have \(activeStreaks.count) active streak\(activeStreaks.count == 1 ? "" : "s"). Your longest is \(longestCurrent) days for \(topHabit?.name ?? "a habit")."
                ) {
                    AllStreaksSnippetView(habits: habits)
                }
            }
        }
    }
}

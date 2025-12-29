import Foundation

// MARK: - User Auth State

/// User authentication state synced from iPhone to Watch
struct UserAuthSyncData: Codable, Equatable {
    let isLoggedIn: Bool
    let userId: String?
    let displayName: String?
    let photoURL: String?
    
    static let notLoggedIn = UserAuthSyncData(
        isLoggedIn: false,
        userId: nil,
        displayName: nil,
        photoURL: nil
    )
    
    enum CodingKeys: String, CodingKey {
        case isLoggedIn = "is_logged_in"
        case userId = "user_id"
        case displayName = "display_name"
        case photoURL = "photo_url"
    }
}

// MARK: - Diet Plan Sync Data

/// Lightweight diet plan data for Watch display
struct DietPlanSyncData: Codable, Identifiable, Equatable {
    let id: String
    let weekRange: String
    let avgCaloriesPerDay: Int
    let totalDays: Int
    let todayMeals: [MealSyncData]
    let isCurrentWeek: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case weekRange = "week_range"
        case avgCaloriesPerDay = "avg_calories_per_day"
        case totalDays = "total_days"
        case todayMeals = "today_meals"
        case isCurrentWeek = "is_current_week"
    }
}

/// Lightweight meal data for Watch display
struct MealSyncData: Codable, Identifiable, Equatable {
    let id: String
    let type: String
    let recipeName: String
    let calories: Int
    let isDone: Bool
    
    var typeIcon: String {
        switch type.lowercased() {
        case "breakfast": return "sunrise.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.stars.fill"
        case "snack": return "leaf.fill"
        default: return "fork.knife"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case recipeName = "recipe_name"
        case calories
        case isDone = "is_done"
    }
}

// MARK: - Workout Plan Sync Data

/// Lightweight workout plan data for Watch display
struct WorkoutPlanSyncData: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let planType: String
    let weekRange: String
    let workoutDaysCount: Int
    let todayWorkout: WorkoutDaySyncData?
    let isCurrentWeek: Bool
    
    var planTypeIcon: String {
        planType == "home" ? "house.fill" : "dumbbell.fill"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case planType = "plan_type"
        case weekRange = "week_range"
        case workoutDaysCount = "workout_days_count"
        case todayWorkout = "today_workout"
        case isCurrentWeek = "is_current_week"
    }
}

/// Lightweight workout day data for Watch display
struct WorkoutDaySyncData: Codable, Identifiable, Equatable {
    let id: String
    let day: Int
    let focus: String
    let isRestDay: Bool
    let exerciseCount: Int
    let estimatedMinutes: Int
    let exercises: [ExerciseSyncData]
    
    enum CodingKeys: String, CodingKey {
        case id
        case day
        case focus
        case isRestDay = "is_rest_day"
        case exerciseCount = "exercise_count"
        case estimatedMinutes = "estimated_minutes"
        case exercises
    }
}

/// Lightweight exercise data for Watch display
struct ExerciseSyncData: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let setsReps: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case setsReps = "sets_reps"
    }
}

// MARK: - Watch Sync Payload

/// Payload sent from iPhone to Watch via Application Context
struct WatchSyncPayload: Codable {
    let timestamp: Date
    let userAuth: UserAuthSyncData
    let timerState: TimerSyncState?
    let habits: [HabitSyncData]
    let healthSummary: HealthSummaryData?
    let dietPlans: [DietPlanSyncData]
    let workoutPlans: [WorkoutPlanSyncData]
    
    static let contextKey = "watchSyncPayload"
    
    init(
        timestamp: Date = Date(),
        userAuth: UserAuthSyncData = .notLoggedIn,
        timerState: TimerSyncState? = nil,
        habits: [HabitSyncData] = [],
        healthSummary: HealthSummaryData? = nil,
        dietPlans: [DietPlanSyncData] = [],
        workoutPlans: [WorkoutPlanSyncData] = []
    ) {
        self.timestamp = timestamp
        self.userAuth = userAuth
        self.timerState = timerState
        self.habits = habits
        self.healthSummary = healthSummary
        self.dietPlans = dietPlans
        self.workoutPlans = workoutPlans
    }
    
    func toDictionary() -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(self),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }
    
    static func from(dictionary: [String: Any]) -> WatchSyncPayload? {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary),
              let payload = try? JSONDecoder().decode(WatchSyncPayload.self, from: data) else {
            return nil
        }
        return payload
    }
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case userAuth = "user_auth"
        case timerState = "timer_state"
        case habits
        case healthSummary = "health_summary"
        case dietPlans = "diet_plans"
        case workoutPlans = "workout_plans"
    }
}

// MARK: - Timer Sync State

struct TimerSyncState: Codable, Equatable {
    let isActive: Bool
    let isPaused: Bool
    let isOnBreak: Bool
    let remainingSeconds: Int
    let totalSeconds: Int
    let habitId: String?
    let habitName: String?
    let habitIcon: String?
    let endDate: Date?
    
    var isRunning: Bool { isActive && !isPaused }
    
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
    }
    
    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    static let idle = TimerSyncState(
        isActive: false,
        isPaused: false,
        isOnBreak: false,
        remainingSeconds: 0,
        totalSeconds: 0,
        habitId: nil,
        habitName: nil,
        habitIcon: nil,
        endDate: nil
    )
}

// MARK: - Habit Sync Data

struct HabitSyncData: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String
    let category: String
    let currentStreak: Int
    let isCompletedToday: Bool
    let suggestedDurationMinutes: Int
    let completionDates: [Date]
    
    enum CodingKeys: String, CodingKey {
        case id, name, icon, category
        case currentStreak = "current_streak"
        case isCompletedToday = "is_completed_today"
        case suggestedDurationMinutes = "suggested_duration_minutes"
        case completionDates = "completion_dates"
    }
}

// MARK: - Health Summary Data

struct HealthSummaryData: Codable, Equatable {
    let steps: Int
    let activeCalories: Int
    let exerciseMinutes: Int
    let lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case steps
        case activeCalories = "active_calories"
        case exerciseMinutes = "exercise_minutes"
        case lastUpdated = "last_updated"
    }
}

// MARK: - Watch Commands

enum WatchCommand: String, Codable {
    case startTimer = "start_timer"
    case pauseTimer = "pause_timer"
    case resumeTimer = "resume_timer"
    case stopTimer = "stop_timer"
    case completeHabit = "complete_habit"
    case uncompleteHabit = "uncomplete_habit"
    case requestSync = "request_sync"
}

struct WatchCommandPayload: Codable {
    let command: WatchCommand
    let habitId: String?
    let durationMinutes: Int?
    let timestamp: Date
    
    init(command: WatchCommand, habitId: String? = nil, durationMinutes: Int? = nil) {
        self.command = command
        self.habitId = habitId
        self.durationMinutes = durationMinutes
        self.timestamp = Date()
    }
    
    func toDictionary() -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(self),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }
    
    static func from(dictionary: [String: Any]) -> WatchCommandPayload? {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary),
              let payload = try? JSONDecoder().decode(WatchCommandPayload.self, from: data) else {
            return nil
        }
        return payload
    }
}

// MARK: - App Group Constants

enum WatchSyncConstants {
    static let appGroupIdentifier = "group.com.edgetr.FitLink"
    static let cachedStateKey = "watchCachedState"
    static let pendingCommandsKey = "watchPendingCommands"
}

import Foundation
import FirebaseFirestore

// MARK: - Health Metrics Store

struct HealthMetricsStore: Identifiable, Codable {
    let id: String
    var userId: String
    
    // MARK: - Daily Summaries (Last 30 days)
    var dailyMetrics: [DailyHealthMetrics]
    
    // MARK: - Computed Patterns
    var avgStepsPerDay: Int
    var avgCaloriesBurned: Int
    var avgExerciseMinutes: Int
    var avgSleepHours: Double
    var avgRestingHeartRate: Int
    
    // MARK: - Behavioral Patterns
    var peakActivityHours: [Int]
    var typicalWakeTime: TimeComponents?
    var typicalSleepTime: TimeComponents?
    var mostActiveWeekdays: [Int]
    var activityTrend: ActivityTrend
    
    // MARK: - Metadata
    var lastSyncedAt: Date
    var oldestDataDate: Date
    var newestDataDate: Date
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        dailyMetrics: [DailyHealthMetrics] = [],
        avgStepsPerDay: Int = 0,
        avgCaloriesBurned: Int = 0,
        avgExerciseMinutes: Int = 0,
        avgSleepHours: Double = 0,
        avgRestingHeartRate: Int = 0,
        peakActivityHours: [Int] = [],
        typicalWakeTime: TimeComponents? = nil,
        typicalSleepTime: TimeComponents? = nil,
        mostActiveWeekdays: [Int] = [],
        activityTrend: ActivityTrend = .insufficientData,
        lastSyncedAt: Date = Date(),
        oldestDataDate: Date = Date(),
        newestDataDate: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.dailyMetrics = dailyMetrics
        self.avgStepsPerDay = avgStepsPerDay
        self.avgCaloriesBurned = avgCaloriesBurned
        self.avgExerciseMinutes = avgExerciseMinutes
        self.avgSleepHours = avgSleepHours
        self.avgRestingHeartRate = avgRestingHeartRate
        self.peakActivityHours = peakActivityHours
        self.typicalWakeTime = typicalWakeTime
        self.typicalSleepTime = typicalSleepTime
        self.mostActiveWeekdays = mostActiveWeekdays
        self.activityTrend = activityTrend
        self.lastSyncedAt = lastSyncedAt
        self.oldestDataDate = oldestDataDate
        self.newestDataDate = newestDataDate
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case dailyMetrics = "daily_metrics"
        case avgStepsPerDay = "avg_steps_per_day"
        case avgCaloriesBurned = "avg_calories_burned"
        case avgExerciseMinutes = "avg_exercise_minutes"
        case avgSleepHours = "avg_sleep_hours"
        case avgRestingHeartRate = "avg_resting_heart_rate"
        case peakActivityHours = "peak_activity_hours"
        case typicalWakeTime = "typical_wake_time"
        case typicalSleepTime = "typical_sleep_time"
        case mostActiveWeekdays = "most_active_weekdays"
        case activityTrend = "activity_trend"
        case lastSyncedAt = "last_synced_at"
        case oldestDataDate = "oldest_data_date"
        case newestDataDate = "newest_data_date"
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "user_id": userId,
            "avg_steps_per_day": avgStepsPerDay,
            "avg_calories_burned": avgCaloriesBurned,
            "avg_exercise_minutes": avgExerciseMinutes,
            "avg_sleep_hours": avgSleepHours,
            "avg_resting_heart_rate": avgRestingHeartRate,
            "peak_activity_hours": peakActivityHours,
            "most_active_weekdays": mostActiveWeekdays,
            "activity_trend": activityTrend.rawValue,
            "last_synced_at": Timestamp(date: lastSyncedAt),
            "oldest_data_date": Timestamp(date: oldestDataDate),
            "newest_data_date": Timestamp(date: newestDataDate)
        ]
        
        if let typicalWakeTime = typicalWakeTime {
            dict["typical_wake_time"] = typicalWakeTime.toDictionary()
        }
        if let typicalSleepTime = typicalSleepTime {
            dict["typical_sleep_time"] = typicalSleepTime.toDictionary()
        }
        
        return dict
    }
    
    static func fromDictionary(_ data: [String: Any], id: String) -> HealthMetricsStore? {
        guard let userId = data["user_id"] as? String else { return nil }
        
        var store = HealthMetricsStore(id: id, userId: userId)
        
        store.avgStepsPerDay = data["avg_steps_per_day"] as? Int ?? 0
        store.avgCaloriesBurned = data["avg_calories_burned"] as? Int ?? 0
        store.avgExerciseMinutes = data["avg_exercise_minutes"] as? Int ?? 0
        store.avgSleepHours = data["avg_sleep_hours"] as? Double ?? 0
        store.avgRestingHeartRate = data["avg_resting_heart_rate"] as? Int ?? 0
        store.peakActivityHours = data["peak_activity_hours"] as? [Int] ?? []
        store.mostActiveWeekdays = data["most_active_weekdays"] as? [Int] ?? []
        
        if let raw = data["activity_trend"] as? String {
            store.activityTrend = ActivityTrend(rawValue: raw) ?? .insufficientData
        }
        if let wakeData = data["typical_wake_time"] as? [String: Any] {
            store.typicalWakeTime = TimeComponents.fromDictionary(wakeData)
        }
        if let sleepData = data["typical_sleep_time"] as? [String: Any] {
            store.typicalSleepTime = TimeComponents.fromDictionary(sleepData)
        }
        if let timestamp = data["last_synced_at"] as? Timestamp {
            store.lastSyncedAt = timestamp.dateValue()
        }
        if let timestamp = data["oldest_data_date"] as? Timestamp {
            store.oldestDataDate = timestamp.dateValue()
        }
        if let timestamp = data["newest_data_date"] as? Timestamp {
            store.newestDataDate = timestamp.dateValue()
        }
        
        return store
    }
}

// MARK: - Daily Health Metrics

struct DailyHealthMetrics: Identifiable, Codable {
    let id: String
    var date: Date
    
    // MARK: - Activity
    var steps: Int
    var activeCalories: Int
    var totalCalories: Int
    var exerciseMinutes: Int
    var standHours: Int
    var distanceKm: Double
    var flightsClimbed: Int
    
    // MARK: - Heart
    var restingHeartRate: Int?
    var avgHeartRate: Int?
    var maxHeartRate: Int?
    var heartRateVariability: Double?
    
    // MARK: - Sleep
    var sleepHours: Double?
    var sleepStartTime: Date?
    var sleepEndTime: Date?
    var sleepQuality: SleepQuality?
    var sleepStages: SleepStageBreakdown?
    
    // MARK: - Hourly Breakdown (for pattern detection)
    var hourlySteps: [Int]
    var hourlyCalories: [Int]
    var hourlyHeartRate: [Int?]
    
    // MARK: - Workout Sessions
    var workoutSessions: [WorkoutSession]
    
    init(
        id: String,
        date: Date,
        steps: Int = 0,
        activeCalories: Int = 0,
        totalCalories: Int = 0,
        exerciseMinutes: Int = 0,
        standHours: Int = 0,
        distanceKm: Double = 0,
        flightsClimbed: Int = 0,
        restingHeartRate: Int? = nil,
        avgHeartRate: Int? = nil,
        maxHeartRate: Int? = nil,
        heartRateVariability: Double? = nil,
        sleepHours: Double? = nil,
        sleepStartTime: Date? = nil,
        sleepEndTime: Date? = nil,
        sleepQuality: SleepQuality? = nil,
        sleepStages: SleepStageBreakdown? = nil,
        hourlySteps: [Int] = Array(repeating: 0, count: 24),
        hourlyCalories: [Int] = Array(repeating: 0, count: 24),
        hourlyHeartRate: [Int?] = Array(repeating: nil, count: 24),
        workoutSessions: [WorkoutSession] = []
    ) {
        self.id = id
        self.date = date
        self.steps = steps
        self.activeCalories = activeCalories
        self.totalCalories = totalCalories
        self.exerciseMinutes = exerciseMinutes
        self.standHours = standHours
        self.distanceKm = distanceKm
        self.flightsClimbed = flightsClimbed
        self.restingHeartRate = restingHeartRate
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.heartRateVariability = heartRateVariability
        self.sleepHours = sleepHours
        self.sleepStartTime = sleepStartTime
        self.sleepEndTime = sleepEndTime
        self.sleepQuality = sleepQuality
        self.sleepStages = sleepStages
        self.hourlySteps = hourlySteps
        self.hourlyCalories = hourlyCalories
        self.hourlyHeartRate = hourlyHeartRate
        self.workoutSessions = workoutSessions
    }
    
    static func makeId(userId: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(userId)_\(formatter.string(from: date))"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case steps
        case activeCalories = "active_calories"
        case totalCalories = "total_calories"
        case exerciseMinutes = "exercise_minutes"
        case standHours = "stand_hours"
        case distanceKm = "distance_km"
        case flightsClimbed = "flights_climbed"
        case restingHeartRate = "resting_heart_rate"
        case avgHeartRate = "avg_heart_rate"
        case maxHeartRate = "max_heart_rate"
        case heartRateVariability = "heart_rate_variability"
        case sleepHours = "sleep_hours"
        case sleepStartTime = "sleep_start_time"
        case sleepEndTime = "sleep_end_time"
        case sleepQuality = "sleep_quality"
        case sleepStages = "sleep_stages"
        case hourlySteps = "hourly_steps"
        case hourlyCalories = "hourly_calories"
        case hourlyHeartRate = "hourly_heart_rate"
        case workoutSessions = "workout_sessions"
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "date": Timestamp(date: date),
            "steps": steps,
            "active_calories": activeCalories,
            "total_calories": totalCalories,
            "exercise_minutes": exerciseMinutes,
            "stand_hours": standHours,
            "distance_km": distanceKm,
            "flights_climbed": flightsClimbed,
            "hourly_steps": hourlySteps,
            "hourly_calories": hourlyCalories
        ]
        
        if let restingHeartRate = restingHeartRate { dict["resting_heart_rate"] = restingHeartRate }
        if let avgHeartRate = avgHeartRate { dict["avg_heart_rate"] = avgHeartRate }
        if let maxHeartRate = maxHeartRate { dict["max_heart_rate"] = maxHeartRate }
        if let heartRateVariability = heartRateVariability { dict["heart_rate_variability"] = heartRateVariability }
        if let sleepHours = sleepHours { dict["sleep_hours"] = sleepHours }
        if let sleepStartTime = sleepStartTime { dict["sleep_start_time"] = Timestamp(date: sleepStartTime) }
        if let sleepEndTime = sleepEndTime { dict["sleep_end_time"] = Timestamp(date: sleepEndTime) }
        if let sleepQuality = sleepQuality { dict["sleep_quality"] = sleepQuality.rawValue }
        if let sleepStages = sleepStages { dict["sleep_stages"] = sleepStages.toDictionary() }
        
        let hrArray = hourlyHeartRate.map { $0 as Any }
        dict["hourly_heart_rate"] = hrArray
        
        if let sessionsData = try? JSONEncoder().encode(workoutSessions),
           let sessionsJSON = String(data: sessionsData, encoding: .utf8) {
            dict["workout_sessions_json"] = sessionsJSON
        }
        
        return dict
    }
    
    static func fromDictionary(_ data: [String: Any], id: String) -> DailyHealthMetrics? {
        guard let timestamp = data["date"] as? Timestamp else { return nil }
        
        var metrics = DailyHealthMetrics(id: id, date: timestamp.dateValue())
        
        metrics.steps = data["steps"] as? Int ?? 0
        metrics.activeCalories = data["active_calories"] as? Int ?? 0
        metrics.totalCalories = data["total_calories"] as? Int ?? 0
        metrics.exerciseMinutes = data["exercise_minutes"] as? Int ?? 0
        metrics.standHours = data["stand_hours"] as? Int ?? 0
        metrics.distanceKm = data["distance_km"] as? Double ?? 0
        metrics.flightsClimbed = data["flights_climbed"] as? Int ?? 0
        
        metrics.restingHeartRate = data["resting_heart_rate"] as? Int
        metrics.avgHeartRate = data["avg_heart_rate"] as? Int
        metrics.maxHeartRate = data["max_heart_rate"] as? Int
        metrics.heartRateVariability = data["heart_rate_variability"] as? Double
        
        metrics.sleepHours = data["sleep_hours"] as? Double
        if let sleepStart = data["sleep_start_time"] as? Timestamp {
            metrics.sleepStartTime = sleepStart.dateValue()
        }
        if let sleepEnd = data["sleep_end_time"] as? Timestamp {
            metrics.sleepEndTime = sleepEnd.dateValue()
        }
        if let raw = data["sleep_quality"] as? String {
            metrics.sleepQuality = SleepQuality(rawValue: raw)
        }
        if let stagesData = data["sleep_stages"] as? [String: Any] {
            metrics.sleepStages = SleepStageBreakdown.fromDictionary(stagesData)
        }
        
        metrics.hourlySteps = data["hourly_steps"] as? [Int] ?? Array(repeating: 0, count: 24)
        metrics.hourlyCalories = data["hourly_calories"] as? [Int] ?? Array(repeating: 0, count: 24)
        
        if let hrArray = data["hourly_heart_rate"] as? [Any] {
            metrics.hourlyHeartRate = hrArray.map { $0 as? Int }
        }
        
        if let sessionsJSON = data["workout_sessions_json"] as? String,
           let sessionsData = sessionsJSON.data(using: .utf8),
           let sessions = try? JSONDecoder().decode([WorkoutSession].self, from: sessionsData) {
            metrics.workoutSessions = sessions
        }
        
        return metrics
    }
}

// MARK: - Sleep Stage Breakdown

struct SleepStageBreakdown: Codable {
    var awakeMinutes: Int
    var remMinutes: Int
    var coreMinutes: Int
    var deepMinutes: Int
    
    var totalSleepMinutes: Int {
        remMinutes + coreMinutes + deepMinutes
    }
    
    var sleepEfficiency: Double {
        let total = awakeMinutes + remMinutes + coreMinutes + deepMinutes
        guard total > 0 else { return 0 }
        return Double(totalSleepMinutes) / Double(total)
    }
    
    enum CodingKeys: String, CodingKey {
        case awakeMinutes = "awake_minutes"
        case remMinutes = "rem_minutes"
        case coreMinutes = "core_minutes"
        case deepMinutes = "deep_minutes"
    }
    
    func toDictionary() -> [String: Any] {
        [
            "awake_minutes": awakeMinutes,
            "rem_minutes": remMinutes,
            "core_minutes": coreMinutes,
            "deep_minutes": deepMinutes
        ]
    }
    
    static func fromDictionary(_ data: [String: Any]) -> SleepStageBreakdown {
        SleepStageBreakdown(
            awakeMinutes: data["awake_minutes"] as? Int ?? 0,
            remMinutes: data["rem_minutes"] as? Int ?? 0,
            coreMinutes: data["core_minutes"] as? Int ?? 0,
            deepMinutes: data["deep_minutes"] as? Int ?? 0
        )
    }
}

// MARK: - Workout Session

struct WorkoutSession: Identifiable, Codable {
    let id: String
    var type: HealthWorkoutType
    var startTime: Date
    var endTime: Date
    var durationMinutes: Int
    var caloriesBurned: Int
    var avgHeartRate: Int?
    var maxHeartRate: Int?
    
    init(
        id: String = UUID().uuidString,
        type: HealthWorkoutType,
        startTime: Date,
        endTime: Date,
        durationMinutes: Int,
        caloriesBurned: Int,
        avgHeartRate: Int? = nil,
        maxHeartRate: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.caloriesBurned = caloriesBurned
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case startTime = "start_time"
        case endTime = "end_time"
        case durationMinutes = "duration_minutes"
        case caloriesBurned = "calories_burned"
        case avgHeartRate = "avg_heart_rate"
        case maxHeartRate = "max_heart_rate"
    }
}

// MARK: - Supporting Enums

enum HealthWorkoutType: String, Codable {
    case running
    case walking
    case cycling
    case swimming
    case strengthTraining = "strength_training"
    case hiit
    case yoga
    case pilates
    case elliptical
    case rowing
    case stairClimbing = "stair_climbing"
    case functionalTraining = "functional_training"
    case other
    
    var displayName: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .strengthTraining: return "Strength Training"
        case .hiit: return "HIIT"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair Climbing"
        case .functionalTraining: return "Functional Training"
        case .other: return "Other"
        }
    }
}

enum SleepQuality: String, Codable {
    case poor
    case fair
    case good
    case excellent
    
    static func from(efficiency: Double, deepPercentage: Double) -> SleepQuality {
        if efficiency >= 0.9 && deepPercentage >= 0.15 { return .excellent }
        if efficiency >= 0.8 && deepPercentage >= 0.10 { return .good }
        if efficiency >= 0.7 { return .fair }
        return .poor
    }
    
    var displayName: String {
        switch self {
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
}

enum ActivityTrend: String, Codable {
    case improving
    case stable
    case declining
    case insufficientData = "insufficient_data"
    
    var displayName: String {
        switch self {
        case .improving: return "Improving"
        case .stable: return "Stable"
        case .declining: return "Declining"
        case .insufficientData: return "Insufficient Data"
        }
    }
}

// MARK: - Time Components

struct TimeComponents: Codable {
    var hour: Int
    var minute: Int
    
    var formatted: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", h, minute, ampm)
    }
    
    func toDictionary() -> [String: Any] {
        ["hour": hour, "minute": minute]
    }
    
    static func fromDictionary(_ data: [String: Any]) -> TimeComponents? {
        guard let hour = data["hour"] as? Int,
              let minute = data["minute"] as? Int else {
            return nil
        }
        return TimeComponents(hour: hour, minute: minute)
    }
}

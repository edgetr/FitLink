import Foundation
import FirebaseFirestore

// MARK: - UserContextProvider

actor UserContextProvider {
    
    static let shared = UserContextProvider()
    
    private let db = Firestore.firestore()
    private var cachedContext: [String: CachedLLMUserContext] = [:]
    private let cacheValidityMinutes: Double = 30
    
    // MARK: - Main Context Retrieval
    
    func getContext(for userId: String) async throws -> LLMUserContext {
        if let cached = cachedContext[userId],
           Date().timeIntervalSince(cached.timestamp) < cacheValidityMinutes * 60 {
            return cached.context
        }
        
        let context = try await buildUserContext(userId: userId)
        
        cachedContext[userId] = CachedLLMUserContext(context: context, timestamp: Date())
        
        return context
    }
    
    func invalidateCache(for userId: String) {
        cachedContext.removeValue(forKey: userId)
    }
    
    func invalidateAllCaches() {
        cachedContext.removeAll()
    }
    
    // MARK: - Build Context
    
    private func buildUserContext(userId: String) async throws -> LLMUserContext {
        async let profile = loadUserProfile(userId: userId)
        async let metrics = loadHealthMetrics(userId: userId)
        async let history = loadPlanHistory(userId: userId)
        
        let (profileData, metricsData, historyData) = try await (profile, metrics, history)
        
        return LLMUserContext(
            userId: userId,
            profile: profileData,
            healthMetrics: metricsData,
            planHistory: historyData,
            generatedAt: Date()
        )
    }
    
    // MARK: - Load Profile
    
    private func loadUserProfile(userId: String) async throws -> LLMUserProfileContext? {
        let doc = try await db.collection("user_profiles").document(userId).getDocument()
        guard let data = doc.data() else { return nil }
        
        return LLMUserProfileContext(
            age: calculateAge(from: data["date_of_birth"] as? Timestamp),
            biologicalSex: data["biological_sex"] as? String,
            heightCm: data["height_cm"] as? Double,
            weightKg: data["weight_kg"] as? Double,
            targetWeightKg: data["target_weight_kg"] as? Double,
            bmi: calculateBMI(height: data["height_cm"] as? Double, weight: data["weight_kg"] as? Double),
            fitnessLevel: data["fitness_level"] as? String,
            primaryGoals: data["primary_goals"] as? [String] ?? [],
            preferredWorkoutTimes: data["preferred_workout_times"] as? [String] ?? [],
            hasGymAccess: data["has_gym_access"] as? Bool ?? false,
            availableEquipment: data["available_equipment"] as? [String] ?? [],
            injuriesOrLimitations: data["injuries_or_limitations"] as? [String] ?? [],
            preferredWorkoutDuration: data["preferred_workout_duration"] as? String,
            workoutDaysPerWeek: data["workout_days_per_week"] as? Int,
            dietaryRestrictions: data["dietary_restrictions"] as? [String] ?? [],
            allergies: data["allergies"] as? [String] ?? [],
            dislikedFoods: data["disliked_foods"] as? [String] ?? [],
            preferredCuisines: data["preferred_cuisines"] as? [String] ?? [],
            cookingSkillLevel: data["cooking_skill_level"] as? String,
            mealPrepTimePreference: data["meal_prep_time_preference"] as? String,
            householdSize: data["household_size"] as? Int,
            dailyCalorieTarget: data["daily_calorie_target"] as? Int,
            profileCompleteness: data["profile_completeness"] as? Double ?? 0
        )
    }
    
    // MARK: - Load Health Metrics
    
    private func loadHealthMetrics(userId: String) async throws -> LLMHealthMetricsContext? {
        let metricsDoc = try await db.collection("health_metrics").document(userId).getDocument()
        guard let data = metricsDoc.data() else { return nil }
        
        let dailySnapshot = try await db.collection("health_metrics")
            .document(userId)
            .collection("daily_metrics")
            .order(by: "date", descending: true)
            .limit(to: 7)
            .getDocuments()
        
        let recentDays = dailySnapshot.documents.compactMap { doc -> LLMRecentDayContext? in
            let d = doc.data()
            guard let timestamp = d["date"] as? Timestamp else { return nil }
            return LLMRecentDayContext(
                date: timestamp.dateValue(),
                steps: d["steps"] as? Int ?? 0,
                activeCalories: d["active_calories"] as? Int ?? 0,
                exerciseMinutes: d["exercise_minutes"] as? Int ?? 0,
                sleepHours: d["sleep_hours"] as? Double
            )
        }
        
        return LLMHealthMetricsContext(
            avgStepsPerDay: data["avg_steps_per_day"] as? Int ?? 0,
            avgCaloriesBurned: data["avg_calories_burned"] as? Int ?? 0,
            avgExerciseMinutes: data["avg_exercise_minutes"] as? Int ?? 0,
            avgSleepHours: data["avg_sleep_hours"] as? Double ?? 0,
            avgRestingHeartRate: data["avg_resting_heart_rate"] as? Int,
            peakActivityHours: data["peak_activity_hours"] as? [Int] ?? [],
            typicalWakeTime: parseTimeComponents(data["typical_wake_time"] as? [String: Int]),
            typicalSleepTime: parseTimeComponents(data["typical_sleep_time"] as? [String: Int]),
            mostActiveWeekdays: data["most_active_weekdays"] as? [Int] ?? [],
            activityTrend: data["activity_trend"] as? String ?? "insufficient_data",
            recentDays: recentDays,
            daysOfDataAvailable: data["days_of_data"] as? Int ?? recentDays.count
        )
    }
    
    // MARK: - Load Plan History
    
    private func loadPlanHistory(userId: String) async throws -> LLMPlanHistoryContext? {
        let historyDoc = try await db.collection("plan_history").document(userId).getDocument()
        guard let data = historyDoc.data() else { return nil }
        
        return LLMPlanHistoryContext(
            totalWorkoutPlansGenerated: data["total_workout_plans"] as? Int ?? 0,
            totalDietPlansGenerated: data["total_diet_plans"] as? Int ?? 0,
            avgWorkoutCompletionRate: data["avg_workout_completion_rate"] as? Double ?? 0,
            avgMealCompletionRate: data["avg_meal_completion_rate"] as? Double ?? 0,
            preferredExerciseTypes: data["preferred_exercise_types"] as? [String] ?? [],
            avoidedExerciseTypes: data["avoided_exercise_types"] as? [String] ?? [],
            preferredMealTypes: data["preferred_meal_types"] as? [String] ?? [],
            avoidedMealIngredients: data["avoided_meal_ingredients"] as? [String] ?? [],
            bestCompletionDays: data["best_completion_days"] as? [Int] ?? []
        )
    }
    
    // MARK: - Helpers
    
    private func calculateAge(from timestamp: Timestamp?) -> Int? {
        guard let dob = timestamp?.dateValue() else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }
    
    private func calculateBMI(height: Double?, weight: Double?) -> Double? {
        guard let h = height, let w = weight, h > 0 else { return nil }
        let heightM = h / 100
        return w / (heightM * heightM)
    }
    
    private func parseTimeComponents(_ dict: [String: Int]?) -> LLMTimeComponentsContext? {
        guard let d = dict, let hour = d["hour"], let minute = d["minute"] else { return nil }
        return LLMTimeComponentsContext(hour: hour, minute: minute)
    }
}

// MARK: - Context Models

struct CachedLLMUserContext {
    let context: LLMUserContext
    let timestamp: Date
}

struct LLMUserContext: Encodable {
    let userId: String
    let profile: LLMUserProfileContext?
    let healthMetrics: LLMHealthMetricsContext?
    let planHistory: LLMPlanHistoryContext?
    let generatedAt: Date
    
    // MARK: - Format for LLM Prompt
    
    func formatForPrompt() -> String {
        var sections: [String] = []
        
        sections.append("=== USER CONTEXT ===")
        sections.append("(This is automatic data collected from the user's profile and HealthKit. Use it to personalize the plan.)")
        
        if let p = profile {
            sections.append("\n## Personal Profile")
            
            var personalDetails: [String] = []
            if let age = p.age { personalDetails.append("Age: \(age)") }
            if let sex = p.biologicalSex { personalDetails.append("Sex: \(sex)") }
            if let height = p.heightCm { personalDetails.append("Height: \(Int(height))cm") }
            if let weight = p.weightKg { personalDetails.append("Weight: \(String(format: "%.1f", weight))kg") }
            if let bmi = p.bmi { personalDetails.append("BMI: \(String(format: "%.1f", bmi))") }
            if let target = p.targetWeightKg { personalDetails.append("Target Weight: \(String(format: "%.1f", target))kg") }
            
            if !personalDetails.isEmpty {
                sections.append(personalDetails.joined(separator: " | "))
            }
            
            if let level = p.fitnessLevel {
                sections.append("Fitness Level: \(level)")
            }
            if !p.primaryGoals.isEmpty {
                sections.append("Goals: \(p.primaryGoals.joined(separator: ", "))")
            }
            if !p.preferredWorkoutTimes.isEmpty {
                sections.append("Preferred Workout Times: \(p.preferredWorkoutTimes.joined(separator: ", "))")
            }
            if p.hasGymAccess {
                sections.append("Has Gym Access: Yes")
            }
            if !p.availableEquipment.isEmpty {
                sections.append("Available Equipment: \(p.availableEquipment.joined(separator: ", "))")
            }
            if !p.injuriesOrLimitations.isEmpty {
                sections.append("⚠️ INJURIES/LIMITATIONS (MUST RESPECT):")
                for injury in p.injuriesOrLimitations {
                    sections.append("  - \(injury)")
                }
            }
            if let duration = p.preferredWorkoutDuration {
                sections.append("Preferred Workout Duration: \(duration)")
            }
            if let days = p.workoutDaysPerWeek {
                sections.append("Workout Days/Week: \(days)")
            }
            
            if !p.dietaryRestrictions.isEmpty {
                sections.append("Dietary Restrictions: \(p.dietaryRestrictions.joined(separator: ", "))")
            }
            if !p.allergies.isEmpty {
                sections.append("⚠️ ALLERGIES (NEVER INCLUDE THESE INGREDIENTS):")
                for allergy in p.allergies {
                    sections.append("  - \(allergy)")
                }
            }
            if !p.dislikedFoods.isEmpty {
                sections.append("Disliked Foods: \(p.dislikedFoods.joined(separator: ", "))")
            }
            if !p.preferredCuisines.isEmpty {
                sections.append("Preferred Cuisines: \(p.preferredCuisines.joined(separator: ", "))")
            }
            if let skill = p.cookingSkillLevel {
                sections.append("Cooking Skill: \(skill)")
            }
            if let prepTime = p.mealPrepTimePreference {
                sections.append("Meal Prep Time Preference: \(prepTime)")
            }
            if let household = p.householdSize {
                sections.append("Household Size: \(household)")
            }
            if let calories = p.dailyCalorieTarget {
                sections.append("Daily Calorie Target: \(calories)")
            }
        }
        
        if let m = healthMetrics, m.daysOfDataAvailable > 0 {
            sections.append("\n## Health Metrics (Last 30 Days)")
            sections.append("Data Available: \(m.daysOfDataAvailable) days")
            
            sections.append("Daily Averages:")
            sections.append("  - Steps: \(m.avgStepsPerDay.formatted())")
            sections.append("  - Active Calories: \(m.avgCaloriesBurned)")
            sections.append("  - Exercise: \(m.avgExerciseMinutes) minutes")
            sections.append("  - Sleep: \(String(format: "%.1f", m.avgSleepHours)) hours")
            if let hr = m.avgRestingHeartRate {
                sections.append("  - Resting Heart Rate: \(hr) bpm")
            }
            
            if !m.peakActivityHours.isEmpty {
                let hourStrings = m.peakActivityHours.map { formatHour($0) }
                sections.append("Peak Activity Hours: \(hourStrings.joined(separator: ", "))")
            }
            
            if let wake = m.typicalWakeTime {
                sections.append("Typical Wake Time: \(wake.formatted)")
            }
            if let sleep = m.typicalSleepTime {
                sections.append("Typical Sleep Time: \(sleep.formatted)")
            }
            
            if !m.mostActiveWeekdays.isEmpty {
                let dayNames = m.mostActiveWeekdays.map { weekdayName($0) }
                sections.append("Most Active Days: \(dayNames.joined(separator: ", "))")
            }
            
            sections.append("Activity Trend: \(m.activityTrend)")
            
            if !m.recentDays.isEmpty {
                sections.append("\nLast 7 Days:")
                for day in m.recentDays.prefix(7) {
                    let dateStr = formatDate(day.date)
                    var dayInfo = "  \(dateStr): \(day.steps.formatted()) steps, \(day.activeCalories) cal, \(day.exerciseMinutes) min exercise"
                    if let sleep = day.sleepHours {
                        dayInfo += ", \(String(format: "%.1f", sleep))h sleep"
                    }
                    sections.append(dayInfo)
                }
            }
        }
        
        if let h = planHistory, (h.totalWorkoutPlansGenerated + h.totalDietPlansGenerated) > 0 {
            sections.append("\n## Previous Plan History")
            
            if h.totalWorkoutPlansGenerated > 0 {
                sections.append("Workout Plans Generated: \(h.totalWorkoutPlansGenerated)")
                sections.append("Workout Completion Rate: \(Int(h.avgWorkoutCompletionRate * 100))%")
            }
            
            if h.totalDietPlansGenerated > 0 {
                sections.append("Diet Plans Generated: \(h.totalDietPlansGenerated)")
                sections.append("Meal Completion Rate: \(Int(h.avgMealCompletionRate * 100))%")
            }
            
            if !h.preferredExerciseTypes.isEmpty {
                sections.append("### Exercises User Enjoys (include more of these):")
                for exercise in h.preferredExerciseTypes.prefix(5) {
                    sections.append("  ✓ \(exercise)")
                }
            }
            if !h.avoidedExerciseTypes.isEmpty {
                sections.append("### Exercises User Tends to Skip (use sparingly or substitute):")
                for exercise in h.avoidedExerciseTypes.prefix(5) {
                    sections.append("  ✗ \(exercise)")
                }
            }
            if !h.preferredMealTypes.isEmpty {
                sections.append("### Meals User Enjoys (include similar recipes):")
                for meal in h.preferredMealTypes.prefix(5) {
                    sections.append("  ✓ \(meal)")
                }
            }
            if !h.avoidedMealIngredients.isEmpty {
                sections.append("### Ingredients User Often Skips (avoid or substitute):")
                for ingredient in h.avoidedMealIngredients.prefix(5) {
                    sections.append("  ✗ \(ingredient)")
                }
            }
            if !h.bestCompletionDays.isEmpty {
                let dayNames = h.bestCompletionDays.map { weekdayName($0) }
                sections.append("Best Completion Days: \(dayNames.joined(separator: ", "))")
            }
        }
        
        sections.append("\n=== END USER CONTEXT ===\n")
        
        return sections.joined(separator: "\n")
    }
    
    // MARK: - Formatting Helpers
    
    private func formatHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h) \(ampm)"
    }
    
    private func weekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "Sunday"
        case 2: return "Monday"
        case 3: return "Tuesday"
        case 4: return "Wednesday"
        case 5: return "Thursday"
        case 6: return "Friday"
        case 7: return "Saturday"
        default: return "Day \(weekday)"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Sub-Context Models

struct LLMUserProfileContext: Encodable {
    let age: Int?
    let biologicalSex: String?
    let heightCm: Double?
    let weightKg: Double?
    let targetWeightKg: Double?
    let bmi: Double?
    let fitnessLevel: String?
    let primaryGoals: [String]
    let preferredWorkoutTimes: [String]
    let hasGymAccess: Bool
    let availableEquipment: [String]
    let injuriesOrLimitations: [String]
    let preferredWorkoutDuration: String?
    let workoutDaysPerWeek: Int?
    let dietaryRestrictions: [String]
    let allergies: [String]
    let dislikedFoods: [String]
    let preferredCuisines: [String]
    let cookingSkillLevel: String?
    let mealPrepTimePreference: String?
    let householdSize: Int?
    let dailyCalorieTarget: Int?
    let profileCompleteness: Double
}

struct LLMHealthMetricsContext: Encodable {
    let avgStepsPerDay: Int
    let avgCaloriesBurned: Int
    let avgExerciseMinutes: Int
    let avgSleepHours: Double
    let avgRestingHeartRate: Int?
    let peakActivityHours: [Int]
    let typicalWakeTime: LLMTimeComponentsContext?
    let typicalSleepTime: LLMTimeComponentsContext?
    let mostActiveWeekdays: [Int]
    let activityTrend: String
    let recentDays: [LLMRecentDayContext]
    let daysOfDataAvailable: Int
}

struct LLMTimeComponentsContext: Encodable {
    let hour: Int
    let minute: Int
    
    var formatted: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", h, minute, ampm)
    }
}

struct LLMRecentDayContext: Encodable {
    let date: Date
    let steps: Int
    let activeCalories: Int
    let exerciseMinutes: Int
    let sleepHours: Double?
}

struct LLMPlanHistoryContext: Encodable {
    let totalWorkoutPlansGenerated: Int
    let totalDietPlansGenerated: Int
    let avgWorkoutCompletionRate: Double
    let avgMealCompletionRate: Double
    let preferredExerciseTypes: [String]
    let avoidedExerciseTypes: [String]
    let preferredMealTypes: [String]
    let avoidedMealIngredients: [String]
    let bestCompletionDays: [Int]
}

// MARK: - Errors

enum UserContextProviderError: LocalizedError {
    case userNotFound
    case invalidData
    case cacheMiss
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User context not found."
        case .invalidData:
            return "Invalid user context data."
        case .cacheMiss:
            return "Context not in cache."
        }
    }
}

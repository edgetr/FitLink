import Foundation
import FirebaseFirestore

final class UserProfileService {
    
    static let shared = UserProfileService()
    
    private let db = Firestore.firestore()
    private let collectionName = "user_profiles"
    
    private init() {}
    
    // MARK: - CRUD Operations
    
    func getProfile(for userId: String) async throws -> UserProfile? {
        let document = try await db.collection(collectionName).document(userId).getDocument()
        
        guard document.exists, let data = document.data() else {
            return nil
        }
        
        return UserProfile.fromDictionary(data, id: userId)
    }
    
    func createProfile(for userId: String) async throws -> UserProfile {
        let profile = UserProfile(id: userId, userId: userId)
        try await saveProfile(profile)
        return profile
    }
    
    func saveProfile(_ profile: UserProfile) async throws {
        var updatedProfile = profile
        updatedProfile.lastUpdated = Date()
        try await db.collection(collectionName).document(profile.id).setData(updatedProfile.toDictionary())
    }
    
    func updateProfile(_ profile: UserProfile) async throws {
        var updatedProfile = profile
        updatedProfile.lastUpdated = Date()
        try await db.collection(collectionName).document(profile.id).updateData(updatedProfile.toDictionary())
    }
    
    func deleteProfile(for userId: String) async throws {
        try await db.collection(collectionName).document(userId).delete()
    }
    
    // MARK: - Partial Updates
    
    func updatePhysicalAttributes(
        for userId: String,
        dateOfBirth: Date? = nil,
        biologicalSex: BiologicalSex? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        targetWeightKg: Double? = nil
    ) async throws {
        var updates: [String: Any] = ["last_updated": Timestamp(date: Date())]
        
        if let dob = dateOfBirth { updates["date_of_birth"] = Timestamp(date: dob) }
        if let sex = biologicalSex { updates["biological_sex"] = sex.rawValue }
        if let height = heightCm { updates["height_cm"] = height }
        if let weight = weightKg { updates["weight_kg"] = weight }
        if let target = targetWeightKg { updates["target_weight_kg"] = target }
        
        try await db.collection(collectionName).document(userId).updateData(updates)
    }
    
    func updateFitnessContext(
        for userId: String,
        fitnessLevel: FitnessLevel? = nil,
        primaryGoals: [FitnessGoal]? = nil,
        preferredWorkoutTimes: [TimeOfDay]? = nil,
        hasGymAccess: Bool? = nil,
        availableEquipment: [Equipment]? = nil,
        injuriesOrLimitations: [String]? = nil,
        preferredWorkoutDuration: WorkoutDuration? = nil,
        workoutDaysPerWeek: Int? = nil
    ) async throws {
        var updates: [String: Any] = ["last_updated": Timestamp(date: Date())]
        
        if let level = fitnessLevel { updates["fitness_level"] = level.rawValue }
        if let goals = primaryGoals { updates["primary_goals"] = goals.map { $0.rawValue } }
        if let times = preferredWorkoutTimes { updates["preferred_workout_times"] = times.map { $0.rawValue } }
        if let gym = hasGymAccess { updates["has_gym_access"] = gym }
        if let equipment = availableEquipment { updates["available_equipment"] = equipment.map { $0.rawValue } }
        if let injuries = injuriesOrLimitations { updates["injuries_or_limitations"] = injuries }
        if let duration = preferredWorkoutDuration { updates["preferred_workout_duration"] = duration.rawValue }
        if let days = workoutDaysPerWeek { updates["workout_days_per_week"] = days }
        
        try await db.collection(collectionName).document(userId).updateData(updates)
    }
    
    func updateDietaryContext(
        for userId: String,
        dietaryRestrictions: [DietaryRestriction]? = nil,
        allergies: [String]? = nil,
        dislikedFoods: [String]? = nil,
        preferredCuisines: [String]? = nil,
        cookingSkillLevel: CookingSkill? = nil,
        mealPrepTimePreference: MealPrepTime? = nil,
        householdSize: Int? = nil,
        dailyCalorieTarget: Int? = nil,
        macroTargets: MacroTargets? = nil
    ) async throws {
        var updates: [String: Any] = ["last_updated": Timestamp(date: Date())]
        
        if let restrictions = dietaryRestrictions { updates["dietary_restrictions"] = restrictions.map { $0.rawValue } }
        if let allergies = allergies { updates["allergies"] = allergies }
        if let disliked = dislikedFoods { updates["disliked_foods"] = disliked }
        if let cuisines = preferredCuisines { updates["preferred_cuisines"] = cuisines }
        if let skill = cookingSkillLevel { updates["cooking_skill_level"] = skill.rawValue }
        if let prepTime = mealPrepTimePreference { updates["meal_prep_time_preference"] = prepTime.rawValue }
        if let size = householdSize { updates["household_size"] = size }
        if let calories = dailyCalorieTarget { updates["daily_calorie_target"] = calories }
        if let macros = macroTargets { updates["macro_targets"] = macros.toDictionary() }
        
        try await db.collection(collectionName).document(userId).updateData(updates)
    }
    
    func updateDetectedPatterns(
        for userId: String,
        detectedWakeTime: Date? = nil,
        detectedSleepTime: Date? = nil,
        detectedActiveHours: [Int]? = nil,
        workScheduleType: WorkSchedule? = nil
    ) async throws {
        var updates: [String: Any] = ["last_updated": Timestamp(date: Date())]
        
        if let wake = detectedWakeTime { updates["detected_wake_time"] = Timestamp(date: wake) }
        if let sleep = detectedSleepTime { updates["detected_sleep_time"] = Timestamp(date: sleep) }
        if let hours = detectedActiveHours { updates["detected_active_hours"] = hours }
        if let schedule = workScheduleType { updates["work_schedule_type"] = schedule.rawValue }
        
        try await db.collection(collectionName).document(userId).updateData(updates)
    }
    
    func updateProfileCompleteness(for userId: String, completeness: Double) async throws {
        try await db.collection(collectionName).document(userId).updateData([
            "profile_completeness": completeness,
            "last_updated": Timestamp(date: Date())
        ])
    }
    
    func updateDataSources(for userId: String, sources: [DataSource]) async throws {
        try await db.collection(collectionName).document(userId).updateData([
            "data_sources_enabled": sources.map { $0.rawValue },
            "last_updated": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Profile Completeness Calculation
    
    func calculateCompleteness(profile: UserProfile, metrics: HealthMetricsStore?) -> Double {
        var score = 0.0
        var maxScore = 0.0
        
        maxScore += 15
        if profile.dateOfBirth != nil { score += 5 }
        if profile.heightCm != nil { score += 5 }
        if profile.weightKg != nil { score += 5 }
        
        maxScore += 50
        if let metrics = metrics {
            let daysOfData = metrics.dailyMetrics.count
            score += min(Double(daysOfData) / 30.0 * 30, 30)
            if metrics.typicalWakeTime != nil { score += 10 }
            if metrics.typicalSleepTime != nil { score += 10 }
        }
        
        maxScore += 20
        if profile.fitnessLevel != nil { score += 5 }
        if !profile.primaryGoals.isEmpty { score += 5 }
        if !profile.availableEquipment.isEmpty { score += 5 }
        if profile.workoutDaysPerWeek != nil { score += 5 }
        
        maxScore += 15
        if !profile.dietaryRestrictions.isEmpty || !profile.allergies.isEmpty { score += 5 }
        if profile.cookingSkillLevel != nil { score += 5 }
        if profile.dailyCalorieTarget != nil { score += 5 }
        
        return score / maxScore
    }
    
    // MARK: - Convenience Methods
    
    func getOrCreateProfile(for userId: String) async throws -> UserProfile {
        if let existing = try await getProfile(for: userId) {
            return existing
        }
        return try await createProfile(for: userId)
    }
}

// MARK: - Errors

enum UserProfileServiceError: LocalizedError {
    case profileNotFound
    case invalidData
    case updateFailed
    
    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "User profile not found."
        case .invalidData:
            return "Invalid profile data."
        case .updateFailed:
            return "Failed to update profile."
        }
    }
}

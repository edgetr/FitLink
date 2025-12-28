import Foundation
import FirebaseFirestore

// MARK: - User Profile

struct UserProfile: Identifiable, Codable {
    let id: String
    var userId: String
    
    // MARK: - Physical Attributes (Optional - Can be inferred or manually set)
    var dateOfBirth: Date?
    var biologicalSex: BiologicalSex?
    var heightCm: Double?
    var weightKg: Double?
    var targetWeightKg: Double?
    
    // MARK: - Fitness Context
    var fitnessLevel: FitnessLevel?
    var primaryGoals: [FitnessGoal]
    var preferredWorkoutTimes: [TimeOfDay]
    var hasGymAccess: Bool
    var availableEquipment: [Equipment]
    var injuriesOrLimitations: [String]
    var preferredWorkoutDuration: WorkoutDuration?
    var workoutDaysPerWeek: Int?
    
    // MARK: - Dietary Context
    var dietaryRestrictions: [DietaryRestriction]
    var allergies: [String]
    var dislikedFoods: [String]
    var preferredCuisines: [String]
    var cookingSkillLevel: CookingSkill?
    var mealPrepTimePreference: MealPrepTime?
    var householdSize: Int?
    var dailyCalorieTarget: Int?
    var macroTargets: MacroTargets?
    
    // MARK: - Lifestyle Patterns (Auto-detected)
    var detectedWakeTime: Date?
    var detectedSleepTime: Date?
    var detectedActiveHours: [Int]
    var workScheduleType: WorkSchedule?
    
    // MARK: - Metadata
    var createdAt: Date
    var lastUpdated: Date
    var profileCompleteness: Double
    var dataSourcesEnabled: [DataSource]
    
    // MARK: - Computed Properties
    
    var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }
    
    var bmi: Double? {
        guard let height = heightCm, let weight = weightKg, height > 0 else { return nil }
        let heightM = height / 100
        return weight / (heightM * heightM)
    }
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        dateOfBirth: Date? = nil,
        biologicalSex: BiologicalSex? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        targetWeightKg: Double? = nil,
        fitnessLevel: FitnessLevel? = nil,
        primaryGoals: [FitnessGoal] = [],
        preferredWorkoutTimes: [TimeOfDay] = [],
        hasGymAccess: Bool = false,
        availableEquipment: [Equipment] = [],
        injuriesOrLimitations: [String] = [],
        preferredWorkoutDuration: WorkoutDuration? = nil,
        workoutDaysPerWeek: Int? = nil,
        dietaryRestrictions: [DietaryRestriction] = [],
        allergies: [String] = [],
        dislikedFoods: [String] = [],
        preferredCuisines: [String] = [],
        cookingSkillLevel: CookingSkill? = nil,
        mealPrepTimePreference: MealPrepTime? = nil,
        householdSize: Int? = nil,
        dailyCalorieTarget: Int? = nil,
        macroTargets: MacroTargets? = nil,
        detectedWakeTime: Date? = nil,
        detectedSleepTime: Date? = nil,
        detectedActiveHours: [Int] = [],
        workScheduleType: WorkSchedule? = nil,
        createdAt: Date = Date(),
        lastUpdated: Date = Date(),
        profileCompleteness: Double = 0.0,
        dataSourcesEnabled: [DataSource] = []
    ) {
        self.id = id
        self.userId = userId
        self.dateOfBirth = dateOfBirth
        self.biologicalSex = biologicalSex
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.targetWeightKg = targetWeightKg
        self.fitnessLevel = fitnessLevel
        self.primaryGoals = primaryGoals
        self.preferredWorkoutTimes = preferredWorkoutTimes
        self.hasGymAccess = hasGymAccess
        self.availableEquipment = availableEquipment
        self.injuriesOrLimitations = injuriesOrLimitations
        self.preferredWorkoutDuration = preferredWorkoutDuration
        self.workoutDaysPerWeek = workoutDaysPerWeek
        self.dietaryRestrictions = dietaryRestrictions
        self.allergies = allergies
        self.dislikedFoods = dislikedFoods
        self.preferredCuisines = preferredCuisines
        self.cookingSkillLevel = cookingSkillLevel
        self.mealPrepTimePreference = mealPrepTimePreference
        self.householdSize = householdSize
        self.dailyCalorieTarget = dailyCalorieTarget
        self.macroTargets = macroTargets
        self.detectedWakeTime = detectedWakeTime
        self.detectedSleepTime = detectedSleepTime
        self.detectedActiveHours = detectedActiveHours
        self.workScheduleType = workScheduleType
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
        self.profileCompleteness = profileCompleteness
        self.dataSourcesEnabled = dataSourcesEnabled
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case dateOfBirth = "date_of_birth"
        case biologicalSex = "biological_sex"
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case targetWeightKg = "target_weight_kg"
        case fitnessLevel = "fitness_level"
        case primaryGoals = "primary_goals"
        case preferredWorkoutTimes = "preferred_workout_times"
        case hasGymAccess = "has_gym_access"
        case availableEquipment = "available_equipment"
        case injuriesOrLimitations = "injuries_or_limitations"
        case preferredWorkoutDuration = "preferred_workout_duration"
        case workoutDaysPerWeek = "workout_days_per_week"
        case dietaryRestrictions = "dietary_restrictions"
        case allergies
        case dislikedFoods = "disliked_foods"
        case preferredCuisines = "preferred_cuisines"
        case cookingSkillLevel = "cooking_skill_level"
        case mealPrepTimePreference = "meal_prep_time_preference"
        case householdSize = "household_size"
        case dailyCalorieTarget = "daily_calorie_target"
        case macroTargets = "macro_targets"
        case detectedWakeTime = "detected_wake_time"
        case detectedSleepTime = "detected_sleep_time"
        case detectedActiveHours = "detected_active_hours"
        case workScheduleType = "work_schedule_type"
        case createdAt = "created_at"
        case lastUpdated = "last_updated"
        case profileCompleteness = "profile_completeness"
        case dataSourcesEnabled = "data_sources_enabled"
    }
    
    // MARK: - Firestore Conversion
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "user_id": userId,
            "primary_goals": primaryGoals.map { $0.rawValue },
            "preferred_workout_times": preferredWorkoutTimes.map { $0.rawValue },
            "has_gym_access": hasGymAccess,
            "available_equipment": availableEquipment.map { $0.rawValue },
            "injuries_or_limitations": injuriesOrLimitations,
            "dietary_restrictions": dietaryRestrictions.map { $0.rawValue },
            "allergies": allergies,
            "disliked_foods": dislikedFoods,
            "preferred_cuisines": preferredCuisines,
            "detected_active_hours": detectedActiveHours,
            "created_at": Timestamp(date: createdAt),
            "last_updated": Timestamp(date: lastUpdated),
            "profile_completeness": profileCompleteness,
            "data_sources_enabled": dataSourcesEnabled.map { $0.rawValue }
        ]
        
        if let dateOfBirth = dateOfBirth {
            dict["date_of_birth"] = Timestamp(date: dateOfBirth)
        }
        if let biologicalSex = biologicalSex {
            dict["biological_sex"] = biologicalSex.rawValue
        }
        if let heightCm = heightCm {
            dict["height_cm"] = heightCm
        }
        if let weightKg = weightKg {
            dict["weight_kg"] = weightKg
        }
        if let targetWeightKg = targetWeightKg {
            dict["target_weight_kg"] = targetWeightKg
        }
        if let fitnessLevel = fitnessLevel {
            dict["fitness_level"] = fitnessLevel.rawValue
        }
        if let preferredWorkoutDuration = preferredWorkoutDuration {
            dict["preferred_workout_duration"] = preferredWorkoutDuration.rawValue
        }
        if let workoutDaysPerWeek = workoutDaysPerWeek {
            dict["workout_days_per_week"] = workoutDaysPerWeek
        }
        if let cookingSkillLevel = cookingSkillLevel {
            dict["cooking_skill_level"] = cookingSkillLevel.rawValue
        }
        if let mealPrepTimePreference = mealPrepTimePreference {
            dict["meal_prep_time_preference"] = mealPrepTimePreference.rawValue
        }
        if let householdSize = householdSize {
            dict["household_size"] = householdSize
        }
        if let dailyCalorieTarget = dailyCalorieTarget {
            dict["daily_calorie_target"] = dailyCalorieTarget
        }
        if let macroTargets = macroTargets {
            dict["macro_targets"] = macroTargets.toDictionary()
        }
        if let detectedWakeTime = detectedWakeTime {
            dict["detected_wake_time"] = Timestamp(date: detectedWakeTime)
        }
        if let detectedSleepTime = detectedSleepTime {
            dict["detected_sleep_time"] = Timestamp(date: detectedSleepTime)
        }
        if let workScheduleType = workScheduleType {
            dict["work_schedule_type"] = workScheduleType.rawValue
        }
        
        return dict
    }
    
    static func fromDictionary(_ data: [String: Any], id: String) -> UserProfile? {
        guard let userId = data["user_id"] as? String else {
            return nil
        }
        
        var profile = UserProfile(id: id, userId: userId)
        
        if let timestamp = data["date_of_birth"] as? Timestamp {
            profile.dateOfBirth = timestamp.dateValue()
        }
        if let raw = data["biological_sex"] as? String {
            profile.biologicalSex = BiologicalSex(rawValue: raw)
        }
        profile.heightCm = data["height_cm"] as? Double
        profile.weightKg = data["weight_kg"] as? Double
        profile.targetWeightKg = data["target_weight_kg"] as? Double
        
        if let raw = data["fitness_level"] as? String {
            profile.fitnessLevel = FitnessLevel(rawValue: raw)
        }
        if let rawGoals = data["primary_goals"] as? [String] {
            profile.primaryGoals = rawGoals.compactMap { FitnessGoal(rawValue: $0) }
        }
        if let rawTimes = data["preferred_workout_times"] as? [String] {
            profile.preferredWorkoutTimes = rawTimes.compactMap { TimeOfDay(rawValue: $0) }
        }
        profile.hasGymAccess = data["has_gym_access"] as? Bool ?? false
        if let rawEquipment = data["available_equipment"] as? [String] {
            profile.availableEquipment = rawEquipment.compactMap { Equipment(rawValue: $0) }
        }
        profile.injuriesOrLimitations = data["injuries_or_limitations"] as? [String] ?? []
        if let raw = data["preferred_workout_duration"] as? String {
            profile.preferredWorkoutDuration = WorkoutDuration(rawValue: raw)
        }
        profile.workoutDaysPerWeek = data["workout_days_per_week"] as? Int
        
        if let rawRestrictions = data["dietary_restrictions"] as? [String] {
            profile.dietaryRestrictions = rawRestrictions.compactMap { DietaryRestriction(rawValue: $0) }
        }
        profile.allergies = data["allergies"] as? [String] ?? []
        profile.dislikedFoods = data["disliked_foods"] as? [String] ?? []
        profile.preferredCuisines = data["preferred_cuisines"] as? [String] ?? []
        if let raw = data["cooking_skill_level"] as? String {
            profile.cookingSkillLevel = CookingSkill(rawValue: raw)
        }
        if let raw = data["meal_prep_time_preference"] as? String {
            profile.mealPrepTimePreference = MealPrepTime(rawValue: raw)
        }
        profile.householdSize = data["household_size"] as? Int
        profile.dailyCalorieTarget = data["daily_calorie_target"] as? Int
        if let macroData = data["macro_targets"] as? [String: Any] {
            profile.macroTargets = MacroTargets.fromDictionary(macroData)
        }
        
        if let timestamp = data["detected_wake_time"] as? Timestamp {
            profile.detectedWakeTime = timestamp.dateValue()
        }
        if let timestamp = data["detected_sleep_time"] as? Timestamp {
            profile.detectedSleepTime = timestamp.dateValue()
        }
        profile.detectedActiveHours = data["detected_active_hours"] as? [Int] ?? []
        if let raw = data["work_schedule_type"] as? String {
            profile.workScheduleType = WorkSchedule(rawValue: raw)
        }
        
        if let timestamp = data["created_at"] as? Timestamp {
            profile.createdAt = timestamp.dateValue()
        }
        if let timestamp = data["last_updated"] as? Timestamp {
            profile.lastUpdated = timestamp.dateValue()
        }
        profile.profileCompleteness = data["profile_completeness"] as? Double ?? 0.0
        if let rawSources = data["data_sources_enabled"] as? [String] {
            profile.dataSourcesEnabled = rawSources.compactMap { DataSource(rawValue: $0) }
        }
        
        return profile
    }
}

// MARK: - Supporting Enums

enum BiologicalSex: String, Codable, CaseIterable {
    case male
    case female
    case other
    case preferNotToSay = "prefer_not_to_say"
    
    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

enum FitnessLevel: String, Codable, CaseIterable {
    case beginner
    case intermediate
    case advanced
    case athlete
    
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .athlete: return "Athlete"
        }
    }
}

enum FitnessGoal: String, Codable, CaseIterable {
    case loseWeight = "lose_weight"
    case buildMuscle = "build_muscle"
    case improveEndurance = "improve_endurance"
    case maintainFitness = "maintain_fitness"
    case increaseFlexibility = "increase_flexibility"
    case reduceStress = "reduce_stress"
    case improveHealth = "improve_health"
    case trainForEvent = "train_for_event"
    
    var displayName: String {
        switch self {
        case .loseWeight: return "Lose Weight"
        case .buildMuscle: return "Build Muscle"
        case .improveEndurance: return "Improve Endurance"
        case .maintainFitness: return "Maintain Fitness"
        case .increaseFlexibility: return "Increase Flexibility"
        case .reduceStress: return "Reduce Stress"
        case .improveHealth: return "Improve Health"
        case .trainForEvent: return "Train for Event"
        }
    }
}

enum TimeOfDay: String, Codable, CaseIterable {
    case earlyMorning = "early_morning"
    case morning
    case midday
    case afternoon
    case evening
    case night
    
    var displayName: String {
        switch self {
        case .earlyMorning: return "Early Morning (5-7am)"
        case .morning: return "Morning (7-10am)"
        case .midday: return "Midday (10am-2pm)"
        case .afternoon: return "Afternoon (2-5pm)"
        case .evening: return "Evening (5-8pm)"
        case .night: return "Night (8-11pm)"
        }
    }
}

enum Equipment: String, Codable, CaseIterable {
    case dumbbells
    case barbells
    case kettlebells
    case resistanceBands = "resistance_bands"
    case pullUpBar = "pull_up_bar"
    case treadmill
    case stationaryBike = "stationary_bike"
    case rowingMachine = "rowing_machine"
    case yogaMat = "yoga_mat"
    case foamRoller = "foam_roller"
    case cableMachine = "cable_machine"
    case smithMachine = "smith_machine"
    case bench
    case squatRack = "squat_rack"
    case none
    
    var displayName: String {
        switch self {
        case .dumbbells: return "Dumbbells"
        case .barbells: return "Barbells"
        case .kettlebells: return "Kettlebells"
        case .resistanceBands: return "Resistance Bands"
        case .pullUpBar: return "Pull-up Bar"
        case .treadmill: return "Treadmill"
        case .stationaryBike: return "Stationary Bike"
        case .rowingMachine: return "Rowing Machine"
        case .yogaMat: return "Yoga Mat"
        case .foamRoller: return "Foam Roller"
        case .cableMachine: return "Cable Machine"
        case .smithMachine: return "Smith Machine"
        case .bench: return "Bench"
        case .squatRack: return "Squat Rack"
        case .none: return "No Equipment"
        }
    }
}

enum WorkoutDuration: String, Codable, CaseIterable {
    case short = "15-30 minutes"
    case medium = "30-45 minutes"
    case standard = "45-60 minutes"
    case long = "60-90 minutes"
    case extended = "90+ minutes"
    
    var displayName: String {
        rawValue
    }
}

enum DietaryRestriction: String, Codable, CaseIterable {
    case vegetarian
    case vegan
    case pescatarian
    case glutenFree = "gluten_free"
    case dairyFree = "dairy_free"
    case nutFree = "nut_free"
    case halal
    case kosher
    case keto
    case paleo
    case lowCarb = "low_carb"
    case lowSodium = "low_sodium"
    case diabeticFriendly = "diabetic_friendly"
    
    var displayName: String {
        switch self {
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        case .pescatarian: return "Pescatarian"
        case .glutenFree: return "Gluten Free"
        case .dairyFree: return "Dairy Free"
        case .nutFree: return "Nut Free"
        case .halal: return "Halal"
        case .kosher: return "Kosher"
        case .keto: return "Keto"
        case .paleo: return "Paleo"
        case .lowCarb: return "Low Carb"
        case .lowSodium: return "Low Sodium"
        case .diabeticFriendly: return "Diabetic Friendly"
        }
    }
}

enum CookingSkill: String, Codable, CaseIterable {
    case beginner
    case intermediate
    case advanced
    case chef
    
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .chef: return "Chef Level"
        }
    }
}

enum MealPrepTime: String, Codable, CaseIterable {
    case quick = "under_15_minutes"
    case moderate = "15-30_minutes"
    case standard = "30-45_minutes"
    case elaborate = "45+_minutes"
    
    var displayName: String {
        switch self {
        case .quick: return "Under 15 minutes"
        case .moderate: return "15-30 minutes"
        case .standard: return "30-45 minutes"
        case .elaborate: return "45+ minutes"
        }
    }
}

enum WorkSchedule: String, Codable, CaseIterable {
    case nineFive = "9_to_5_office"
    case shift = "shift_work"
    case remote = "remote_flexible"
    case student
    case retired
    case irregular
    
    var displayName: String {
        switch self {
        case .nineFive: return "9-5 Office"
        case .shift: return "Shift Work"
        case .remote: return "Remote/Flexible"
        case .student: return "Student"
        case .retired: return "Retired"
        case .irregular: return "Irregular"
        }
    }
}

enum DataSource: String, Codable, CaseIterable {
    case healthKit = "health_kit"
    case manual
    case inferred
    
    var displayName: String {
        switch self {
        case .healthKit: return "Apple Health"
        case .manual: return "Manual Entry"
        case .inferred: return "Auto-detected"
        }
    }
}

// MARK: - Macro Targets

struct MacroTargets: Codable {
    var proteinGrams: Int?
    var carbsGrams: Int?
    var fatGrams: Int?
    var fiberGrams: Int?
    
    enum CodingKeys: String, CodingKey {
        case proteinGrams = "protein_grams"
        case carbsGrams = "carbs_grams"
        case fatGrams = "fat_grams"
        case fiberGrams = "fiber_grams"
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let proteinGrams = proteinGrams { dict["protein_grams"] = proteinGrams }
        if let carbsGrams = carbsGrams { dict["carbs_grams"] = carbsGrams }
        if let fatGrams = fatGrams { dict["fat_grams"] = fatGrams }
        if let fiberGrams = fiberGrams { dict["fiber_grams"] = fiberGrams }
        return dict
    }
    
    static func fromDictionary(_ data: [String: Any]) -> MacroTargets {
        MacroTargets(
            proteinGrams: data["protein_grams"] as? Int,
            carbsGrams: data["carbs_grams"] as? Int,
            fatGrams: data["fat_grams"] as? Int,
            fiberGrams: data["fiber_grams"] as? Int
        )
    }
}

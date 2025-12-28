import Foundation
import FirebaseFirestore

// MARK: - Plan History Store

struct PlanHistoryStore: Identifiable, Codable {
    let id: String
    var userId: String
    
    // MARK: - Workout Plan History
    var workoutPlanHistory: [PlanHistoryEntry]
    
    // MARK: - Diet Plan History
    var dietPlanHistory: [PlanHistoryEntry]
    
    // MARK: - Learned Preferences
    var preferredExerciseTypes: [String]
    var avoidedExerciseTypes: [String]
    var preferredMealTypes: [String]
    var avoidedMealIngredients: [String]
    
    // MARK: - Completion Metrics
    var avgWorkoutCompletionRate: Double
    var avgMealCompletionRate: Double
    var bestCompletionDays: [Int]
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        workoutPlanHistory: [PlanHistoryEntry] = [],
        dietPlanHistory: [PlanHistoryEntry] = [],
        preferredExerciseTypes: [String] = [],
        avoidedExerciseTypes: [String] = [],
        preferredMealTypes: [String] = [],
        avoidedMealIngredients: [String] = [],
        avgWorkoutCompletionRate: Double = 0,
        avgMealCompletionRate: Double = 0,
        bestCompletionDays: [Int] = []
    ) {
        self.id = id
        self.userId = userId
        self.workoutPlanHistory = workoutPlanHistory
        self.dietPlanHistory = dietPlanHistory
        self.preferredExerciseTypes = preferredExerciseTypes
        self.avoidedExerciseTypes = avoidedExerciseTypes
        self.preferredMealTypes = preferredMealTypes
        self.avoidedMealIngredients = avoidedMealIngredients
        self.avgWorkoutCompletionRate = avgWorkoutCompletionRate
        self.avgMealCompletionRate = avgMealCompletionRate
        self.bestCompletionDays = bestCompletionDays
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case workoutPlanHistory = "workout_plan_history"
        case dietPlanHistory = "diet_plan_history"
        case preferredExerciseTypes = "preferred_exercise_types"
        case avoidedExerciseTypes = "avoided_exercise_types"
        case preferredMealTypes = "preferred_meal_types"
        case avoidedMealIngredients = "avoided_meal_ingredients"
        case avgWorkoutCompletionRate = "avg_workout_completion_rate"
        case avgMealCompletionRate = "avg_meal_completion_rate"
        case bestCompletionDays = "best_completion_days"
    }
    
    func toDictionary() -> [String: Any] {
        [
            "id": id,
            "user_id": userId,
            "preferred_exercise_types": preferredExerciseTypes,
            "avoided_exercise_types": avoidedExerciseTypes,
            "preferred_meal_types": preferredMealTypes,
            "avoided_meal_ingredients": avoidedMealIngredients,
            "avg_workout_completion_rate": avgWorkoutCompletionRate,
            "avg_meal_completion_rate": avgMealCompletionRate,
            "best_completion_days": bestCompletionDays
        ]
    }
    
    static func fromDictionary(_ data: [String: Any], id: String) -> PlanHistoryStore? {
        guard let userId = data["user_id"] as? String else { return nil }
        
        return PlanHistoryStore(
            id: id,
            userId: userId,
            preferredExerciseTypes: data["preferred_exercise_types"] as? [String] ?? [],
            avoidedExerciseTypes: data["avoided_exercise_types"] as? [String] ?? [],
            preferredMealTypes: data["preferred_meal_types"] as? [String] ?? [],
            avoidedMealIngredients: data["avoided_meal_ingredients"] as? [String] ?? [],
            avgWorkoutCompletionRate: data["avg_workout_completion_rate"] as? Double ?? 0,
            avgMealCompletionRate: data["avg_meal_completion_rate"] as? Double ?? 0,
            bestCompletionDays: data["best_completion_days"] as? [Int] ?? []
        )
    }
}

// MARK: - Plan History Entry

struct PlanHistoryEntry: Identifiable, Codable {
    let id: String
    var planId: String
    var planType: PlanHistoryType
    var createdAt: Date
    var preferences: String
    var completionRate: Double
    var completedItems: Int
    var totalItems: Int
    var userFeedback: PlanFeedback?
    
    init(
        id: String = UUID().uuidString,
        planId: String,
        planType: PlanHistoryType,
        createdAt: Date = Date(),
        preferences: String = "",
        completionRate: Double = 0,
        completedItems: Int = 0,
        totalItems: Int = 0,
        userFeedback: PlanFeedback? = nil
    ) {
        self.id = id
        self.planId = planId
        self.planType = planType
        self.createdAt = createdAt
        self.preferences = preferences
        self.completionRate = completionRate
        self.completedItems = completedItems
        self.totalItems = totalItems
        self.userFeedback = userFeedback
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case planType = "plan_type"
        case createdAt = "created_at"
        case preferences
        case completionRate = "completion_rate"
        case completedItems = "completed_items"
        case totalItems = "total_items"
        case userFeedback = "user_feedback"
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "plan_id": planId,
            "plan_type": planType.rawValue,
            "created_at": Timestamp(date: createdAt),
            "preferences": preferences,
            "completion_rate": completionRate,
            "completed_items": completedItems,
            "total_items": totalItems
        ]
        
        if let feedback = userFeedback {
            dict["user_feedback"] = feedback.toDictionary()
        }
        
        return dict
    }
    
    static func fromDictionary(_ data: [String: Any], id: String) -> PlanHistoryEntry? {
        guard let planId = data["plan_id"] as? String,
              let planTypeRaw = data["plan_type"] as? String,
              let planType = PlanHistoryType(rawValue: planTypeRaw) else {
            return nil
        }
        
        var entry = PlanHistoryEntry(id: id, planId: planId, planType: planType)
        
        if let timestamp = data["created_at"] as? Timestamp {
            entry.createdAt = timestamp.dateValue()
        }
        entry.preferences = data["preferences"] as? String ?? ""
        entry.completionRate = data["completion_rate"] as? Double ?? 0
        entry.completedItems = data["completed_items"] as? Int ?? 0
        entry.totalItems = data["total_items"] as? Int ?? 0
        
        if let feedbackData = data["user_feedback"] as? [String: Any] {
            entry.userFeedback = PlanFeedback.fromDictionary(feedbackData)
        }
        
        return entry
    }
}

// MARK: - Plan History Type

enum PlanHistoryType: String, Codable {
    case workoutHome = "workout_home"
    case workoutGym = "workout_gym"
    case diet
    
    var displayName: String {
        switch self {
        case .workoutHome: return "Home Workout"
        case .workoutGym: return "Gym Workout"
        case .diet: return "Diet Plan"
        }
    }
}

// MARK: - Plan Feedback

struct PlanFeedback: Codable {
    var rating: Int
    var wasTooDifficult: Bool?
    var wasTooEasy: Bool?
    var portionsTooLarge: Bool?
    var portionsTooSmall: Bool?
    var notes: String?
    
    init(
        rating: Int,
        wasTooDifficult: Bool? = nil,
        wasTooEasy: Bool? = nil,
        portionsTooLarge: Bool? = nil,
        portionsTooSmall: Bool? = nil,
        notes: String? = nil
    ) {
        self.rating = rating
        self.wasTooDifficult = wasTooDifficult
        self.wasTooEasy = wasTooEasy
        self.portionsTooLarge = portionsTooLarge
        self.portionsTooSmall = portionsTooSmall
        self.notes = notes
    }
    
    enum CodingKeys: String, CodingKey {
        case rating
        case wasTooDifficult = "was_too_difficult"
        case wasTooEasy = "was_too_easy"
        case portionsTooLarge = "portions_too_large"
        case portionsTooSmall = "portions_too_small"
        case notes
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["rating": rating]
        
        if let wasTooDifficult = wasTooDifficult { dict["was_too_difficult"] = wasTooDifficult }
        if let wasTooEasy = wasTooEasy { dict["was_too_easy"] = wasTooEasy }
        if let portionsTooLarge = portionsTooLarge { dict["portions_too_large"] = portionsTooLarge }
        if let portionsTooSmall = portionsTooSmall { dict["portions_too_small"] = portionsTooSmall }
        if let notes = notes { dict["notes"] = notes }
        
        return dict
    }
    
    static func fromDictionary(_ data: [String: Any]) -> PlanFeedback {
        PlanFeedback(
            rating: data["rating"] as? Int ?? 0,
            wasTooDifficult: data["was_too_difficult"] as? Bool,
            wasTooEasy: data["was_too_easy"] as? Bool,
            portionsTooLarge: data["portions_too_large"] as? Bool,
            portionsTooSmall: data["portions_too_small"] as? Bool,
            notes: data["notes"] as? String
        )
    }
}

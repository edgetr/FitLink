import Foundation
import FirebaseFirestore

// MARK: - Memory

struct Memory: Identifiable, Codable, Equatable {
    let id: String
    let type: MemoryType
    let value: String
    let source: MemorySource
    let createdAt: Date
    let confidence: Double
    
    init(
        id: String = UUID().uuidString,
        type: MemoryType,
        value: String,
        source: MemorySource,
        createdAt: Date = Date(),
        confidence: Double = 0.5
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.source = source
        self.createdAt = createdAt
        self.confidence = confidence
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case value
        case source
        case createdAt = "created_at"
        case confidence
    }
    
    var toastMessage: String {
        switch type {
        case .preferredExercise:
            return "You enjoy \(value)"
        case .avoidedExercise:
            return "You tend to skip \(value)"
        case .preferredMeal:
            return "You like \(value)"
        case .avoidedIngredient:
            return "You avoid \(value)"
        case .preferredCuisine:
            return "You prefer \(value) cuisine"
        case .activityPattern:
            return value
        case .schedulePreference:
            return value
        }
    }
    
    func toDictionary() -> [String: Any] {
        [
            "id": id,
            "type": type.rawValue,
            "value": value,
            "source": source.rawValue,
            "created_at": Timestamp(date: createdAt),
            "confidence": confidence
        ]
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> Memory? {
        guard let id = dict["id"] as? String,
              let typeRaw = dict["type"] as? String,
              let type = MemoryType(rawValue: typeRaw),
              let value = dict["value"] as? String,
              let sourceRaw = dict["source"] as? String,
              let source = MemorySource(rawValue: sourceRaw) else {
            return nil
        }
        
        let createdAt = (dict["created_at"] as? Timestamp)?.dateValue() ?? Date()
        let confidence = dict["confidence"] as? Double ?? 0.5
        
        return Memory(
            id: id,
            type: type,
            value: value,
            source: source,
            createdAt: createdAt,
            confidence: confidence
        )
    }
}

// MARK: - MemoryType

enum MemoryType: String, Codable, CaseIterable {
    case preferredExercise = "preferred_exercise"
    case avoidedExercise = "avoided_exercise"
    case preferredMeal = "preferred_meal"
    case avoidedIngredient = "avoided_ingredient"
    case preferredCuisine = "preferred_cuisine"
    case activityPattern = "activity_pattern"
    case schedulePreference = "schedule_preference"
    
    var displayName: String {
        switch self {
        case .preferredExercise: return "Likes exercise"
        case .avoidedExercise: return "Avoids exercise"
        case .preferredMeal: return "Likes meal"
        case .avoidedIngredient: return "Avoids ingredient"
        case .preferredCuisine: return "Prefers cuisine"
        case .activityPattern: return "Activity pattern"
        case .schedulePreference: return "Schedule preference"
        }
    }
    
    var icon: String {
        switch self {
        case .preferredExercise: return "figure.run"
        case .avoidedExercise: return "figure.run.slash"
        case .preferredMeal: return "fork.knife"
        case .avoidedIngredient: return "xmark.circle"
        case .preferredCuisine: return "globe"
        case .activityPattern: return "chart.line.uptrend.xyaxis"
        case .schedulePreference: return "clock"
        }
    }
    
    var isPositive: Bool {
        switch self {
        case .preferredExercise, .preferredMeal, .preferredCuisine, .activityPattern, .schedulePreference:
            return true
        case .avoidedExercise, .avoidedIngredient:
            return false
        }
    }
}

// MARK: - MemorySource

enum MemorySource: String, Codable {
    case completedExercise = "completed_exercise"
    case skippedExercise = "skipped_exercise"
    case completedMeal = "completed_meal"
    case skippedMeal = "skipped_meal"
    case conversation = "conversation"
    case healthKitPattern = "healthkit_pattern"
    case manualEntry = "manual_entry"
    
    var displayName: String {
        switch self {
        case .completedExercise: return "Completed in workout"
        case .skippedExercise: return "Skipped in workout"
        case .completedMeal: return "Completed meal"
        case .skippedMeal: return "Skipped meal"
        case .conversation: return "Mentioned in chat"
        case .healthKitPattern: return "Detected from activity"
        case .manualEntry: return "Added manually"
        }
    }
}

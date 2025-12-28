import Foundation
import FirebaseFirestore

// MARK: - Generation Plan Type

enum GenerationPlanType: String, Codable {
    case diet
    case workoutHome
    case workoutGym
    
    var displayName: String {
        switch self {
        case .diet: return "Meal Plan"
        case .workoutHome: return "Home Workout Plan"
        case .workoutGym: return "Gym Workout Plan"
        }
    }
    
    var notificationTitle: String {
        switch self {
        case .diet: return "Your Meal Plan is Ready!"
        case .workoutHome: return "Your Home Workout is Ready!"
        case .workoutGym: return "Your Gym Workout is Ready!"
        }
    }
}

// MARK: - Generation Phase

enum GenerationPhase: String, Codable {
    case conversation
    case generating
    case completed
    case failed
    
    var isActive: Bool {
        self == .conversation || self == .generating
    }
    
    var isTerminal: Bool {
        self == .completed || self == .failed
    }
}

// MARK: - Pending Generation

struct PendingGeneration: Identifiable, Codable {
    static let schemaVersion = 2
    static let maxMessages = 10
    
    var id: String
    var userId: String
    var planType: GenerationPlanType
    var conversationHistory: [ChatMessage]
    var collectedContext: String
    var phase: GenerationPhase
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var resultPlanId: String?
    var errorMessage: String?
    var notificationSent: Bool
    var messageCount: Int
    var schemaVersion: Int
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        planType: GenerationPlanType,
        conversationHistory: [ChatMessage] = [],
        collectedContext: String = "",
        phase: GenerationPhase = .conversation,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        resultPlanId: String? = nil,
        errorMessage: String? = nil,
        notificationSent: Bool = false,
        messageCount: Int = 0,
        schemaVersion: Int = Self.schemaVersion
    ) {
        self.id = id
        self.userId = userId
        self.planType = planType
        self.conversationHistory = conversationHistory
        self.collectedContext = collectedContext
        self.phase = phase
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.resultPlanId = resultPlanId
        self.errorMessage = errorMessage
        self.notificationSent = notificationSent
        self.messageCount = messageCount
        self.schemaVersion = schemaVersion
    }
    
    var canContinueConversation: Bool {
        phase == .conversation && messageCount < Self.maxMessages
    }
    
    var shouldForceGenerate: Bool {
        phase == .conversation && messageCount >= Self.maxMessages
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case planType = "plan_type"
        case conversationHistory = "conversation_history"
        case collectedContext = "collected_context"
        case phase
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case completedAt = "completed_at"
        case resultPlanId = "result_plan_id"
        case errorMessage = "error_message"
        case notificationSent = "notification_sent"
        case messageCount = "message_count"
        case schemaVersion = "schema_version"
    }
    
    var isRecoverable: Bool {
        switch phase {
        case .conversation:
            return !conversationHistory.isEmpty
        case .generating:
            return true
        case .completed, .failed:
            return false
        }
    }
    
    var recoveryDescription: String {
        switch phase {
        case .conversation:
            return "Resume conversation with \(messageCount) messages"
        case .generating:
            return "Resume \(planType.displayName) generation"
        case .completed:
            return "View completed \(planType.displayName)"
        case .failed:
            return "Retry failed \(planType.displayName)"
        }
    }
}

// MARK: - Firebase Conversion

extension PendingGeneration {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "user_id": userId,
            "plan_type": planType.rawValue,
            "collected_context": collectedContext,
            "phase": phase.rawValue,
            "created_at": Timestamp(date: createdAt),
            "updated_at": Timestamp(date: updatedAt),
            "notification_sent": notificationSent,
            "message_count": messageCount,
            "schema_version": schemaVersion
        ]
        
        if let historyData = try? JSONEncoder().encode(conversationHistory),
           let historyJSON = String(data: historyData, encoding: .utf8) {
            dict["conversation_history_json"] = historyJSON
        }
        
        if let completedAt = completedAt {
            dict["completed_at"] = Timestamp(date: completedAt)
        }
        
        if let resultPlanId = resultPlanId {
            dict["result_plan_id"] = resultPlanId
        }
        
        if let errorMessage = errorMessage {
            dict["error_message"] = errorMessage
        }
        
        return dict
    }
    
    static func fromDictionary(_ data: [String: Any], id: String) -> PendingGeneration? {
        guard let userId = data["user_id"] as? String,
              let planTypeRaw = data["plan_type"] as? String,
              let planType = GenerationPlanType(rawValue: planTypeRaw),
              let phaseRaw = data["phase"] as? String,
              let phase = GenerationPhase(rawValue: phaseRaw) else {
            appLog("Failed to parse PendingGeneration: missing required fields", level: .warning, category: .ai)
            return nil
        }
        
        let storedVersion = data["schema_version"] as? Int ?? 1
        if storedVersion < schemaVersion {
            appLog("Migrating PendingGeneration from v\(storedVersion) to v\(schemaVersion)", level: .info, category: .ai)
        }
        
        var generation = PendingGeneration(
            id: id,
            userId: userId,
            planType: planType,
            phase: phase,
            schemaVersion: schemaVersion
        )
        
        generation.collectedContext = data["collected_context"] as? String ?? ""
        generation.notificationSent = data["notification_sent"] as? Bool ?? false
        generation.messageCount = data["message_count"] as? Int ?? 0
        generation.resultPlanId = data["result_plan_id"] as? String
        generation.errorMessage = data["error_message"] as? String
        
        if let createdAt = (data["created_at"] as? Timestamp)?.dateValue() {
            generation.createdAt = createdAt
        }
        if let updatedAt = (data["updated_at"] as? Timestamp)?.dateValue() {
            generation.updatedAt = updatedAt
        }
        if let completedAt = (data["completed_at"] as? Timestamp)?.dateValue() {
            generation.completedAt = completedAt
        }
        
        if let historyJSON = data["conversation_history_json"] as? String,
           let directData = historyJSON.data(using: .utf8) {
            if let history = try? JSONDecoder().decode([ChatMessage].self, from: directData) {
                generation.conversationHistory = history
            } else if let base64Data = Data(base64Encoded: historyJSON),
                      let history = try? JSONDecoder().decode([ChatMessage].self, from: base64Data) {
                generation.conversationHistory = history
            } else {
                appLog("Failed to decode conversation history for generation \(id)", level: .warning, category: .ai)
            }
        }
        
        return generation
    }
}

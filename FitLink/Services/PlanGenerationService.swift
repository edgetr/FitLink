import Foundation
import FirebaseFirestore

class PlanGenerationService {
    
    static let shared = PlanGenerationService()
    
    private let db = Firestore.firestore()
    private let collectionName = "pending_generations"
    
    private init() {}
    
    // MARK: - Create
    
    func createPendingGeneration(
        userId: String,
        planType: GenerationPlanType,
        initialPrompt: String
    ) async throws -> PendingGeneration {
        let initialMessage = ChatMessage.user(initialPrompt)
        
        var generation = PendingGeneration(
            userId: userId,
            planType: planType,
            conversationHistory: [initialMessage],
            collectedContext: initialPrompt,
            messageCount: 1
        )
        
        let docRef = db.collection(collectionName).document(generation.id)
        try await docRef.setData(generation.toDictionary())
        
        return generation
    }
    
    // MARK: - Update Conversation
    
    func addMessage(
        generationId: String,
        message: ChatMessage,
        updatedContext: String
    ) async throws {
        let docRef = db.collection(collectionName).document(generationId)
        
        let doc = try await docRef.getDocument()
        guard var generation = doc.data().flatMap({ PendingGeneration.fromDictionary($0, id: generationId) }) else {
            throw PlanGenerationServiceError.notFound
        }
        
        generation.conversationHistory.append(message)
        generation.collectedContext = updatedContext
        generation.messageCount = generation.conversationHistory.filter { $0.role == .user }.count
        generation.updatedAt = Date()
        
        try await docRef.setData(generation.toDictionary())
    }
    
    func updateConversation(
        generationId: String,
        messages: [ChatMessage],
        context: String
    ) async throws {
        let docRef = db.collection(collectionName).document(generationId)
        
        let userMessageCount = messages.filter { $0.role == .user }.count
        
        // Encode as plain JSON string (consistent with PendingGeneration.toDictionary())
        guard let historyData = try? JSONEncoder().encode(messages),
              let historyJSON = String(data: historyData, encoding: .utf8) else {
            throw PlanGenerationServiceError.encodingFailed
        }
        
        try await docRef.updateData([
            "conversation_history_json": historyJSON,
            "collected_context": context,
            "message_count": userMessageCount,
            "updated_at": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Phase Transitions
    
    func startGeneration(_ generationId: String) async throws {
        let docRef = db.collection(collectionName).document(generationId)
        try await docRef.updateData([
            "phase": GenerationPhase.generating.rawValue,
            "updated_at": Timestamp(date: Date())
        ])
    }
    
    func markCompleted(
        generationId: String,
        resultPlanId: String
    ) async throws {
        let docRef = db.collection(collectionName).document(generationId)
        try await docRef.updateData([
            "phase": GenerationPhase.completed.rawValue,
            "result_plan_id": resultPlanId,
            "completed_at": Timestamp(date: Date()),
            "updated_at": Timestamp(date: Date())
        ])
    }
    
    func markFailed(
        generationId: String,
        error: String
    ) async throws {
        let docRef = db.collection(collectionName).document(generationId)
        try await docRef.updateData([
            "phase": GenerationPhase.failed.rawValue,
            "error_message": error,
            "updated_at": Timestamp(date: Date())
        ])
    }
    
    func markNotificationSent(_ generationId: String) async throws {
        let docRef = db.collection(collectionName).document(generationId)
        try await docRef.updateData([
            "notification_sent": true,
            "updated_at": Timestamp(date: Date())
        ])
    }
    
    // MARK: - Load
    
    func loadGeneration(id: String) async throws -> PendingGeneration? {
        let doc = try await db.collection(collectionName).document(id).getDocument()
        guard let data = doc.data() else { return nil }
        return PendingGeneration.fromDictionary(data, id: id)
    }
    
    func loadActiveGenerations(userId: String) async throws -> [PendingGeneration] {
        let snapshot = try await db.collection(collectionName)
            .whereField("user_id", isEqualTo: userId)
            .whereField("phase", in: [
                GenerationPhase.conversation.rawValue,
                GenerationPhase.generating.rawValue
            ])
            .order(by: "updated_at", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            PendingGeneration.fromDictionary(doc.data(), id: doc.documentID)
        }
    }
    
    func loadGeneratingPhase(userId: String) async throws -> [PendingGeneration] {
        let snapshot = try await db.collection(collectionName)
            .whereField("user_id", isEqualTo: userId)
            .whereField("phase", isEqualTo: GenerationPhase.generating.rawValue)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            PendingGeneration.fromDictionary(doc.data(), id: doc.documentID)
        }
    }
    
    func loadCompletedUnnotified(userId: String) async throws -> [PendingGeneration] {
        let snapshot = try await db.collection(collectionName)
            .whereField("user_id", isEqualTo: userId)
            .whereField("phase", isEqualTo: GenerationPhase.completed.rawValue)
            .whereField("notification_sent", isEqualTo: false)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            PendingGeneration.fromDictionary(doc.data(), id: doc.documentID)
        }
    }
    
    func loadRecentCompleted(
        userId: String,
        planType: GenerationPlanType? = nil,
        limit: Int = 10
    ) async throws -> [PendingGeneration] {
        var query = db.collection(collectionName)
            .whereField("user_id", isEqualTo: userId)
            .whereField("phase", isEqualTo: GenerationPhase.completed.rawValue)
        
        if let planType = planType {
            query = query.whereField("plan_type", isEqualTo: planType.rawValue)
        }
        
        let snapshot = try await query
            .order(by: "completed_at", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            PendingGeneration.fromDictionary(doc.data(), id: doc.documentID)
        }
    }
    
    // MARK: - Delete
    
    func deleteGeneration(_ generationId: String) async throws {
        try await db.collection(collectionName).document(generationId).delete()
    }
    
    func cleanupOldGenerations(userId: String) async throws -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let snapshot = try await db.collection(collectionName)
            .whereField("user_id", isEqualTo: userId)
            .whereField("phase", in: [
                GenerationPhase.completed.rawValue,
                GenerationPhase.failed.rawValue
            ])
            .whereField("completed_at", isLessThan: Timestamp(date: cutoffDate))
            .getDocuments()
        
        var deletedCount = 0
        for doc in snapshot.documents {
            try await doc.reference.delete()
            deletedCount += 1
        }
        
        return deletedCount
    }
}

// MARK: - Errors

enum PlanGenerationServiceError: LocalizedError {
    case notFound
    case invalidState
    case encodingFailed
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Generation not found."
        case .invalidState:
            return "Invalid generation state for this operation."
        case .encodingFailed:
            return "Failed to encode generation data."
        case .decodingFailed:
            return "Failed to decode generation data."
        }
    }
}

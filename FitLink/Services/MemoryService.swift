import Foundation
import FirebaseFirestore
import Combine

typealias MemoryAddedCallback = (Memory) -> Void

actor MemoryService {
    
    static let shared = MemoryService()
    
    private let db = Firestore.firestore()
    
    private let memoryAddedSubject = PassthroughSubject<Memory, Never>()
    nonisolated var memoryAddedPublisher: AnyPublisher<Memory, Never> {
        memoryAddedSubject.eraseToAnyPublisher()
    }
    
    private init() {}
    
    // MARK: - Retrieve
    
    func getAllMemories(userId: String) async throws -> [Memory] {
        let snapshot = try await db.collection("memories")
            .document(userId)
            .collection("items")
            .order(by: "created_at", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            Memory.fromDictionary(doc.data())
        }
    }
    
    func getMemories(userId: String, type: MemoryType) async throws -> [Memory] {
        let snapshot = try await db.collection("memories")
            .document(userId)
            .collection("items")
            .whereField("type", isEqualTo: type.rawValue)
            .order(by: "created_at", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            Memory.fromDictionary(doc.data())
        }
    }
    
    // MARK: - Add
    
    func addMemory(
        userId: String,
        type: MemoryType,
        value: String,
        source: MemorySource,
        showToast: Bool = true
    ) async throws {
        let existing = try await db.collection("memories")
            .document(userId)
            .collection("items")
            .whereField("type", isEqualTo: type.rawValue)
            .whereField("value", isEqualTo: value)
            .getDocuments()
        
        if let existingDoc = existing.documents.first {
            let currentConfidence = existingDoc.data()["confidence"] as? Double ?? 0.5
            let newConfidence = min(1.0, currentConfidence + 0.1)
            
            try await existingDoc.reference.updateData([
                "confidence": newConfidence,
                "created_at": Timestamp(date: Date())
            ])
            return
        }
        
        let memory = Memory(
            id: UUID().uuidString,
            type: type,
            value: value,
            source: source,
            createdAt: Date(),
            confidence: 0.5
        )
        
        try await db.collection("memories")
            .document(userId)
            .collection("items")
            .document(memory.id)
            .setData(memory.toDictionary())
        
        try await updateLegacyAggregates(userId: userId, memory: memory)
        
        if showToast {
            memoryAddedSubject.send(memory)
        }
    }
    
    // MARK: - Delete
    
    func deleteMemory(userId: String, memoryId: String) async throws {
        let doc = try await db.collection("memories")
            .document(userId)
            .collection("items")
            .document(memoryId)
            .getDocument()
        
        guard let memory = doc.data().flatMap(Memory.fromDictionary) else {
            return
        }
        
        try await db.collection("memories")
            .document(userId)
            .collection("items")
            .document(memoryId)
            .delete()
        
        try await removeLegacyAggregate(userId: userId, memory: memory)
    }
    
    func deleteAllMemories(userId: String) async throws {
        let snapshot = try await db.collection("memories")
            .document(userId)
            .collection("items")
            .getDocuments()
        
        let batch = db.batch()
        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
        
        try await db.collection("plan_history").document(userId).setData([
            "preferred_exercise_types": [],
            "avoided_exercise_types": [],
            "preferred_meal_types": [],
            "avoided_meal_ingredients": []
        ], merge: true)
    }
    
    // MARK: - Convenience Recording Methods
    
    func recordCompletedExercise(userId: String, exerciseName: String) async throws {
        try await addMemory(
            userId: userId,
            type: .preferredExercise,
            value: exerciseName,
            source: .completedExercise,
            showToast: true
        )
    }
    
    func recordSkippedExercise(userId: String, exerciseName: String) async throws {
        try await addMemory(
            userId: userId,
            type: .avoidedExercise,
            value: exerciseName,
            source: .skippedExercise,
            showToast: true
        )
    }
    
    func recordCompletedMeal(userId: String, mealName: String) async throws {
        try await addMemory(
            userId: userId,
            type: .preferredMeal,
            value: mealName,
            source: .completedMeal,
            showToast: true
        )
    }
    
    func recordSkippedIngredients(userId: String, ingredients: [String]) async throws {
        for ingredient in ingredients {
            try await addMemory(
                userId: userId,
                type: .avoidedIngredient,
                value: ingredient,
                source: .skippedMeal,
                showToast: true
            )
        }
    }
    
    func recordConversationPreference(
        userId: String,
        type: MemoryType,
        value: String
    ) async throws {
        try await addMemory(
            userId: userId,
            type: type,
            value: value,
            source: .conversation,
            showToast: true
        )
    }
    
    func recordActivityPattern(userId: String, pattern: String) async throws {
        try await addMemory(
            userId: userId,
            type: .activityPattern,
            value: pattern,
            source: .healthKitPattern,
            showToast: false
        )
    }
    
    // MARK: - Legacy Compatibility
    
    private func updateLegacyAggregates(userId: String, memory: Memory) async throws {
        let docRef = db.collection("plan_history").document(userId)
        
        let fieldName: String
        switch memory.type {
        case .preferredExercise:
            fieldName = "preferred_exercise_types"
        case .avoidedExercise:
            fieldName = "avoided_exercise_types"
        case .preferredMeal:
            fieldName = "preferred_meal_types"
        case .avoidedIngredient:
            fieldName = "avoided_meal_ingredients"
        default:
            return
        }
        
        try await docRef.setData([
            fieldName: FieldValue.arrayUnion([memory.value])
        ], merge: true)
    }
    
    private func removeLegacyAggregate(userId: String, memory: Memory) async throws {
        let docRef = db.collection("plan_history").document(userId)
        
        let fieldName: String
        switch memory.type {
        case .preferredExercise:
            fieldName = "preferred_exercise_types"
        case .avoidedExercise:
            fieldName = "avoided_exercise_types"
        case .preferredMeal:
            fieldName = "preferred_meal_types"
        case .avoidedIngredient:
            fieldName = "avoided_meal_ingredients"
        default:
            return
        }
        
        try await docRef.setData([
            fieldName: FieldValue.arrayRemove([memory.value])
        ], merge: true)
    }
}

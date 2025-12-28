import Foundation
import FirebaseFirestore

final class PlanHistoryService {
    
    static let shared = PlanHistoryService()
    
    private let db = Firestore.firestore()
    private let collectionName = "plan_history"
    private let entriesSubcollection = "entries"
    
    private init() {}
    
    // MARK: - Store Operations
    
    func getHistoryStore(for userId: String) async throws -> PlanHistoryStore? {
        let document = try await db.collection(collectionName).document(userId).getDocument()
        
        guard document.exists, let data = document.data() else {
            return nil
        }
        
        var store = PlanHistoryStore.fromDictionary(data, id: userId)
        
        let entries = try await loadEntries(for: userId)
        store?.workoutPlanHistory = entries.filter { $0.planType != .diet }
        store?.dietPlanHistory = entries.filter { $0.planType == .diet }
        
        return store
    }
    
    func createHistoryStore(for userId: String) async throws -> PlanHistoryStore {
        let store = PlanHistoryStore(id: userId, userId: userId)
        try await saveHistoryStore(store)
        return store
    }
    
    func saveHistoryStore(_ store: PlanHistoryStore) async throws {
        try await db.collection(collectionName).document(store.id).setData(store.toDictionary())
    }
    
    func deleteHistoryStore(for userId: String) async throws {
        let entriesDocs = try await db.collection(collectionName)
            .document(userId)
            .collection(entriesSubcollection)
            .getDocuments()
        
        for doc in entriesDocs.documents {
            try await doc.reference.delete()
        }
        
        try await db.collection(collectionName).document(userId).delete()
    }
    
    // MARK: - Entry Operations
    
    func loadEntries(for userId: String) async throws -> [PlanHistoryEntry] {
        let snapshot = try await db.collection(collectionName)
            .document(userId)
            .collection(entriesSubcollection)
            .order(by: "created_at", descending: true)
            .limit(to: 100)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            PlanHistoryEntry.fromDictionary(doc.data(), id: doc.documentID)
        }
    }
    
    func loadEntries(for userId: String, type: PlanHistoryType) async throws -> [PlanHistoryEntry] {
        let snapshot = try await db.collection(collectionName)
            .document(userId)
            .collection(entriesSubcollection)
            .whereField("plan_type", isEqualTo: type.rawValue)
            .order(by: "created_at", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            PlanHistoryEntry.fromDictionary(doc.data(), id: doc.documentID)
        }
    }
    
    func getEntry(id: String, userId: String) async throws -> PlanHistoryEntry? {
        let document = try await db.collection(collectionName)
            .document(userId)
            .collection(entriesSubcollection)
            .document(id)
            .getDocument()
        
        guard document.exists, let data = document.data() else {
            return nil
        }
        
        return PlanHistoryEntry.fromDictionary(data, id: id)
    }
    
    func addEntry(_ entry: PlanHistoryEntry, userId: String) async throws {
        try await db.collection(collectionName)
            .document(userId)
            .collection(entriesSubcollection)
            .document(entry.id)
            .setData(entry.toDictionary())
        
        try await recalculateAggregates(for: userId)
    }
    
    func updateEntry(_ entry: PlanHistoryEntry, userId: String) async throws {
        try await db.collection(collectionName)
            .document(userId)
            .collection(entriesSubcollection)
            .document(entry.id)
            .updateData(entry.toDictionary())
        
        try await recalculateAggregates(for: userId)
    }
    
    func updateCompletionRate(entryId: String, userId: String, completedItems: Int, totalItems: Int) async throws {
        let rate = totalItems > 0 ? Double(completedItems) / Double(totalItems) : 0
        
        try await db.collection(collectionName)
            .document(userId)
            .collection(entriesSubcollection)
            .document(entryId)
            .updateData([
                "completed_items": completedItems,
                "total_items": totalItems,
                "completion_rate": rate
            ])
        
        try await recalculateAggregates(for: userId)
    }
    
    func addFeedback(_ feedback: PlanFeedback, entryId: String, userId: String) async throws {
        try await db.collection(collectionName)
            .document(userId)
            .collection(entriesSubcollection)
            .document(entryId)
            .updateData(["user_feedback": feedback.toDictionary()])
    }
    
    func deleteEntry(id: String, userId: String) async throws {
        try await db.collection(collectionName)
            .document(userId)
            .collection(entriesSubcollection)
            .document(id)
            .delete()
        
        try await recalculateAggregates(for: userId)
    }
    
    // MARK: - Aggregate Calculations
    
    private func recalculateAggregates(for userId: String) async throws {
        let entries = try await loadEntries(for: userId)
        
        let workoutEntries = entries.filter { $0.planType != .diet }
        let dietEntries = entries.filter { $0.planType == .diet }
        
        let avgWorkoutRate = workoutEntries.isEmpty ? 0 :
            workoutEntries.reduce(0) { $0 + $1.completionRate } / Double(workoutEntries.count)
        let avgMealRate = dietEntries.isEmpty ? 0 :
            dietEntries.reduce(0) { $0 + $1.completionRate } / Double(dietEntries.count)
        
        let bestDays = calculateBestCompletionDays(from: entries)
        
        try await db.collection(collectionName).document(userId).setData([
            "avg_workout_completion_rate": avgWorkoutRate,
            "avg_meal_completion_rate": avgMealRate,
            "best_completion_days": bestDays
        ], merge: true)
    }
    
    private func calculateBestCompletionDays(from entries: [PlanHistoryEntry]) -> [Int] {
        var weekdayRates = Array(repeating: (total: 0.0, count: 0), count: 7)
        
        for entry in entries {
            let weekday = Calendar.current.component(.weekday, from: entry.createdAt)
            weekdayRates[weekday - 1].total += entry.completionRate
            weekdayRates[weekday - 1].count += 1
        }
        
        let averages = weekdayRates.enumerated().map { i, data -> (weekday: Int, avg: Double) in
            (i + 1, data.count > 0 ? data.total / Double(data.count) : 0)
        }
        
        return averages.sorted { $0.avg > $1.avg }.prefix(3).map { $0.weekday }
    }
    
    // MARK: - Learned Preferences
    
    func updateLearnedPreferences(
        for userId: String,
        preferredExerciseTypes: [String]? = nil,
        avoidedExerciseTypes: [String]? = nil,
        preferredMealTypes: [String]? = nil,
        avoidedMealIngredients: [String]? = nil
    ) async throws {
        var updates: [String: Any] = [:]
        
        if let preferred = preferredExerciseTypes { updates["preferred_exercise_types"] = preferred }
        if let avoided = avoidedExerciseTypes { updates["avoided_exercise_types"] = avoided }
        if let meals = preferredMealTypes { updates["preferred_meal_types"] = meals }
        if let ingredients = avoidedMealIngredients { updates["avoided_meal_ingredients"] = ingredients }
        
        guard !updates.isEmpty else { return }
        
        try await db.collection(collectionName).document(userId).setData(updates, merge: true)
    }
    
    func addPreferredExercise(_ exercise: String, userId: String) async throws {
        try await db.collection(collectionName).document(userId).setData([
            "preferred_exercise_types": FieldValue.arrayUnion([exercise])
        ], merge: true)
    }
    
    func addAvoidedExercise(_ exercise: String, userId: String) async throws {
        try await db.collection(collectionName).document(userId).setData([
            "avoided_exercise_types": FieldValue.arrayUnion([exercise])
        ], merge: true)
    }
    
    func addPreferredMealType(_ meal: String, userId: String) async throws {
        try await db.collection(collectionName).document(userId).setData([
            "preferred_meal_types": FieldValue.arrayUnion([meal])
        ], merge: true)
    }
    
    func addAvoidedIngredient(_ ingredient: String, userId: String) async throws {
        try await db.collection(collectionName).document(userId).setData([
            "avoided_meal_ingredients": FieldValue.arrayUnion([ingredient])
        ], merge: true)
    }
    
    // MARK: - Convenience Methods
    
    func getOrCreateHistoryStore(for userId: String) async throws -> PlanHistoryStore {
        if let existing = try await getHistoryStore(for: userId) {
            return existing
        }
        return try await createHistoryStore(for: userId)
    }
    
    func recordPlanCompletion(
        planId: String,
        planType: PlanHistoryType,
        preferences: String,
        completedItems: Int,
        totalItems: Int,
        userId: String
    ) async throws -> PlanHistoryEntry {
        let rate = totalItems > 0 ? Double(completedItems) / Double(totalItems) : 0
        
        let entry = PlanHistoryEntry(
            planId: planId,
            planType: planType,
            preferences: preferences,
            completionRate: rate,
            completedItems: completedItems,
            totalItems: totalItems
        )
        
        try await addEntry(entry, userId: userId)
        return entry
    }
}

// MARK: - Errors

enum PlanHistoryServiceError: LocalizedError {
    case storeNotFound
    case entryNotFound
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .storeNotFound:
            return "Plan history store not found."
        case .entryNotFound:
            return "Plan history entry not found."
        case .saveFailed:
            return "Failed to save plan history."
        }
    }
}

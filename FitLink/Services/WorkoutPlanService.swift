import Foundation
import FirebaseFirestore

class WorkoutPlanService {
    
    static let shared = WorkoutPlanService()
    
    private let db = Firestore.firestore()
    private let collectionName = "workout_plans"
    
    private init() {}
    
    func saveSinglePlan(_ doc: WorkoutPlanDocument) async throws {
        let docRef = db.collection(collectionName).document(doc.id)
        let data = doc.toDictionary()
        try await docRef.setData(data)
    }
    
    func loadLatestPlan(for planType: WorkoutPlanType, userId: String) async throws -> WorkoutPlanDocument? {
        let snapshot = try await db.collection(collectionName)
            .whereField("user_id", isEqualTo: userId)
            .whereField("plan_type", isEqualTo: planType.rawValue)
            .whereField("is_archived", isEqualTo: false)
            .order(by: "created_at", descending: true)
            .limit(to: 1)
            .getDocuments()
        
        guard let doc = snapshot.documents.first else { return nil }
        return WorkoutPlanDocument.fromDictionary(doc.data(), id: doc.documentID)
    }
    
    func loadCurrentWeekPlan(for planType: WorkoutPlanType, userId: String) async throws -> WorkoutPlanDocument? {
        let now = Date()
        let snapshot = try await db.collection(collectionName)
            .whereField("user_id", isEqualTo: userId)
            .whereField("plan_type", isEqualTo: planType.rawValue)
            .whereField("is_archived", isEqualTo: false)
            .whereField("week_start_date", isLessThanOrEqualTo: Timestamp(date: now))
            .whereField("week_end_date", isGreaterThanOrEqualTo: Timestamp(date: now))
            .limit(to: 1)
            .getDocuments()
        
        guard let doc = snapshot.documents.first else { return nil }
        return WorkoutPlanDocument.fromDictionary(doc.data(), id: doc.documentID)
    }
    
    func loadAllPlansForUser(userId: String) async throws -> [WorkoutPlanDocument] {
        let snapshot = try await db.collection(collectionName)
            .whereField("user_id", isEqualTo: userId)
            .order(by: "created_at", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            WorkoutPlanDocument.fromDictionary(doc.data(), id: doc.documentID)
        }
    }
    
    func loadAllPlansForUser(userId: String, planType: WorkoutPlanType) async throws -> [WorkoutPlanDocument] {
        let snapshot = try await db.collection(collectionName)
            .whereField("user_id", isEqualTo: userId)
            .whereField("plan_type", isEqualTo: planType.rawValue)
            .order(by: "created_at", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            WorkoutPlanDocument.fromDictionary(doc.data(), id: doc.documentID)
        }
    }
    
    func loadActivePlansForUser(userId: String) async throws -> [WorkoutPlanDocument] {
        let snapshot = try await db.collection(collectionName)
            .whereField("user_id", isEqualTo: userId)
            .whereField("is_archived", isEqualTo: false)
            .order(by: "created_at", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            WorkoutPlanDocument.fromDictionary(doc.data(), id: doc.documentID)
        }
    }
    
    func loadPlan(byId planId: String) async throws -> WorkoutPlanDocument? {
        let doc = try await db.collection(collectionName).document(planId).getDocument()
        guard let data = doc.data() else { return nil }
        return WorkoutPlanDocument.fromDictionary(data, id: doc.documentID)
    }
    
    func deletePlan(_ doc: WorkoutPlanDocument) async throws {
        try await db.collection(collectionName).document(doc.id).delete()
    }
    
    func deletePlan(byId planId: String) async throws {
        try await db.collection(collectionName).document(planId).delete()
    }
    
    func updatePlan(_ doc: WorkoutPlanDocument) async throws {
        var updatedDoc = doc
        updatedDoc.lastUpdated = Date()
        try await saveSinglePlan(updatedDoc)
    }
    
    func archivePlan(_ doc: WorkoutPlanDocument) async throws {
        let docRef = db.collection(collectionName).document(doc.id)
        try await docRef.updateData([
            "is_archived": true,
            "archived_at": Timestamp(date: Date()),
            "last_updated": Timestamp(date: Date())
        ])
    }
    
    func unarchivePlan(_ doc: WorkoutPlanDocument) async throws {
        let docRef = db.collection(collectionName).document(doc.id)
        try await docRef.updateData([
            "is_archived": false,
            "archived_at": FieldValue.delete(),
            "last_updated": Timestamp(date: Date())
        ])
    }
    
    func archiveOldPlans(userId: String) async throws -> Int {
        let now = Date()
        let snapshot = try await db.collection(collectionName)
            .whereField("user_id", isEqualTo: userId)
            .whereField("is_archived", isEqualTo: false)
            .whereField("week_end_date", isLessThan: Timestamp(date: now))
            .getDocuments()
        
        var archivedCount = 0
        for doc in snapshot.documents {
            try await doc.reference.updateData([
                "is_archived": true,
                "archived_at": Timestamp(date: now),
                "last_updated": Timestamp(date: now)
            ])
            archivedCount += 1
        }
        
        return archivedCount
    }
    
    func createPendingPlan(userId: String, planType: WorkoutPlanType, preferences: String) async throws -> WorkoutPlanDocument {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? today
        
        let doc = WorkoutPlanDocument(
            userId: userId,
            planType: planType,
            preferences: preferences,
            weekStartDate: weekStart,
            weekEndDate: weekEnd
        )
        
        try await saveSinglePlan(doc)
        return doc
    }
}

enum WorkoutPlanServiceError: LocalizedError {
    case planNotFound
    case invalidData
    case encodingFailed
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .planNotFound:
            return "Workout plan not found."
        case .invalidData:
            return "Invalid plan data."
        case .encodingFailed:
            return "Failed to encode workout plan data."
        case .decodingFailed:
            return "Failed to decode workout plan data."
        }
    }
}

extension WorkoutPlanService: WorkoutPlanServiceProtocol {}

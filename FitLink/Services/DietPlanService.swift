import Foundation
import FirebaseFirestore

class DietPlanService {
    
    static let shared = DietPlanService()
    
    private let db = Firestore.firestore()
    private let collectionName = "diet_plans"
    
    private init() {}
    
    func saveDietPlan(_ plan: DietPlan) async throws {
        let docRef = db.collection(collectionName).document(plan.id)
        let data = plan.toDictionary()
        try await docRef.setData(data)
    }
    
    func loadAllPlansForUser(userId: String) async throws -> [DietPlan] {
        let snapshot = try await db.collection(collectionName)
            .whereField("user_id", isEqualTo: userId)
            .order(by: "created_at", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            DietPlan.fromDictionary(doc.data(), id: doc.documentID)
        }
    }
    
    func loadActivePlansForUser(userId: String) async throws -> [DietPlan] {
        let snapshot = try await db.collection(collectionName)
            .whereField("user_id", isEqualTo: userId)
            .whereField("is_archived", isEqualTo: false)
            .order(by: "created_at", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            DietPlan.fromDictionary(doc.data(), id: doc.documentID)
        }
    }
    
    func loadArchivedPlansForUser(userId: String) async throws -> [DietPlan] {
        let snapshot = try await db.collection(collectionName)
            .whereField("user_id", isEqualTo: userId)
            .whereField("is_archived", isEqualTo: true)
            .order(by: "archived_at", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            DietPlan.fromDictionary(doc.data(), id: doc.documentID)
        }
    }
    
    func loadPlan(byId planId: String) async throws -> DietPlan? {
        let doc = try await db.collection(collectionName).document(planId).getDocument()
        guard let data = doc.data() else { return nil }
        return DietPlan.fromDictionary(data, id: doc.documentID)
    }
    
    func loadCurrentWeekPlan(userId: String) async throws -> DietPlan? {
        let now = Date()
        let snapshot = try await db.collection(collectionName)
            .whereField("user_id", isEqualTo: userId)
            .whereField("is_archived", isEqualTo: false)
            .whereField("week_start_date", isLessThanOrEqualTo: Timestamp(date: now))
            .whereField("week_end_date", isGreaterThanOrEqualTo: Timestamp(date: now))
            .limit(to: 1)
            .getDocuments()
        
        guard let doc = snapshot.documents.first else { return nil }
        return DietPlan.fromDictionary(doc.data(), id: doc.documentID)
    }
    
    func deletePlan(_ plan: DietPlan) async throws {
        try await db.collection(collectionName).document(plan.id).delete()
    }
    
    func deletePlan(byId planId: String) async throws {
        try await db.collection(collectionName).document(planId).delete()
    }
    
    func updatePlan(_ plan: DietPlan) async throws {
        plan.lastUpdated = Date()
        try await saveDietPlan(plan)
    }
    
    func archivePlan(_ plan: DietPlan) async throws {
        let docRef = db.collection(collectionName).document(plan.id)
        try await docRef.updateData([
            "is_archived": true,
            "archived_at": Timestamp(date: Date()),
            "last_updated": Timestamp(date: Date())
        ])
    }
    
    func unarchivePlan(_ plan: DietPlan) async throws {
        let docRef = db.collection(collectionName).document(plan.id)
        try await docRef.updateData([
            "is_archived": false,
            "archived_at": FieldValue.delete(),
            "last_updated": Timestamp(date: Date())
        ])
    }
    
    func markMealDone(planId: String, dayNumber: Int, mealId: UUID, isDone: Bool) async throws {
        let docRef = db.collection(collectionName).document(planId)
        let mealPath = "daily_plans.day_\(dayNumber).meals.\(mealId.uuidString).is_done"
        
        try await docRef.updateData([
            mealPath: isDone,
            "last_updated": Timestamp(date: Date())
        ])
    }
    
    @available(*, deprecated, message: "Use markMealDone(planId:dayNumber:mealId:isDone:) for atomic updates")
    func markMealDoneLegacy(planId: String, dailyPlanIndex: Int, mealId: UUID, isDone: Bool) async throws {
        guard let plan = try await loadPlan(byId: planId) else {
            throw DietPlanServiceError.planNotFound
        }
        
        guard dailyPlanIndex < plan.dailyPlans.count else {
            throw DietPlanServiceError.invalidDayIndex
        }
        
        var dailyPlans = plan.dailyPlans
        let dailyPlan = dailyPlans[dailyPlanIndex]
        
        guard let mealIndex = dailyPlan.meals.firstIndex(where: { $0.id == mealId }) else {
            throw DietPlanServiceError.mealNotFound
        }
        
        dailyPlans[dailyPlanIndex].meals[mealIndex].isDone = isDone
        plan.dailyPlans = dailyPlans
        
        try await updatePlan(plan)
    }
    
    func updateGenerationStatus(planId: String, status: GenerationStatus, progress: Double) async throws {
        let docRef = db.collection(collectionName).document(planId)
        try await docRef.updateData([
            "generation_status": status.rawValue,
            "generation_progress": progress,
            "last_updated": Timestamp(date: Date())
        ])
    }
    
    func sharePlan(_ plan: DietPlan, withUserIds userIds: [String]) async throws -> String {
        let shareId = UUID().uuidString
        let docRef = db.collection(collectionName).document(plan.id)
        try await docRef.updateData([
            "is_shared": true,
            "shared_with": userIds,
            "share_id": shareId,
            "last_updated": Timestamp(date: Date())
        ])
        return shareId
    }
    
    func unsharePlan(_ plan: DietPlan) async throws {
        let docRef = db.collection(collectionName).document(plan.id)
        try await docRef.updateData([
            "is_shared": false,
            "shared_with": [],
            "share_id": FieldValue.delete(),
            "last_updated": Timestamp(date: Date())
        ])
    }
    
    func loadSharedPlan(shareId: String) async throws -> DietPlan? {
        let snapshot = try await db.collection(collectionName)
            .whereField("share_id", isEqualTo: shareId)
            .whereField("is_shared", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()
        
        guard let doc = snapshot.documents.first else { return nil }
        return DietPlan.fromDictionary(doc.data(), id: doc.documentID)
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
    
    func createPendingPlan(userId: String, preferences: String) async throws -> DietPlan {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? today
        
        let plan = DietPlan(
            userId: userId,
            preferences: preferences,
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            generationStatus: .pending
        )
        
        try await saveDietPlan(plan)
        return plan
    }
    
    func getMealStatus(planId: String, dayNumber: Int, mealId: UUID) async throws -> Bool? {
        let docRef = db.collection(collectionName).document(planId)
        let doc = try await docRef.getDocument()
        
        guard let data = doc.data(),
              let dailyPlans = data["daily_plans"] as? [String: [String: Any]],
              let dayData = dailyPlans["day_\(dayNumber)"],
              let meals = dayData["meals"] as? [String: [String: Any]],
              let mealData = meals[mealId.uuidString] else {
            return nil
        }
        
        return mealData["is_done"] as? Bool
    }
    
    func migrateLegacyPlanToNativeFormat(planId: String) async throws {
        guard let plan = try await loadPlan(byId: planId) else {
            throw DietPlanServiceError.planNotFound
        }
        try await saveDietPlan(plan)
    }
    
    func batchMigrateLegacyPlans(userId: String) async throws -> Int {
        let plans = try await loadAllPlansForUser(userId: userId)
        var migratedCount = 0
        
        for plan in plans {
            try await saveDietPlan(plan)
            migratedCount += 1
        }
        
        return migratedCount
    }
}

enum DietPlanServiceError: LocalizedError {
    case planNotFound
    case invalidDayIndex
    case mealNotFound
    case encodingFailed
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .planNotFound:
            return "Diet plan not found."
        case .invalidDayIndex:
            return "Invalid day index."
        case .mealNotFound:
            return "Meal not found."
        case .encodingFailed:
            return "Failed to encode diet plan data."
        case .decodingFailed:
            return "Failed to decode diet plan data."
        }
    }
}

extension DietPlanService: DietPlanServiceProtocol {}

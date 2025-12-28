import Foundation
import SwiftUI
import Combine

// MARK: - Service Protocols

protocol FriendServiceProtocol: AnyObject {
    func sendFriendRequest(from senderId: String, to recipientId: String) async throws
    func acceptFriendRequest(_ requestId: String) async throws
    func declineFriendRequest(_ requestId: String) async throws
    func cancelFriendRequest(_ requestId: String) async throws
    func removeFriend(userId: String, friendId: String) async throws
    func getPendingFriendRequests(for userId: String) async throws -> [FriendRequest]
    func getSentFriendRequests(for userId: String) async throws -> [FriendRequest]
    func getFriends(for userId: String) async throws -> [User]
    func getPendingRequestsCount(for userId: String) async throws -> Int
    func searchUsersByEmail(_ query: String, excluding currentUserId: String) async throws -> [User]
}

protocol DietPlanServiceProtocol: AnyObject {
    func saveDietPlan(_ plan: DietPlan) async throws
    func loadAllPlansForUser(userId: String) async throws -> [DietPlan]
    func loadActivePlansForUser(userId: String) async throws -> [DietPlan]
    func loadArchivedPlansForUser(userId: String) async throws -> [DietPlan]
    func loadPlan(byId planId: String) async throws -> DietPlan?
    func loadCurrentWeekPlan(userId: String) async throws -> DietPlan?
    func deletePlan(_ plan: DietPlan) async throws
    func deletePlan(byId planId: String) async throws
    func updatePlan(_ plan: DietPlan) async throws
    func archivePlan(_ plan: DietPlan) async throws
    func unarchivePlan(_ plan: DietPlan) async throws
    func markMealDone(planId: String, dayNumber: Int, mealId: UUID, isDone: Bool) async throws
    func updateGenerationStatus(planId: String, status: GenerationStatus, progress: Double) async throws
    func sharePlan(_ plan: DietPlan, withUserIds userIds: [String]) async throws -> String
    func unsharePlan(_ plan: DietPlan) async throws
    func loadSharedPlan(shareId: String) async throws -> DietPlan?
    func archiveOldPlans(userId: String) async throws -> Int
    func createPendingPlan(userId: String, preferences: String) async throws -> DietPlan
}

protocol WorkoutPlanServiceProtocol: AnyObject {
    func saveSinglePlan(_ doc: WorkoutPlanDocument) async throws
    func loadLatestPlan(for planType: WorkoutPlanType, userId: String) async throws -> WorkoutPlanDocument?
    func loadCurrentWeekPlan(for planType: WorkoutPlanType, userId: String) async throws -> WorkoutPlanDocument?
    func loadAllPlansForUser(userId: String) async throws -> [WorkoutPlanDocument]
    func loadAllPlansForUser(userId: String, planType: WorkoutPlanType) async throws -> [WorkoutPlanDocument]
    func loadActivePlansForUser(userId: String) async throws -> [WorkoutPlanDocument]
    func loadPlan(byId planId: String) async throws -> WorkoutPlanDocument?
    func deletePlan(_ doc: WorkoutPlanDocument) async throws
    func deletePlan(byId planId: String) async throws
    func updatePlan(_ doc: WorkoutPlanDocument) async throws
    func archivePlan(_ doc: WorkoutPlanDocument) async throws
    func unarchivePlan(_ doc: WorkoutPlanDocument) async throws
    func archiveOldPlans(userId: String) async throws -> Int
    func createPendingPlan(userId: String, planType: WorkoutPlanType, preferences: String) async throws -> WorkoutPlanDocument
}

// MARK: - AppEnvironment

@MainActor
final class AppEnvironment: ObservableObject {
    
    let objectWillChange = ObservableObjectPublisher()
    
    private let _friendService: FriendService
    private let _dietPlanService: DietPlanService
    private let _workoutPlanService: WorkoutPlanService
    let sessionManager: SessionManager
    
    var friendService: FriendService { _friendService }
    var dietPlanService: DietPlanService { _dietPlanService }
    var workoutPlanService: WorkoutPlanService { _workoutPlanService }
    
    init() {
        self._friendService = FriendService.shared
        self._dietPlanService = DietPlanService.shared
        self._workoutPlanService = WorkoutPlanService.shared
        self.sessionManager = SessionManager.shared
    }
    
    init(
        friendService: FriendService,
        dietPlanService: DietPlanService,
        workoutPlanService: WorkoutPlanService,
        sessionManager: SessionManager
    ) {
        self._friendService = friendService
        self._dietPlanService = dietPlanService
        self._workoutPlanService = workoutPlanService
        self.sessionManager = sessionManager
    }
    
    var currentUserId: String? { sessionManager.currentUserID }
    var isAuthenticated: Bool { sessionManager.isAuthenticated }
}

// MARK: - SwiftUI Environment Integration

private struct AppEnvironmentKey: EnvironmentKey {
    @MainActor static let defaultValue: AppEnvironment = AppEnvironment()
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}

extension View {
    func withAppEnvironment(_ environment: AppEnvironment) -> some View {
        self.environment(\.appEnvironment, environment)
            .environmentObject(environment.sessionManager)
    }
}

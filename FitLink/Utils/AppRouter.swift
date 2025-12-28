import Foundation
import SwiftUI
import Combine

/// Handles deep link routing for the FitLink app
/// URL scheme: fitlink://
final class AppRouter: ObservableObject {
    
    static let shared = AppRouter()
    
    @Published var pendingRoute: AppRoute?
    @Published var hasNavigationPending = false
    
    /// Route stored when prerequisites (auth/onboarding) are not met
    @Published private(set) var deferredRoute: AppRoute?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .navigateToPlan)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.handlePlanNavigationNotification(notification)
            }
            .store(in: &cancellables)
    }
    
    private func handlePlanNavigationNotification(_ notification: Notification) {
        guard let planTypeRaw = notification.userInfo?["planType"] as? String else { return }
        
        if planTypeRaw == "diet" {
            pendingRoute = .dietPlanner
        } else if planTypeRaw == "workoutHome" || planTypeRaw == "workoutGym" {
            pendingRoute = .workouts
        }
        
        if pendingRoute != nil {
            hasNavigationPending = true
        }
    }
    
    // MARK: - Route Definition
    
    /// Represents all possible deep link destinations in the app
    enum AppRoute: Equatable, Hashable {
        /// Home dashboard
        case dashboard
        
        /// Habit tracker with optional specific date
        case habitTracker(date: Date?)
        
        /// Focus session for a specific habit
        case focusSession(habitId: String)
        
        /// Resume current active focus session (no habitId required)
        case currentFocusSession
        
        /// Diet planner main view
        case dietPlanner
        
        /// Specific diet plan by ID
        case dietPlan(planId: String)
        
        /// Recipe detail by ID
        case recipe(recipeId: String)
        
        /// Workouts main view
        case workouts
        
        /// Specific workout plan
        case workoutPlan(planId: String, type: WorkoutType)
        
        /// Activity summary from HealthKit
        case activitySummary
        
        /// Friends list
        case friends
        
        /// User profile
        case profile
        
        /// Settings
        case settings
        
        /// Workout type for routing
        enum WorkoutType: String {
            case home
            case gym
        }
    }
    
    // MARK: - URL Parsing
    
    /// Parse a deep link URL into an AppRoute
    /// - Parameter url: The URL to parse
    /// - Returns: An AppRoute if the URL is valid, nil otherwise
    func parseURL(_ url: URL) -> AppRoute? {
        guard url.scheme == "fitlink" else { return nil }
        
        let host = url.host ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        
        switch host {
        case "dashboard", "home":
            return .dashboard
            
        case "habits", "habittracker":
            if let dateString = queryItems.first(where: { $0.name == "date" })?.value,
               let date = parseDate(dateString) {
                return .habitTracker(date: date)
            }
            return .habitTracker(date: nil)
            
        case "focus":
            if let habitId = pathComponents.first ?? queryItems.first(where: { $0.name == "habitId" })?.value {
                return .focusSession(habitId: habitId)
            }
            return .currentFocusSession
            
        case "diet", "dietplanner":
            if let planId = pathComponents.first ?? queryItems.first(where: { $0.name == "planId" })?.value {
                return .dietPlan(planId: planId)
            }
            return .dietPlanner
            
        case "recipe":
            guard let recipeId = pathComponents.first ?? queryItems.first(where: { $0.name == "id" })?.value else {
                return nil
            }
            return .recipe(recipeId: recipeId)
            
        case "workouts", "workout":
            if let planId = pathComponents.first ?? queryItems.first(where: { $0.name == "planId" })?.value {
                let typeString = queryItems.first(where: { $0.name == "type" })?.value ?? "home"
                let type = AppRoute.WorkoutType(rawValue: typeString) ?? .home
                return .workoutPlan(planId: planId, type: type)
            }
            return .workouts
            
        case "activity", "health":
            return .activitySummary
            
        case "friends", "social":
            return .friends
            
        case "profile":
            return .profile
            
        case "settings":
            return .settings
            
        default:
            return nil
        }
    }
    
    // MARK: - Handle URL
    
    /// Handle an incoming deep link URL
    /// - Parameter url: The URL to handle
    /// - Returns: Whether the URL was successfully handled
    @discardableResult
    func handleURL(_ url: URL) -> Bool {
        guard let route = parseURL(url) else {
            AppLogger.shared.warning("Unable to parse URL", category: .navigation)
            return false
        }
        
        AppLogger.shared.debug("Navigating to route: \(route)", category: .navigation)
        
        DispatchQueue.main.async {
            self.pendingRoute = route
            self.hasNavigationPending = true
        }
        
        return true
    }
    
    /// Clear the pending route after navigation is complete
    func clearPendingRoute() {
        pendingRoute = nil
        hasNavigationPending = false
    }
    
    // MARK: - Deferred Route Gating
    
    func handleURLWithGating(_ url: URL, isAuthenticated: Bool, hasCompletedOnboarding: Bool) -> Bool {
        guard let route = parseURL(url) else {
            AppLogger.shared.warning("Unable to parse URL: \(url.absoluteString)", category: .navigation)
            return false
        }
        
        return applyRouteWithGating(route, isAuthenticated: isAuthenticated, hasCompletedOnboarding: hasCompletedOnboarding)
    }
    
    func applyRouteWithGating(_ route: AppRoute, isAuthenticated: Bool, hasCompletedOnboarding: Bool) -> Bool {
        if !isAuthenticated || !hasCompletedOnboarding {
            AppLogger.shared.debug("Deferring route until prerequisites met: \(route)", category: .navigation)
            deferredRoute = route
            return true
        }
        
        DispatchQueue.main.async {
            self.pendingRoute = route
            self.hasNavigationPending = true
        }
        return true
    }
    
    func applyDeferredRouteIfReady(isAuthenticated: Bool, hasCompletedOnboarding: Bool) {
        guard isAuthenticated, hasCompletedOnboarding else { return }
        guard let route = deferredRoute else { return }
        
        AppLogger.shared.debug("Applying deferred route: \(route)", category: .navigation)
        deferredRoute = nil
        
        DispatchQueue.main.async {
            self.pendingRoute = route
            self.hasNavigationPending = true
        }
    }
    
    func clearDeferredRoute() {
        deferredRoute = nil
    }
    
    // MARK: - URL Generation
    
    /// Generate a deep link URL for a given route
    /// - Parameter route: The route to generate a URL for
    /// - Returns: The deep link URL
    func generateURL(for route: AppRoute) -> URL? {
        var components = URLComponents()
        components.scheme = "fitlink"
        
        switch route {
        case .dashboard:
            components.host = "dashboard"
            
        case .habitTracker(let date):
            components.host = "habits"
            if let date = date {
                components.queryItems = [URLQueryItem(name: "date", value: formatDate(date))]
            }
            
        case .focusSession(let habitId):
            components.host = "focus"
            components.path = "/\(habitId)"
            
        case .currentFocusSession:
            components.host = "focus"
            
        case .dietPlanner:
            components.host = "diet"
            
        case .dietPlan(let planId):
            components.host = "diet"
            components.path = "/\(planId)"
            
        case .recipe(let recipeId):
            components.host = "recipe"
            components.path = "/\(recipeId)"
            
        case .workouts:
            components.host = "workouts"
            
        case .workoutPlan(let planId, let type):
            components.host = "workout"
            components.path = "/\(planId)"
            components.queryItems = [URLQueryItem(name: "type", value: type.rawValue)]
            
        case .activitySummary:
            components.host = "activity"
            
        case .friends:
            components.host = "friends"
            
        case .profile:
            components.host = "profile"
            
        case .settings:
            components.host = "settings"
        }
        
        return components.url
    }
    
    // MARK: - Private Helpers
    
    private func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: string)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
}

// MARK: - View Extension for Navigation

extension View {
    /// Apply pending route navigation from AppRouter
    func handleDeepLinkNavigation() -> some View {
        self.modifier(DeepLinkNavigationModifier())
    }
}

private struct DeepLinkNavigationModifier: ViewModifier {
    @StateObject private var router = AppRouter.shared
    
    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                router.handleURL(url)
            }
    }
}

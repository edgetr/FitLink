import SwiftUI

// MARK: - Tour Step Model

struct OnboardingTourStep: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    let targetElementID: String
    let route: AppRouter.AppRoute?
    let completionRule: CompletionRule
    
    static func == (lhs: OnboardingTourStep, rhs: OnboardingTourStep) -> Bool {
        lhs.id == rhs.id
    }
    
    enum CompletionRule: Equatable {
        case tapNext
        case tapTarget
        case performAction(actionID: String)
        case autoAdvance(delay: TimeInterval)
    }
}

// MARK: - Tour Definition

struct OnboardingTour: Identifiable {
    let id: String
    let name: String
    let steps: [OnboardingTourStep]
    
    static let firstRunTour = OnboardingTour(
        id: "first_run",
        name: "Welcome Tour",
        steps: [
            OnboardingTourStep(
                id: "welcome_hero",
                title: "Welcome to FitLink",
                body: "Your personal AI-powered fitness companion. Let's take a quick tour of the main features.",
                targetElementID: "dashboard.hero",
                route: .dashboard,
                completionRule: .tapNext
            ),
            OnboardingTourStep(
                id: "quick_stats",
                title: "Your Daily Stats",
                body: "Track your calories, steps, sleep, and more at a glance. Tap any stat for detailed insights.",
                targetElementID: "dashboard.quickStats",
                route: .dashboard,
                completionRule: .tapNext
            ),
            OnboardingTourStep(
                id: "ai_workouts",
                title: "AI Workouts",
                body: "Get personalized workout plans tailored to your fitness level and goals. Tap to explore.",
                targetElementID: "dashboard.aiWorkouts",
                route: .dashboard,
                completionRule: .tapTarget
            ),
            OnboardingTourStep(
                id: "ai_diet",
                title: "AI Diet Planner",
                body: "Receive AI-curated meal plans based on your dietary preferences and nutritional needs.",
                targetElementID: "dashboard.aiDiet",
                route: .dashboard,
                completionRule: .tapNext
            ),
            OnboardingTourStep(
                id: "habits",
                title: "Habit Tracker",
                body: "Build healthy habits with focus timers and streak tracking. Consistency is key!",
                targetElementID: "dashboard.habits",
                route: .dashboard,
                completionRule: .tapNext
            ),
            OnboardingTourStep(
                id: "settings",
                title: "Settings & Privacy",
                body: "Manage your preferences, privacy controls, and personalization settings here.",
                targetElementID: "dashboard.profile",
                route: .dashboard,
                completionRule: .tapNext
            )
        ]
    )
}

// MARK: - Spotlight Preference Key

struct OnboardingTargetKey: PreferenceKey {
    typealias Value = [String: Anchor<CGRect>]
    
    static var defaultValue: Value = [:]
    
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - View Modifier for Target Registration

extension View {
    func onboardingTarget(_ id: String) -> some View {
        self.anchorPreference(key: OnboardingTargetKey.self, value: .bounds) { anchor in
            [id: anchor]
        }
    }
}

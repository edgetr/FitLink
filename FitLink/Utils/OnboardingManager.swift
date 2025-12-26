import Foundation
import Combine
import HealthKit
import CoreLocation

@MainActor
final class OnboardingManager: ObservableObject {
    
    static let shared = OnboardingManager()
    
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: hasCompletedOnboardingKey)
        }
    }
    
    private init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
}

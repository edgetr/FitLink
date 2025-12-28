import Foundation
import Combine

@MainActor
final class OnboardingManager: ObservableObject {
    
    static let shared = OnboardingManager()
    
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    private let completedToursKey = "completedTours"
    private let lastSeenStepByTourKey = "lastSeenStepByTour"
    
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: hasCompletedOnboardingKey)
        }
    }
    
    @Published private(set) var completedTours: Set<String> {
        didSet {
            let array = Array(completedTours)
            UserDefaults.standard.set(array, forKey: completedToursKey)
        }
    }
    
    private var lastSeenStepByTour: [String: Int] {
        didSet {
            UserDefaults.standard.set(lastSeenStepByTour, forKey: lastSeenStepByTourKey)
        }
    }
    
    private init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
        
        let toursArray = UserDefaults.standard.stringArray(forKey: completedToursKey) ?? []
        self.completedTours = Set(toursArray)
        
        self.lastSeenStepByTour = UserDefaults.standard.dictionary(forKey: lastSeenStepByTourKey) as? [String: Int] ?? [:]
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
    
    // MARK: - Tour Management
    
    func hasCompletedTour(_ tourId: String) -> Bool {
        completedTours.contains(tourId)
    }
    
    func completeTour(_ tourId: String) {
        completedTours.insert(tourId)
        lastSeenStepByTour.removeValue(forKey: tourId)
    }
    
    func resetTour(_ tourId: String) {
        completedTours.remove(tourId)
        lastSeenStepByTour.removeValue(forKey: tourId)
    }
    
    func resetAllTours() {
        completedTours.removeAll()
        lastSeenStepByTour.removeAll()
    }
    
    func saveLastSeenStep(tourId: String, stepIndex: Int) {
        lastSeenStepByTour[tourId] = stepIndex
    }
    
    func lastSeenStep(for tourId: String) -> Int {
        lastSeenStepByTour[tourId] ?? 0
    }
}

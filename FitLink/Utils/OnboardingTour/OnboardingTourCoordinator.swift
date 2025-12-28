import SwiftUI
import Combine

@MainActor
final class OnboardingTourCoordinator: ObservableObject {
    
    static let shared = OnboardingTourCoordinator()
    
    @Published private(set) var activeTour: OnboardingTour?
    @Published private(set) var currentStepIndex: Int = 0
    @Published private(set) var isShowingTour: Bool = false
    @Published var scrollToElementID: String?
    
    private let onboardingManager = OnboardingManager.shared
    private let router = AppRouter.shared
    
    var currentStep: OnboardingTourStep? {
        guard let tour = activeTour,
              currentStepIndex >= 0,
              currentStepIndex < tour.steps.count else { return nil }
        return tour.steps[currentStepIndex]
    }
    
    var hasNextStep: Bool {
        guard let tour = activeTour else { return false }
        return currentStepIndex < tour.steps.count - 1
    }
    
    var hasPreviousStep: Bool {
        currentStepIndex > 0
    }
    
    var progress: Double {
        guard let tour = activeTour, !tour.steps.isEmpty else { return 0 }
        return Double(currentStepIndex + 1) / Double(tour.steps.count)
    }
    
    private init() {}
    
    // MARK: - Tour Control
    
    func startTour(_ tour: OnboardingTour, fromStep: Int = 0) {
        activeTour = tour
        currentStepIndex = max(0, min(fromStep, tour.steps.count - 1))
        isShowingTour = true
        
        navigateToCurrentStepRouteIfNeeded()
        scrollToCurrentStepElement()
    }
    
    func startFirstRunTourIfNeeded() {
        guard !onboardingManager.hasCompletedTour("first_run") else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.startTour(.firstRunTour)
        }
    }
    
    func nextStep() {
        guard let tour = activeTour else { return }
        
        if currentStepIndex < tour.steps.count - 1 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                currentStepIndex += 1
            }
            onboardingManager.saveLastSeenStep(tourId: tour.id, stepIndex: currentStepIndex)
            navigateToCurrentStepRouteIfNeeded()
            scrollToCurrentStepElement()
        } else {
            completeTour()
        }
    }
    
    func previousStep() {
        guard currentStepIndex > 0 else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            currentStepIndex -= 1
        }
        
        if let tour = activeTour {
            onboardingManager.saveLastSeenStep(tourId: tour.id, stepIndex: currentStepIndex)
        }
        navigateToCurrentStepRouteIfNeeded()
        scrollToCurrentStepElement()
    }
    
    func skipTour() {
        if let tour = activeTour {
            onboardingManager.completeTour(tour.id)
        }
        endTour()
    }
    
    func completeTour() {
        if let tour = activeTour {
            onboardingManager.completeTour(tour.id)
        }
        endTour()
    }
    
    func resumeTourIfNeeded(_ tourId: String) {
        guard !onboardingManager.hasCompletedTour(tourId) else { return }
        
        let lastStep = onboardingManager.lastSeenStep(for: tourId)
        
        if tourId == OnboardingTour.firstRunTour.id {
            startTour(.firstRunTour, fromStep: lastStep)
        }
    }
    
    // MARK: - Completion Handling
    
    func handleTargetTapped(_ targetID: String) {
        guard let step = currentStep,
              step.targetElementID == targetID,
              step.completionRule == .tapTarget else { return }
        
        nextStep()
    }
    
    func handleActionCompleted(_ actionID: String) {
        guard let step = currentStep,
              case .performAction(let expectedActionID) = step.completionRule,
              actionID == expectedActionID else { return }
        
        nextStep()
    }
    
    // MARK: - Private
    
    private func endTour() {
        isShowingTour = false
        activeTour = nil
        currentStepIndex = 0
    }
    
    private func navigateToCurrentStepRouteIfNeeded() {
        guard let step = currentStep,
              let route = step.route else { return }
        
        if route == .dashboard {
            return
        }
        
        if router.pendingRoute != route {
            router.pendingRoute = route
            router.hasNavigationPending = true
        }
    }
    
    private func scrollToCurrentStepElement() {
        guard let step = currentStep else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.scrollToElementID = step.targetElementID
        }
    }
}

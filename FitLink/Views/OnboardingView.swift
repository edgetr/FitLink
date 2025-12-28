import SwiftUI
import UIKit

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @StateObject private var permissionCoordinator = PermissionCoordinator.shared
    @State private var currentStep = 0
    
    private var healthAuthorized: Bool {
        permissionCoordinator.isHealthAuthorized
    }
    
    private var locationAuthorized: Bool {
        permissionCoordinator.isLocationAuthorized
    }
    
    private var notificationsAuthorized: Bool {
        permissionCoordinator.isNotificationAuthorized
    }
    
    private var steps: [OnboardingStep] {
        [
            OnboardingStep(
                icon: "heart.fill",
                iconGradient: [.pink, .red],
                title: "Welcome to FitLink",
                subtitle: "Your personal fitness companion",
                description: "Track workouts, plan meals, build habits, and achieve your health goals.",
                buttonText: "Get Started",
                action: { nextStep() }
            ),
            OnboardingStep(
                icon: "figure.run",
                iconGradient: [.blue, .purple],
                title: "AI-Powered Workouts",
                subtitle: "Personalized just for you",
                description: "Get custom workout plans tailored to your fitness level, goals, and available equipment.",
                buttonText: "Next",
                action: { nextStep() }
            ),
            OnboardingStep(
                icon: "fork.knife",
                iconGradient: [.green, .teal],
                title: "Smart Diet Planning",
                subtitle: "Eat better, feel better",
                description: "AI-curated meal plans based on your dietary preferences and nutritional needs.",
                buttonText: "Next",
                action: { nextStep() }
            ),
            OnboardingStep(
                icon: "heart.text.square.fill",
                iconGradient: [.red, .orange],
                title: "Health Tracking",
                subtitle: "Connect with Apple Health",
                description: "Sync your steps, calories, and activity data for a complete picture of your health.",
                buttonText: healthAuthorized ? "Authorized ✓" : "Allow Health Access",
                action: { requestHealthKitPermission() },
                isPermissionStep: true,
                isAuthorized: healthAuthorized,
                isDenied: permissionCoordinator.healthStatus == .denied
            ),
            OnboardingStep(
                icon: "location.fill",
                iconGradient: [.blue, .cyan],
                title: "Location Services",
                subtitle: "Find nearby gyms & trails",
                description: "Enable location to discover fitness spots near you and track outdoor activities.",
                buttonText: locationAuthorized ? "Authorized ✓" : "Allow Location",
                action: { requestLocationPermission() },
                isPermissionStep: true,
                isAuthorized: locationAuthorized,
                isDenied: permissionCoordinator.locationStatus == .denied || permissionCoordinator.locationStatus == .restricted
            ),
            OnboardingStep(
                icon: "bell.badge.fill",
                iconGradient: [.orange, .yellow],
                title: "Stay on Track",
                subtitle: "Helpful reminders",
                description: "Get notified about your workouts, meals, and habit streaks.",
                buttonText: notificationsAuthorized ? "Authorized ✓" : "Allow Notifications",
                action: { requestNotificationPermission() },
                isPermissionStep: true,
                isAuthorized: notificationsAuthorized,
                isDenied: permissionCoordinator.notificationStatus == .denied
            ),
            OnboardingStep(
                icon: "checkmark.circle.fill",
                iconGradient: [.green, .mint],
                title: "You're All Set!",
                subtitle: "Let's start your journey",
                description: "Everything is ready. Time to crush your fitness goals!",
                buttonText: "Start Using FitLink",
                action: { completeOnboarding() }
            )
        ]
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                skipButton
                
                Spacer()
                
                stepContent
                
                Spacer()
                
                progressIndicator
                    .padding(.bottom, 40)
            }
        }
        .interactiveDismissDisabled()
        .task {
            await permissionCoordinator.refreshAllStatuses()
        }
    }
    
    private var skipButton: some View {
        HStack {
            Spacer()
            if currentStep < steps.count - 1 {
                Button("Skip") {
                    completeOnboarding()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding()
            }
        }
    }
    
    private var stepContent: some View {
        let step = steps[currentStep]
        
        return VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: step.iconGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: step.iconGradient.first?.opacity(0.4) ?? .clear, radius: 20, x: 0, y: 10)
                
                Image(systemName: step.icon)
                    .font(.system(size: 50))
                    .foregroundStyle(.white)
            }
            .scaleEffect(1.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentStep)
            
            VStack(spacing: 12) {
                Text(step.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(step.subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Text(step.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(spacing: 16) {
                Button {
                    step.action()
                } label: {
                    Text(step.buttonText)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: step.isAuthorized ? [.green, .mint] : step.iconGradient,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 40)
                .disabled(step.isPermissionStep && step.isAuthorized)
                
                if step.isPermissionStep && step.isDenied {
                    Button("Open Settings") {
                        permissionCoordinator.openAppSettings()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                }
                
                if step.isPermissionStep && !step.isAuthorized && !step.isDenied {
                    Button("Skip for now") {
                        nextStep()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                
                if step.isPermissionStep && step.isAuthorized {
                    Button("Continue") {
                        nextStep()
                    }
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .padding(.top, 8)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<steps.count, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? Color.blue : Color(UIColor.tertiarySystemFill))
                    .frame(width: index == currentStep ? 10 : 8, height: index == currentStep ? 10 : 8)
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
            }
        }
    }
    
    private func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentStep < steps.count - 1 {
                currentStep += 1
            }
        }
    }
    
    private func requestHealthKitPermission() {
        Task {
            let success = await permissionCoordinator.requestHealth()
            if success {
                try? await Task.sleep(nanoseconds: 500_000_000)
                nextStep()
            }
        }
    }
    
    private func requestLocationPermission() {
        Task {
            let success = await permissionCoordinator.requestLocation()
            if success {
                try? await Task.sleep(nanoseconds: 500_000_000)
                nextStep()
            }
        }
    }
    
    private func requestNotificationPermission() {
        Task {
            let success = await permissionCoordinator.requestNotifications()
            if success {
                try? await Task.sleep(nanoseconds: 500_000_000)
                nextStep()
            }
        }
    }
    
    private func completeOnboarding() {
        OnboardingManager.shared.completeOnboarding()
        isPresented = false
    }
}

struct OnboardingStep {
    let icon: String
    let iconGradient: [Color]
    let title: String
    let subtitle: String
    let description: String
    let buttonText: String
    let action: () -> Void
    var isPermissionStep: Bool = false
    var isAuthorized: Bool = false
    var isDenied: Bool = false
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}

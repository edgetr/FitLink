import SwiftUI
import FirebaseCore
import FirebaseFirestore
import UIKit

@main
struct FitLinkApp: App {
    @StateObject private var appEnvironment = AppEnvironment()
    @AppStorage("app_preferred_color_scheme") private var preferredColorScheme: Int = 2
    @Environment(\.scenePhase) private var scenePhase
    
    private var sessionManager: SessionManager { appEnvironment.sessionManager }
    
    init() {
        configureFirebase()
        configureFirestoreCache()
        setupMemoryManagement()
        HealthSyncScheduler.shared.registerBackgroundTasks()
    }
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
                .withAppEnvironment(appEnvironment)
                .preferredColorScheme(colorSchemeFromPreference)
                .onOpenURL { url in
                    handleDeepLink(url: url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
                .onAppear {
                    checkPendingGenerations()
                }
        }
    }
    
    private var colorSchemeFromPreference: ColorScheme? {
        switch preferredColorScheme {
        case 1:
            return .light
        case 2:
            return .dark
        default:
            return nil
        }
    }
    
    private func configureFirebase() {
        FirebaseApp.configure()
    }
    
    private func configureFirestoreCache() {
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: 100 * 1024 * 1024 as NSNumber)
        Firestore.firestore().settings = settings
    }
    
    private func setupMemoryManagement() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            handleMemoryWarning()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            clearCachesOnBackground()
        }
    }
    
    private func handleDeepLink(url: URL) {
        let handled = AppRouter.shared.handleURL(url)
        if !handled {
            AppLogger.shared.warning("Unhandled deep link: \(url.absoluteString)", category: .navigation)
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            checkPendingGenerations()
            performHealthSyncIfNeeded()
            Task { @MainActor in
                NotificationService.shared.clearBadge()
            }
            
        case .inactive:
            break
            
        case .background:
            HealthSyncScheduler.shared.scheduleBackgroundSync()
            
        @unknown default:
            break
        }
    }
    
    private func performHealthSyncIfNeeded() {
        guard let userId = sessionManager.currentUserID else { return }
        
        if HealthSyncScheduler.shared.shouldPerformSync(userId: userId) {
            Task {
                await HealthSyncScheduler.shared.performForegroundSync(userId: userId)
            }
        }
    }
    
    private func checkPendingGenerations() {
        guard let userId = sessionManager.currentUserID else { return }
        
        Task {
            await checkAndDisplayCompletedGenerations(userId: userId)
        }
    }
    
    private func checkAndDisplayCompletedGenerations(userId: String) async {
        let planGenerationService = PlanGenerationService.shared
        
        do {
            let completedGenerations = try await planGenerationService.loadCompletedUnnotified(userId: userId)
            
            for generation in completedGenerations {
                NotificationCenter.default.post(
                    name: .planGenerationCompleted,
                    object: nil,
                    userInfo: [
                        "generationId": generation.id,
                        "planType": generation.planType.rawValue,
                        "resultPlanId": generation.resultPlanId ?? ""
                    ]
                )
                
                try await planGenerationService.markNotificationSent(generation.id)
            }
            
        } catch {
            AppLogger.shared.error("Error checking completed generations: \(error.localizedDescription)", category: .general)
        }
    }
}

private func handleMemoryWarning() {
    CacheManager.shared.clearMemoryCachesOnly()
    ImageFinderService.shared.clearMemoryCache()
    AppLogger.shared.info("Memory warning: cleared memory caches (disk cache preserved)", category: .cache)
}

private func clearCachesOnBackground() {
    CacheManager.shared.clearMemoryCachesOnly()
    AppLogger.shared.debug("App entered background: cleared memory caches (disk cache preserved)", category: .cache)
}

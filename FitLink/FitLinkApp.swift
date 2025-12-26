import SwiftUI
import FirebaseCore
import FirebaseFirestore
import UIKit

@main
struct FitLinkApp: App {
    @StateObject private var sessionManager = SessionManager.shared
    @AppStorage("app_preferred_color_scheme") private var preferredColorScheme: Int = 2
    
    init() {
        configureFirebase()
        configureFirestoreCache()
        setupMemoryManagement()
    }
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(sessionManager)
                .preferredColorScheme(colorSchemeFromPreference)
                .onOpenURL { url in
                    handleDeepLink(url: url)
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
        guard url.scheme == "fitlink" else { return }
        
        let host = url.host
        let pathComponents = url.pathComponents
        
        switch host {
        case "workout":
            print("Deep link to workout: \(pathComponents)")
        case "diet":
            print("Deep link to diet: \(pathComponents)")
        case "habit":
            print("Deep link to habit: \(pathComponents)")
        case "profile":
            print("Deep link to profile")
        default:
            print("Unknown deep link: \(url)")
        }
    }
}

private func handleMemoryWarning() {
    URLCache.shared.removeAllCachedResponses()
    print("Memory warning: cleared URL cache")
}

private func clearCachesOnBackground() {
    URLCache.shared.removeAllCachedResponses()
    print("App entered background: cleared caches")
}

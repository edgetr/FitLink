import SwiftUI

#if os(watchOS)

@main
struct FitLinkWatchApp: App {
    
    @StateObject private var sessionManager = WatchSessionManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
        }
    }
}

#endif

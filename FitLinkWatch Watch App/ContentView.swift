import SwiftUI

#if os(watchOS)

struct ContentView: View {
    
    @EnvironmentObject var sessionManager: WatchSessionManager
    
    var body: some View {
        Group {
            if sessionManager.isLoggedIn {
                mainTabView
            } else {
                WatchNotLoggedInView()
            }
        }
    }
    
    private var mainTabView: some View {
        TabView {
            HealthSummaryWatchView()
                .tag(0)
            
            HabitsWatchView()
                .tag(1)
            
            PlansWatchView()
                .tag(2)
        }
        .tabViewStyle(.verticalPage)
    }
}

#endif

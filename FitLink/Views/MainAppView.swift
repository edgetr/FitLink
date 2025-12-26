import SwiftUI

struct MainAppView: View {
    @EnvironmentObject var sessionManager: SessionManager
    
    var body: some View {
        Group {
            if sessionManager.isLoading {
                LoadingView()
            } else if sessionManager.isAuthenticated {
                DashboardView()
            } else {
                AuthFlowView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: sessionManager.isAuthenticated)
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red.gradient)
                
                Text("FitLink")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.2)
            }
        }
    }
}

#Preview {
    MainAppView()
        .environmentObject(SessionManager.shared)
}

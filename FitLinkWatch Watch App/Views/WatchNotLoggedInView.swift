import SwiftUI

#if os(watchOS)

struct WatchNotLoggedInView: View {
    
    @EnvironmentObject var sessionManager: WatchSessionManager
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            
            Text("Not Logged In")
                .font(.headline)
            
            Text("Open FitLink on your iPhone to sign in")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            
            Spacer()
            
            Button {
                sessionManager.requestSync()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                    Text("Refresh")
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
        }
        .padding()
    }
}

#endif

import SwiftUI

#if os(watchOS)

struct WatchNotLoggedInView: View {
    
    @EnvironmentObject var sessionManager: WatchSessionManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                
                Text("Not Logged In")
                    .font(.headline)
                
                Text("Open FitLink on your iPhone to sign in")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    sessionManager.requestSync()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                        Text("Refresh")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .padding(.top, 8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 16)
        }
    }
}

#endif

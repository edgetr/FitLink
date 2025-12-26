import SwiftUI

struct ProfileIconView: View {
    @EnvironmentObject var sessionManager: SessionManager
    
    private var displayName: String {
        sessionManager.currentUserDisplayName ?? "User"
    }
    
    private var initials: String {
        let components = displayName.split(separator: " ")
        let firstInitial = components.first?.first.map(String.init) ?? "U"
        let lastInitial = components.count > 1 ? components.last?.first.map(String.init) ?? "" : ""
        return (firstInitial + lastInitial).uppercased()
    }
    
    private var profileImageURL: URL? {
        guard let urlString = sessionManager.user?.photoURL, !urlString.isEmpty else {
            return nil
        }
        return URL(string: urlString)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
            
            if let imageURL = profileImageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.5)
                            .tint(.white)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    case .failure:
                        Text(initials)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Text(initials)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    ProfileIconView()
        .environmentObject(SessionManager.shared)
}

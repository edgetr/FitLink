import SwiftUI

struct ProfileMenuView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var showSignOutAlert = false
    
    private var displayName: String {
        sessionManager.currentUserDisplayName ?? "User"
    }
    
    private var initials: String {
        let components = displayName.split(separator: " ")
        let firstInitial = components.first?.first.map(String.init) ?? ""
        let lastInitial = components.count > 1 ? components.last?.first.map(String.init) ?? "" : ""
        return (firstInitial + lastInitial).uppercased()
    }
    
    private var profileImageURL: URL? {
        guard let urlString = sessionManager.user?.photoURL, !urlString.isEmpty else {
            return nil
        }
        return URL(string: urlString)
    }
    
    private var userId: String {
        sessionManager.currentUserID ?? ""
    }
    
    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    profileAvatar
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
                            .font(.headline)
                        
                        if let email = sessionManager.user?.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section {
                NavigationLink(destination: ProfileView()) {
                    Label {
                        Text("Edit Profile")
                    } icon: {
                        FitLinkIcon.profile.image()
                            .frame(width: 22, height: 22)
                    }
                }
                
                NavigationLink(destination: FriendsView(userId: userId)) {
                    Label {
                        Text("Friends")
                    } icon: {
                        FitLinkIcon.friends.image()
                            .frame(width: 22, height: 22)
                    }
                }
                
                NavigationLink(destination: SettingsView()) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            
            Section {
                Button(role: .destructive) {
                    showSignOutAlert = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                try? sessionManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    private var profileAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
            
            if let imageURL = profileImageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    case .failure:
                        Text(initials)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Text(initials)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileMenuView()
            .environmentObject(SessionManager.shared)
    }
}

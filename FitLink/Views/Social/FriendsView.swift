import SwiftUI
import UIKit

struct FriendsView: View {
    @Environment(\.appEnvironment) private var appEnvironment
    
    let userId: String
    @StateObject private var viewModel: FriendsViewModel
    
    @State private var showRemoveFriendAlert = false
    @State private var friendToRemove: User?
    
    init(userId: String, friendService: FriendService = .shared) {
        self.userId = userId
        self._viewModel = StateObject(wrappedValue: FriendsViewModel(userId: userId, friendService: friendService))
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            List {
                // Search Section
                searchSection
                
                // My Friends Section
                friendsSection
                
                // Pending Requests Section (received)
                if !viewModel.pendingRequests.isEmpty {
                    pendingRequestsSection
                }
                
                // Sent Requests Section
                if !viewModel.sentRequests.isEmpty {
                    sentRequestsSection
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                await viewModel.loadAllData()
            }
            
            // Message Banners
            VStack(spacing: 8) {
                if let successMessage = viewModel.successMessage {
                    MessageBanner(
                        message: successMessage,
                        type: .success,
                        onDismiss: { viewModel.clearSuccess() }
                    )
                }
                
                if let errorMessage = viewModel.errorMessage {
                    MessageBanner(
                        message: errorMessage,
                        type: .error,
                        onDismiss: { viewModel.clearError() }
                    )
                }
            }
            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
            .padding(.top, 8)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Remove Friend", isPresented: $showRemoveFriendAlert) {
            Button("Remove", role: .destructive) {
                if let friend = friendToRemove {
                    Task {
                        await viewModel.removeFriend(friend)
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                friendToRemove = nil
            }
        } message: {
            if let friend = friendToRemove {
                Text("Are you sure you want to remove \(friend.displayName) from your friends?")
            }
        }
    }
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search by email or name...", text: $viewModel.searchQuery)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .onSubmit {
                        Task {
                            await viewModel.searchUsers()
                        }
                    }
                
                if viewModel.isSearching {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                        viewModel.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if !viewModel.searchResults.isEmpty {
                ForEach(viewModel.searchResults) { user in
                    UserSearchResultRow(
                        user: user,
                        isLoading: viewModel.isSendingRequest,
                        onAdd: {
                            Task {
                                await viewModel.sendFriendRequest(to: user.id)
                            }
                        }
                    )
                }
            } else if !viewModel.searchQuery.isEmpty && viewModel.searchQuery.count >= 3 && !viewModel.isSearching {
                HStack {
                    Spacer()
                    Text("No users found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        } header: {
            Text("Add Friend")
        } footer: {
            if viewModel.searchQuery.count > 0 && viewModel.searchQuery.count < 3 {
                Text("Enter at least 3 characters to search")
            }
        }
    }
    
    // MARK: - Friends Section
    
    private var friendsSection: some View {
        Section {
            if viewModel.isLoadingFriends && viewModel.friends.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if viewModel.friends.isEmpty {
                EmptyStateRow(
                    icon: "person.2",
                    message: "No friends yet. Search above to add friends!"
                )
            } else {
                ForEach(viewModel.friends) { friend in
                    FriendRow(friend: friend)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                friendToRemove = friend
                                showRemoveFriendAlert = true
                            } label: {
                                Label("Remove", systemImage: "person.badge.minus")
                            }
                        }
                }
            }
        } header: {
            HStack {
                Text("My Friends")
                Spacer()
                if !viewModel.friends.isEmpty {
                    Text("\(viewModel.friends.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Pending Requests Section
    
    private var pendingRequestsSection: some View {
        Section {
            ForEach(viewModel.pendingRequests) { request in
                PendingRequestRow(
                    request: request,
                    onAccept: {
                        Task {
                            await viewModel.acceptRequest(request)
                        }
                    },
                    onDecline: {
                        Task {
                            await viewModel.declineRequest(request)
                        }
                    }
                )
            }
        } header: {
            HStack {
                Text("Pending Requests")
                Spacer()
                Text("\(viewModel.pendingRequests.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Sent Requests Section
    
    private var sentRequestsSection: some View {
        Section {
            ForEach(viewModel.sentRequests) { request in
                SentRequestRow(
                    request: request,
                    onCancel: {
                        Task {
                            await viewModel.cancelRequest(request)
                        }
                    }
                )
            }
        } header: {
            HStack {
                Text("Sent Requests")
                Spacer()
                Text("\(viewModel.sentRequests.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Supporting Views

struct UserSearchResultRow: View {
    let user: User
    let isLoading: Bool
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            AvatarCircle(initials: user.initials, size: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.headline)
                
                Text(user.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: onAdd) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Image(systemName: "person.badge.plus")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
        .padding(.vertical, 4)
    }
}

struct FriendRow: View {
    let friend: User
    
    var body: some View {
        HStack(spacing: 12) {
            AvatarCircle(initials: friend.initials, size: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.headline)
                
                Text(friend.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct PendingRequestRow: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            AvatarCircle(
                initials: String(request.fromUserDisplayName?.prefix(1) ?? "?"),
                size: 40
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(request.fromUserDisplayName ?? "Unknown User")
                    .font(.headline)
                
                if let email = request.fromUserEmail {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onAccept) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                
                Button(action: onDecline) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SentRequestRow: View {
    let request: FriendRequest
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            AvatarCircle(
                initials: String(request.toUserDisplayName?.prefix(1) ?? "?"),
                size: 40
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(request.toUserDisplayName ?? "Unknown User")
                    .font(.headline)
                
                if let email = request.toUserEmail {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text("Pending")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            
            Spacer()
            
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct AvatarCircle: View {
    let initials: String
    let size: CGFloat
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Text(initials.prefix(2).uppercased())
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

struct EmptyStateRow: View {
    let icon: String
    let message: String
    
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(.secondary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 16)
            Spacer()
        }
        .listRowBackground(Color.clear)
    }
}

struct MessageBanner: View {
    enum BannerType {
        case success, error
        
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    let message: String
    let type: BannerType
    let onDismiss: () -> Void
    
    @State private var isVisible = true
    
    var body: some View {
        if isVisible {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                
                Text(message)
                    .font(.subheadline)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.bouncy(duration: 0.3)) {
                        isVisible = false
                        onDismiss()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
            }
            .foregroundStyle(.white)
            .padding(12)
            .background(type.color.gradient)
            .clipShape(RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
            .shadow(color: type.color.opacity(0.3), radius: 8, x: 0, y: 4)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.bouncy(duration: 0.3)) {
                        isVisible = false
                        onDismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        FriendsView(userId: "preview-user-id")
    }
}

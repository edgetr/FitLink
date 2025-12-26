import SwiftUI
import Combine

/// ViewModel for managing friends, friend requests, and user search
@MainActor
class FriendsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current user's friends
    @Published var friends: [User] = []
    
    /// Pending friend requests received
    @Published var pendingRequests: [FriendRequest] = []
    
    /// Friend requests sent by current user
    @Published var sentRequests: [FriendRequest] = []
    
    /// Search results for user search
    @Published var searchResults: [User] = []
    
    /// Search query text
    @Published var searchQuery: String = ""
    
    /// Loading states
    @Published var isLoadingFriends: Bool = false
    @Published var isLoadingPending: Bool = false
    @Published var isLoadingSent: Bool = false
    @Published var isSearching: Bool = false
    @Published var isSendingRequest: Bool = false
    
    /// Error and success messages
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    /// Count of pending requests for badge
    @Published var pendingRequestsCount: Int = 0
    
    // MARK: - Private Properties
    
    private let friendService = FriendService.shared
    private let userId: String
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(userId: String) {
        self.userId = userId
        setupSearchDebounce()
        Task {
            await loadAllData()
        }
    }
    
    // MARK: - Data Loading
    
    /// Load all friends data
    func loadAllData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadFriends() }
            group.addTask { await self.loadPendingRequests() }
            group.addTask { await self.loadSentRequests() }
        }
    }
    
    /// Load current user's friends
    func loadFriends() async {
        isLoadingFriends = true
        defer { isLoadingFriends = false }
        
        do {
            friends = try await friendService.getFriends(for: userId)
        } catch {
            errorMessage = "Failed to load friends: \(error.localizedDescription)"
        }
    }
    
    /// Load pending friend requests
    func loadPendingRequests() async {
        isLoadingPending = true
        defer { isLoadingPending = false }
        
        do {
            pendingRequests = try await friendService.getPendingFriendRequests(for: userId)
            pendingRequestsCount = pendingRequests.count
        } catch {
            errorMessage = "Failed to load pending requests: \(error.localizedDescription)"
        }
    }
    
    /// Load sent friend requests
    func loadSentRequests() async {
        isLoadingSent = true
        defer { isLoadingSent = false }
        
        do {
            sentRequests = try await friendService.getSentFriendRequests(for: userId)
        } catch {
            errorMessage = "Failed to load sent requests: \(error.localizedDescription)"
        }
    }
    
    /// Refresh pending requests count (for dashboard badge)
    func refreshPendingCount() async {
        do {
            pendingRequestsCount = try await friendService.getPendingRequestsCount(for: userId)
        } catch {
            // Silently fail for badge count
        }
    }
    
    // MARK: - Search
    
    private func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task {
                    await self?.performSearch(query: query)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Search for users by email or display name
    func performSearch(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        guard query.count >= 3 else {
            searchResults = []
            return
        }
        
        isSearching = true
        defer { isSearching = false }
        
        do {
            searchResults = try await friendService.searchUsersByEmail(query, excluding: userId)
            
            // Filter out users who are already friends or have pending requests
            let friendIds = Set(friends.map { $0.id })
            let pendingToIds = Set(sentRequests.map { $0.to })
            let pendingFromIds = Set(pendingRequests.map { $0.from })
            
            searchResults = searchResults.filter { user in
                !friendIds.contains(user.id) &&
                !pendingToIds.contains(user.id) &&
                !pendingFromIds.contains(user.id)
            }
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
        }
    }
    
    /// Trigger search manually
    func searchUsers() async {
        await performSearch(query: searchQuery)
    }
    
    // MARK: - Friend Request Actions
    
    /// Send a friend request to a user
    func sendFriendRequest(to recipientId: String) async {
        guard recipientId != userId else {
            errorMessage = "You cannot send a friend request to yourself."
            return
        }
        
        isSendingRequest = true
        defer { isSendingRequest = false }
        
        do {
            try await friendService.sendFriendRequest(from: userId, to: recipientId)
            successMessage = "Friend request sent!"
            
            // Remove from search results
            searchResults.removeAll { $0.id == recipientId }
            
            // Refresh sent requests
            await loadSentRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Accept a friend request
    func acceptRequest(_ request: FriendRequest) async {
        do {
            try await friendService.acceptFriendRequest(request.id)
            successMessage = "Friend request accepted!"
            
            // Refresh data
            await loadPendingRequests()
            await loadFriends()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Decline a friend request
    func declineRequest(_ request: FriendRequest) async {
        do {
            try await friendService.declineFriendRequest(request.id)
            successMessage = "Friend request declined."
            
            // Refresh pending requests
            await loadPendingRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Cancel a sent friend request
    func cancelRequest(_ request: FriendRequest) async {
        do {
            try await friendService.cancelFriendRequest(request.id)
            successMessage = "Friend request cancelled."
            
            // Refresh sent requests
            await loadSentRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Remove a friend
    func removeFriend(_ friend: User) async {
        do {
            try await friendService.removeFriend(userId: userId, friendId: friend.id)
            successMessage = "\(friend.displayName) removed from friends."
            
            // Refresh friends list
            await loadFriends()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Message Handling
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Clear success message
    func clearSuccess() {
        successMessage = nil
    }
    
    /// Clear all messages
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
    
    // MARK: - Computed Properties
    
    /// Check if any data is loading
    var isLoading: Bool {
        isLoadingFriends || isLoadingPending || isLoadingSent
    }
    
    /// Check if user has any pending requests
    var hasPendingRequests: Bool {
        !pendingRequests.isEmpty
    }
    
    /// Check if user has any friends
    var hasFriends: Bool {
        !friends.isEmpty
    }
    
    /// Get friend request status for a user ID
    func getRequestStatus(for targetUserId: String) -> FriendRequestRelationship {
        if friends.contains(where: { $0.id == targetUserId }) {
            return .friends
        }
        if sentRequests.contains(where: { $0.to == targetUserId }) {
            return .requestSent
        }
        if pendingRequests.contains(where: { $0.from == targetUserId }) {
            return .requestReceived
        }
        return .none
    }
}

// MARK: - Supporting Types

enum FriendRequestRelationship {
    case none
    case requestSent
    case requestReceived
    case friends
}

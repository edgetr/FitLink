import SwiftUI
import Combine

@MainActor
class FriendsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var friends: [User] = []
    @Published var pendingRequests: [FriendRequest] = []
    @Published var sentRequests: [FriendRequest] = []
    @Published var searchResults: [User] = []
    @Published var searchQuery: String = ""
    @Published var isLoadingFriends: Bool = false
    @Published var isLoadingPending: Bool = false
    @Published var isLoadingSent: Bool = false
    @Published var isSearching: Bool = false
    @Published var isSendingRequest: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var pendingRequestsCount: Int = 0
    
    // MARK: - Private Properties
    
    private let friendService: FriendService
    private let userId: String
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(userId: String, friendService: FriendService = .shared) {
        self.userId = userId
        self.friendService = friendService
        setupSearchDebounce()
        Task {
            await loadAllData()
        }
    }
    
    // MARK: - Data Loading
    
    func loadAllData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadFriends() }
            group.addTask { await self.loadPendingRequests() }
            group.addTask { await self.loadSentRequests() }
        }
    }
    
    func loadFriends() async {
        isLoadingFriends = true
        defer { isLoadingFriends = false }
        
        do {
            friends = try await friendService.getFriends(for: userId)
        } catch {
            errorMessage = ErrorHandler.shared.handle(error, context: "loadFriends").userMessage
        }
    }
    
    func loadPendingRequests() async {
        isLoadingPending = true
        defer { isLoadingPending = false }
        
        do {
            pendingRequests = try await friendService.getPendingFriendRequests(for: userId)
            pendingRequestsCount = pendingRequests.count
        } catch {
            errorMessage = ErrorHandler.shared.handle(error, context: "loadPendingRequests").userMessage
        }
    }
    
    func loadSentRequests() async {
        isLoadingSent = true
        defer { isLoadingSent = false }
        
        do {
            sentRequests = try await friendService.getSentFriendRequests(for: userId)
        } catch {
            errorMessage = ErrorHandler.shared.handle(error, context: "loadSentRequests").userMessage
        }
    }
    
    func refreshPendingCount() async {
        do {
            pendingRequestsCount = try await friendService.getPendingRequestsCount(for: userId)
        } catch {
            ErrorHandler.shared.log("Failed to refresh pending count", severity: .warning, context: "FriendsViewModel")
        }
    }
    
    // MARK: - Search
    
    private func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                self.searchTask?.cancel()
                self.searchTask = Task {
                    await self.performSearch(query: query)
                }
            }
            .store(in: &cancellables)
    }
    
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
            try Task.checkCancellation()
            let results = try await friendService.searchUsersByEmail(query, excluding: userId)
            try Task.checkCancellation()
            
            let friendIds = Set(friends.map { $0.id })
            let pendingToIds = Set(sentRequests.map { $0.to })
            let pendingFromIds = Set(pendingRequests.map { $0.from })
            
            searchResults = results.filter { user in
                !friendIds.contains(user.id) &&
                !pendingToIds.contains(user.id) &&
                !pendingFromIds.contains(user.id)
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = ErrorHandler.shared.handle(error, context: "searchUsers").userMessage
        }
    }
    
    func searchUsers() async {
        searchTask?.cancel()
        searchTask = Task {
            await performSearch(query: searchQuery)
        }
        await searchTask?.value
    }
    
    // MARK: - Friend Request Actions
    
    func sendFriendRequest(to recipientId: String) async {
        guard recipientId != userId else {
            errorMessage = UserFriendlyErrorMessages.Generic.tryAgain
            return
        }
        
        isSendingRequest = true
        defer { isSendingRequest = false }
        
        do {
            try await friendService.sendFriendRequest(from: userId, to: recipientId)
            successMessage = "Friend request sent!"
            searchResults.removeAll { $0.id == recipientId }
            await loadSentRequests()
        } catch {
            errorMessage = ErrorHandler.shared.handle(error, context: "sendFriendRequest").userMessage
        }
    }
    
    func acceptRequest(_ request: FriendRequest) async {
        do {
            try await friendService.acceptFriendRequest(request.id)
            successMessage = "Friend request accepted!"
            await loadPendingRequests()
            await loadFriends()
        } catch {
            errorMessage = ErrorHandler.shared.handle(error, context: "acceptFriendRequest").userMessage
        }
    }
    
    func declineRequest(_ request: FriendRequest) async {
        do {
            try await friendService.declineFriendRequest(request.id)
            successMessage = "Friend request declined."
            await loadPendingRequests()
        } catch {
            errorMessage = ErrorHandler.shared.handle(error, context: "declineFriendRequest").userMessage
        }
    }
    
    func cancelRequest(_ request: FriendRequest) async {
        do {
            try await friendService.cancelFriendRequest(request.id)
            successMessage = "Friend request cancelled."
            await loadSentRequests()
        } catch {
            errorMessage = ErrorHandler.shared.handle(error, context: "cancelFriendRequest").userMessage
        }
    }
    
    func removeFriend(_ friend: User) async {
        do {
            try await friendService.removeFriend(userId: userId, friendId: friend.id)
            successMessage = "\(friend.displayName) removed from friends."
            await loadFriends()
        } catch {
            errorMessage = ErrorHandler.shared.handle(error, context: "removeFriend").userMessage
        }
    }
    
    // MARK: - Message Handling
    
    func clearError() {
        errorMessage = nil
    }
    
    func clearSuccess() {
        successMessage = nil
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
    
    // MARK: - Computed Properties
    
    var isLoading: Bool {
        isLoadingFriends || isLoadingPending || isLoadingSent
    }
    
    var hasPendingRequests: Bool {
        !pendingRequests.isEmpty
    }
    
    var hasFriends: Bool {
        !friends.isEmpty
    }
    
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

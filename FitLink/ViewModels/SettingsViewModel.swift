import Foundation
import Combine

enum SettingsLoadState {
    case idle
    case loading
    case loaded
    case error(String)
}

@MainActor
final class SettingsViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let sessionManager: SessionManager
    private let memoryService: MemoryService
    private let userService: UserService
    
    // MARK: - Published Properties
    
    @Published private(set) var memoriesCount: Int = 0
    @Published private(set) var loadState: SettingsLoadState = .idle
    @Published var isDeletingAccount = false
    @Published var deleteAccountError: String?
    
    // MARK: - Initialization
    
    init(
        sessionManager: SessionManager = .shared,
        memoryService: MemoryService = .shared,
        userService: UserService = .shared
    ) {
        self.sessionManager = sessionManager
        self.memoryService = memoryService
        self.userService = userService
    }
    
    // MARK: - Public Methods
    
    func loadMemoriesCount() async {
        guard let userId = sessionManager.currentUserID else {
            memoriesCount = 0
            return
        }
        
        loadState = .loading
        
        do {
            let memories = try await memoryService.getAllMemories(userId: userId)
            memoriesCount = memories.count
            loadState = .loaded
        } catch {
            loadState = .error(error.localizedDescription)
            memoriesCount = 0
        }
    }
    
    func deleteAccount() async -> Bool {
        guard let userId = sessionManager.currentUserID else {
            deleteAccountError = "No user logged in"
            return false
        }
        
        isDeletingAccount = true
        deleteAccountError = nil
        
        do {
            try await memoryService.deleteAllMemories(userId: userId)
            try await userService.deleteUser(userId)
            try sessionManager.signOut()
            isDeletingAccount = false
            return true
        } catch {
            deleteAccountError = error.localizedDescription
            isDeletingAccount = false
            return false
        }
    }
    
    var isLoading: Bool {
        if case .loading = loadState { return true }
        return false
    }
}

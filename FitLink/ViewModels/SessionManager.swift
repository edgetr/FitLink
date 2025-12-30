import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class SessionManager: ObservableObject {
    
    static let shared = SessionManager()
    
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var currentUserID: String?
    @Published var currentUserDisplayName: String?
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var cancellables = Set<AnyCancellable>()
    private let db = Firestore.firestore()
    
    private init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let firebaseUser = firebaseUser {
                    self.currentUserID = firebaseUser.uid
                    self.isAuthenticated = true
                    
                    // Only update displayName from Firebase Auth if we don't already have it
                    // This prevents race conditions during signup where profile changes haven't committed yet
                    if self.currentUserDisplayName == nil || self.currentUserDisplayName?.isEmpty == true {
                        self.currentUserDisplayName = firebaseUser.displayName
                    }
                    
                    await self.fetchUserFromFirestore(uid: firebaseUser.uid)
                } else {
                    self.user = nil
                    self.currentUserID = nil
                    self.currentUserDisplayName = nil
                    self.isAuthenticated = false
                }
                self.isLoading = false
            }
        }
    }
    
    private func fetchUserFromFirestore(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            if document.exists, let data = document.data(), let fetchedUser = User.fromDictionary(data, id: uid) {
                self.user = fetchedUser
                self.currentUserDisplayName = fetchedUser.displayName
            }
        } catch {
            AppLogger.shared.error("Error fetching user from Firestore: \(error.localizedDescription)", category: .auth)
        }
    }
    
    func signUp(email: String, password: String, displayName: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
            
            let newUser = User(
                id: result.user.uid,
                displayName: displayName,
                email: email,
                photoURL: nil,
                friendIDs: [],
                createdAt: Date()
            )
            
            try await db.collection("users").document(result.user.uid).setData(newUser.toDictionary())
            
            self.user = newUser
            self.currentUserID = result.user.uid
            self.currentUserDisplayName = displayName
            self.isAuthenticated = true
            
            await triggerHealthSync(userId: result.user.uid)
            await pushWatchSyncState()
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.currentUserID = result.user.uid
            self.currentUserDisplayName = result.user.displayName
            self.isAuthenticated = true
            await fetchUserFromFirestore(uid: result.user.uid)
            
            await triggerHealthSync(userId: result.user.uid)
            await pushWatchSyncState()
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }
    
    func signOut() async throws {
        do {
            try Auth.auth().signOut()
            self.user = nil
            self.currentUserID = nil
            self.currentUserDisplayName = nil
            self.isAuthenticated = false
            HealthSyncScheduler.shared.clearCurrentUser()
            await pushWatchSyncState()
        } catch {
            errorMessage = "Failed to sign out. Please try again."
            throw error
        }
    }
    
    private func pushWatchSyncState() async {
        #if os(iOS)
        await WatchConnectivityService.shared.pushStateToWatch()
        #endif
    }
    
    func resetPassword(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            errorMessage = mapAuthError(error)
            throw error
        }
    }
    
    func refreshUser() async {
        guard let uid = currentUserID else { return }
        await fetchUserFromFirestore(uid: uid)
    }
    
    func updateDisplayName(_ newName: String) {
        currentUserDisplayName = newName
        if var updatedUser = user {
            updatedUser.displayName = newName
            user = updatedUser
        }
    }
    
    private func triggerHealthSync(userId: String) async {
        HealthSyncScheduler.shared.setCurrentUser(userId)
        
        let authorized = try? await HealthDataCollector.shared.requestFullAuthorization()
        if authorized == true {
            await HealthSyncScheduler.shared.performForegroundSync(userId: userId)
        }
    }
    
    private func mapAuthError(_ error: Error) -> String {
        let nsError = error as NSError
        
        switch nsError.code {
        case AuthErrorCode.invalidEmail.rawValue:
            return "Invalid email address."
        case AuthErrorCode.wrongPassword.rawValue:
            return "Incorrect password."
        case AuthErrorCode.userNotFound.rawValue:
            return "No account found with this email."
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "This email is already registered."
        case AuthErrorCode.weakPassword.rawValue:
            return "Password is too weak. Use at least 6 characters."
        case AuthErrorCode.networkError.rawValue:
            return "Network error. Please check your connection."
        default:
            return "An error occurred. Please try again."
        }
    }
}

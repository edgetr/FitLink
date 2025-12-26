import Foundation
import FirebaseFirestore

/// Service for managing friend requests and friendships
class FriendService {
    
    static let shared = FriendService()
    
    private let db = Firestore.firestore()
    private let friendRequestsCollection = "friend_requests"
    private let usersCollection = "users"
    
    var errorMessage: String?
    
    private init() {}
    
    // MARK: - Friend Request Operations
    
    /// Send a friend request from one user to another
    func sendFriendRequest(from senderId: String, to recipientId: String) async throws {
        // Check if request already exists
        let existingRequest = try await getExistingRequest(from: senderId, to: recipientId)
        if existingRequest != nil {
            throw FriendServiceError.requestAlreadyExists
        }
        
        // Check if they're already friends
        let sender = try await getUser(byId: senderId)
        if sender?.friendIDs.contains(recipientId) == true {
            throw FriendServiceError.alreadyFriends
        }
        
        // Get user info for caching in the request
        let senderInfo = try await getUser(byId: senderId)
        let recipientInfo = try await getUser(byId: recipientId)
        
        let request = FriendRequest(
            from: senderId,
            to: recipientId,
            fromUserDisplayName: senderInfo?.displayName,
            fromUserEmail: senderInfo?.email,
            toUserDisplayName: recipientInfo?.displayName,
            toUserEmail: recipientInfo?.email
        )
        
        try await db.collection(friendRequestsCollection)
            .document(request.id)
            .setData(request.toDictionary())
    }
    
    /// Accept a friend request
    func acceptFriendRequest(_ requestId: String) async throws {
        // Get the request
        guard let request = try await getFriendRequest(byId: requestId) else {
            throw FriendServiceError.requestNotFound
        }
        
        guard request.status == .pending else {
            throw FriendServiceError.requestNotPending
        }
        
        // Update request status
        try await db.collection(friendRequestsCollection)
            .document(requestId)
            .updateData([
                "status": FriendRequestStatus.accepted.rawValue,
                "updated_at": Timestamp(date: Date())
            ])
        
        // Add each user to the other's friend list using batch
        let batch = db.batch()
        
        let senderRef = db.collection(usersCollection).document(request.from)
        batch.updateData(["friend_ids": FieldValue.arrayUnion([request.to])], forDocument: senderRef)
        
        let recipientRef = db.collection(usersCollection).document(request.to)
        batch.updateData(["friend_ids": FieldValue.arrayUnion([request.from])], forDocument: recipientRef)
        
        try await batch.commit()
    }
    
    /// Decline a friend request
    func declineFriendRequest(_ requestId: String) async throws {
        guard let request = try await getFriendRequest(byId: requestId) else {
            throw FriendServiceError.requestNotFound
        }
        
        guard request.status == .pending else {
            throw FriendServiceError.requestNotPending
        }
        
        try await db.collection(friendRequestsCollection)
            .document(requestId)
            .updateData([
                "status": FriendRequestStatus.declined.rawValue,
                "updated_at": Timestamp(date: Date())
            ])
    }
    
    /// Cancel a sent friend request
    func cancelFriendRequest(_ requestId: String) async throws {
        guard let request = try await getFriendRequest(byId: requestId) else {
            throw FriendServiceError.requestNotFound
        }
        
        guard request.status == .pending else {
            throw FriendServiceError.requestNotPending
        }
        
        // Delete the request document
        try await db.collection(friendRequestsCollection)
            .document(requestId)
            .delete()
    }
    
    /// Remove a friend from user's friend list
    func removeFriend(userId: String, friendId: String) async throws {
        let batch = db.batch()
        
        let userRef = db.collection(usersCollection).document(userId)
        batch.updateData(["friend_ids": FieldValue.arrayRemove([friendId])], forDocument: userRef)
        
        let friendRef = db.collection(usersCollection).document(friendId)
        batch.updateData(["friend_ids": FieldValue.arrayRemove([userId])], forDocument: friendRef)
        
        try await batch.commit()
    }
    
    // MARK: - Query Methods
    
    /// Get pending friend requests received by a user
    func getPendingFriendRequests(for userId: String) async throws -> [FriendRequest] {
        let snapshot = try await db.collection(friendRequestsCollection)
            .whereField("to_user_id", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .order(by: "created_at", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            FriendRequest.fromDictionary(doc.data(), id: doc.documentID)
        }
    }
    
    /// Get friend requests sent by a user
    func getSentFriendRequests(for userId: String) async throws -> [FriendRequest] {
        let snapshot = try await db.collection(friendRequestsCollection)
            .whereField("from_user_id", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .order(by: "created_at", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            FriendRequest.fromDictionary(doc.data(), id: doc.documentID)
        }
    }
    
    /// Get all friends for a user
    func getFriends(for userId: String) async throws -> [User] {
        guard let user = try await getUser(byId: userId) else {
            return []
        }
        
        guard !user.friendIDs.isEmpty else {
            return []
        }
        
        // Firestore 'in' query supports max 10 items, so batch if needed
        var allFriends: [User] = []
        let chunks = user.friendIDs.chunked(into: 10)
        
        for chunk in chunks {
            let snapshot = try await db.collection(usersCollection)
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            
            let friends = snapshot.documents.compactMap { doc in
                User.fromDictionary(doc.data(), id: doc.documentID)
            }
            allFriends.append(contentsOf: friends)
        }
        
        return allFriends
    }
    
    /// Get count of pending friend requests for badge display
    func getPendingRequestsCount(for userId: String) async throws -> Int {
        let snapshot = try await db.collection(friendRequestsCollection)
            .whereField("to_user_id", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .getDocuments()
        
        return snapshot.documents.count
    }
    
    // MARK: - Search
    
    /// Search users by email (case-insensitive partial match)
    func searchUsersByEmail(_ query: String, excluding currentUserId: String) async throws -> [User] {
        let lowercasedQuery = query.lowercased()
        
        // Firestore doesn't support case-insensitive partial match natively
        // We'll fetch potential matches and filter client-side
        // For production, consider using Algolia or a search index
        
        let snapshot = try await db.collection(usersCollection)
            .order(by: "email")
            .start(at: [lowercasedQuery])
            .end(at: [lowercasedQuery + "\u{f8ff}"])
            .limit(to: 20)
            .getDocuments()
        
        var users = snapshot.documents.compactMap { doc in
            User.fromDictionary(doc.data(), id: doc.documentID)
        }
        
        // Filter out current user and apply case-insensitive filtering
        users = users.filter { user in
            user.id != currentUserId &&
            (user.email.lowercased().contains(lowercasedQuery) ||
             user.displayName.lowercased().contains(lowercasedQuery))
        }
        
        return users
    }
    
    // MARK: - Helper Methods
    
    private func getFriendRequest(byId requestId: String) async throws -> FriendRequest? {
        let doc = try await db.collection(friendRequestsCollection)
            .document(requestId)
            .getDocument()
        
        guard let data = doc.data() else { return nil }
        return FriendRequest.fromDictionary(data, id: doc.documentID)
    }
    
    private func getUser(byId userId: String) async throws -> User? {
        let doc = try await db.collection(usersCollection)
            .document(userId)
            .getDocument()
        
        guard let data = doc.data() else { return nil }
        return User.fromDictionary(data, id: doc.documentID)
    }
    
    private func getExistingRequest(from senderId: String, to recipientId: String) async throws -> FriendRequest? {
        // Check for request in either direction
        let sentSnapshot = try await db.collection(friendRequestsCollection)
            .whereField("from_user_id", isEqualTo: senderId)
            .whereField("to_user_id", isEqualTo: recipientId)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .limit(to: 1)
            .getDocuments()
        
        if let doc = sentSnapshot.documents.first {
            return FriendRequest.fromDictionary(doc.data(), id: doc.documentID)
        }
        
        // Also check reverse direction
        let receivedSnapshot = try await db.collection(friendRequestsCollection)
            .whereField("from_user_id", isEqualTo: recipientId)
            .whereField("to_user_id", isEqualTo: senderId)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .limit(to: 1)
            .getDocuments()
        
        if let doc = receivedSnapshot.documents.first {
            return FriendRequest.fromDictionary(doc.data(), id: doc.documentID)
        }
        
        return nil
    }
}

// MARK: - Error Types

enum FriendServiceError: LocalizedError {
    case requestAlreadyExists
    case alreadyFriends
    case requestNotFound
    case requestNotPending
    case userNotFound
    case selfFriendRequest
    
    var errorDescription: String? {
        switch self {
        case .requestAlreadyExists:
            return "A friend request already exists between these users."
        case .alreadyFriends:
            return "You are already friends with this user."
        case .requestNotFound:
            return "Friend request not found."
        case .requestNotPending:
            return "This friend request is no longer pending."
        case .userNotFound:
            return "User not found."
        case .selfFriendRequest:
            return "You cannot send a friend request to yourself."
        }
    }
}

// MARK: - Array Extension for chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

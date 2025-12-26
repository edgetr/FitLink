import Foundation
import FirebaseFirestore

/// Status of a friend request
enum FriendRequestStatus: String, Codable, CaseIterable {
    case pending
    case accepted
    case declined
    case cancelled
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        case .cancelled: return "Cancelled"
        }
    }
}

/// Represents a friend request between two users
struct FriendRequest: Identifiable, Codable {
    let id: String
    let from: String
    let to: String
    var status: FriendRequestStatus
    let createdAt: Date
    var updatedAt: Date
    
    // Optional cached user info for display
    var fromUserDisplayName: String?
    var fromUserEmail: String?
    var toUserDisplayName: String?
    var toUserEmail: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case from = "from_user_id"
        case to = "to_user_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case fromUserDisplayName = "from_user_display_name"
        case fromUserEmail = "from_user_email"
        case toUserDisplayName = "to_user_display_name"
        case toUserEmail = "to_user_email"
    }
    
    init(
        id: String = UUID().uuidString,
        from: String,
        to: String,
        status: FriendRequestStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        fromUserDisplayName: String? = nil,
        fromUserEmail: String? = nil,
        toUserDisplayName: String? = nil,
        toUserEmail: String? = nil
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.fromUserDisplayName = fromUserDisplayName
        self.fromUserEmail = fromUserEmail
        self.toUserDisplayName = toUserDisplayName
        self.toUserEmail = toUserEmail
    }
    
    /// Convert to dictionary for Firestore
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "from_user_id": from,
            "to_user_id": to,
            "status": status.rawValue,
            "created_at": Timestamp(date: createdAt),
            "updated_at": Timestamp(date: updatedAt)
        ]
        
        if let fromUserDisplayName = fromUserDisplayName {
            dict["from_user_display_name"] = fromUserDisplayName
        }
        if let fromUserEmail = fromUserEmail {
            dict["from_user_email"] = fromUserEmail
        }
        if let toUserDisplayName = toUserDisplayName {
            dict["to_user_display_name"] = toUserDisplayName
        }
        if let toUserEmail = toUserEmail {
            dict["to_user_email"] = toUserEmail
        }
        
        return dict
    }
    
    /// Create from Firestore dictionary
    static func fromDictionary(_ data: [String: Any], id: String) -> FriendRequest? {
        guard let from = data["from_user_id"] as? String,
              let to = data["to_user_id"] as? String,
              let statusRaw = data["status"] as? String,
              let status = FriendRequestStatus(rawValue: statusRaw) else {
            return nil
        }
        
        let createdAt = (data["created_at"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updated_at"] as? Timestamp)?.dateValue() ?? Date()
        
        return FriendRequest(
            id: id,
            from: from,
            to: to,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            fromUserDisplayName: data["from_user_display_name"] as? String,
            fromUserEmail: data["from_user_email"] as? String,
            toUserDisplayName: data["to_user_display_name"] as? String,
            toUserEmail: data["to_user_email"] as? String
        )
    }
    
    // MARK: - Computed Properties
    
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var isPending: Bool {
        status == .pending
    }
    
    // MARK: - Sample Data
    
    static var sample: FriendRequest {
        FriendRequest(
            id: "sample-request-id",
            from: "user-1",
            to: "user-2",
            status: .pending,
            fromUserDisplayName: "John Doe",
            fromUserEmail: "john@example.com",
            toUserDisplayName: "Jane Smith",
            toUserEmail: "jane@example.com"
        )
    }
    
    static var samplePending: [FriendRequest] {
        [
            FriendRequest(
                id: "req-1",
                from: "user-a",
                to: "current-user",
                fromUserDisplayName: "Alice Johnson",
                fromUserEmail: "alice@example.com"
            ),
            FriendRequest(
                id: "req-2",
                from: "user-b",
                to: "current-user",
                fromUserDisplayName: "Bob Williams",
                fromUserEmail: "bob@example.com"
            )
        ]
    }
}

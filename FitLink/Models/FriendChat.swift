import Foundation
import FirebaseFirestore

struct TypingStatus: Codable, Sendable {
    let userId: String
    let timestamp: Date
    
    var isActive: Bool {
        Date().timeIntervalSince(timestamp) < 5.0
    }
}

// MARK: - Last Message Preview

struct LastMessagePreview: Codable, Sendable {
    let senderId: String
    let encryptedPreview: String?
    let timestamp: Date
    let type: FriendChatMessageType
    
    enum CodingKeys: String, CodingKey {
        case senderId = "sender_id"
        case encryptedPreview = "encrypted_preview"
        case timestamp
        case type
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "sender_id": senderId,
            "timestamp": Timestamp(date: timestamp),
            "type": type.rawValue
        ]
        if let preview = encryptedPreview {
            dict["encrypted_preview"] = preview
        }
        return dict
    }
    
    static func fromDictionary(_ data: [String: Any]) -> LastMessagePreview? {
        guard let senderId = data["sender_id"] as? String,
              let typeRaw = data["type"] as? String,
              let type = FriendChatMessageType(rawValue: typeRaw) else {
            return nil
        }
        
        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        let encryptedPreview = data["encrypted_preview"] as? String
        
        return LastMessagePreview(
            senderId: senderId,
            encryptedPreview: encryptedPreview,
            timestamp: timestamp,
            type: type
        )
    }
}

// MARK: - Friend Chat

/// Represents a chat thread between two friends
struct FriendChat: Identifiable, Codable, Sendable {
    let id: String
    let participantIds: [String]
    var lastMessage: LastMessagePreview?
    var updatedAt: Date
    let createdAt: Date
    var typingStatus: [String: Date]
    var encryptionInitialized: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case participantIds = "participant_ids"
        case lastMessage = "last_message"
        case updatedAt = "updated_at"
        case createdAt = "created_at"
        case typingStatus = "typing_status"
        case encryptionInitialized = "encryption_initialized"
    }
    
    // MARK: - Initialization
    
    init(
        id: String? = nil,
        participantIds: [String],
        lastMessage: LastMessagePreview? = nil,
        updatedAt: Date = Date(),
        createdAt: Date = Date(),
        typingStatus: [String: Date] = [:],
        encryptionInitialized: Bool = false
    ) {
        // Create deterministic ID from sorted participant IDs
        self.id = id ?? FriendChat.deterministicId(for: participantIds)
        self.participantIds = participantIds.sorted()
        self.lastMessage = lastMessage
        self.updatedAt = updatedAt
        self.createdAt = createdAt
        self.typingStatus = typingStatus
        self.encryptionInitialized = encryptionInitialized
    }
    
    // MARK: - Deterministic ID
    
    /// Creates a deterministic chat ID from two user IDs
    static func deterministicId(for participantIds: [String]) -> String {
        let sorted = participantIds.sorted()
        return "chat_\(sorted.joined(separator: "_"))"
    }
    
    static func deterministicId(user1: String, user2: String) -> String {
        deterministicId(for: [user1, user2])
    }
    
    // MARK: - Computed Properties
    
    /// Get the other participant's ID given the current user's ID
    func otherParticipantId(currentUserId: String) -> String? {
        participantIds.first { $0 != currentUserId }
    }
    
    /// Check if a specific user is currently typing
    func isUserTyping(_ userId: String) -> Bool {
        guard let timestamp = typingStatus[userId] else { return false }
        return Date().timeIntervalSince(timestamp) < 5.0
    }
    
    /// Get all users currently typing (excluding current user)
    func typingUsers(excludingUserId: String) -> [String] {
        typingStatus.compactMap { userId, timestamp in
            guard userId != excludingUserId,
                  Date().timeIntervalSince(timestamp) < 5.0 else {
                return nil
            }
            return userId
        }
    }
    
    // MARK: - Firestore Conversion
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "participant_ids": participantIds,
            "updated_at": Timestamp(date: updatedAt),
            "created_at": Timestamp(date: createdAt),
            "encryption_initialized": encryptionInitialized
        ]
        
        if let lastMessage = lastMessage {
            dict["last_message"] = lastMessage.toDictionary()
        }
        
        // Convert typing status to Firestore format
        var typingDict: [String: Any] = [:]
        for (userId, timestamp) in typingStatus {
            typingDict[userId] = Timestamp(date: timestamp)
        }
        if !typingDict.isEmpty {
            dict["typing_status"] = typingDict
        }
        
        return dict
    }
    
    static func fromDictionary(_ data: [String: Any], id: String) -> FriendChat? {
        guard let participantIds = data["participant_ids"] as? [String] else {
            return nil
        }
        
        let updatedAt = (data["updated_at"] as? Timestamp)?.dateValue() ?? Date()
        let createdAt = (data["created_at"] as? Timestamp)?.dateValue() ?? Date()
        let encryptionInitialized = data["encryption_initialized"] as? Bool ?? false
        
        // Parse last message
        var lastMessage: LastMessagePreview?
        if let lastMessageData = data["last_message"] as? [String: Any] {
            lastMessage = LastMessagePreview.fromDictionary(lastMessageData)
        }
        
        // Parse typing status
        var typingStatus: [String: Date] = [:]
        if let typingData = data["typing_status"] as? [String: Any] {
            for (userId, value) in typingData {
                if let timestamp = value as? Timestamp {
                    typingStatus[userId] = timestamp.dateValue()
                }
            }
        }
        
        return FriendChat(
            id: id,
            participantIds: participantIds,
            lastMessage: lastMessage,
            updatedAt: updatedAt,
            createdAt: createdAt,
            typingStatus: typingStatus,
            encryptionInitialized: encryptionInitialized
        )
    }
    
    // MARK: - Sample Data
    
    static var sample: FriendChat {
        FriendChat(
            id: "chat_user1_user2",
            participantIds: ["user1", "user2"],
            lastMessage: LastMessagePreview(
                senderId: "user1",
                encryptedPreview: nil,
                timestamp: Date(),
                type: .text
            ),
            encryptionInitialized: true
        )
    }
}

// MARK: - Equatable & Hashable

extension FriendChat: Equatable {
    static func == (lhs: FriendChat, rhs: FriendChat) -> Bool {
        lhs.id == rhs.id
    }
}

extension FriendChat: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

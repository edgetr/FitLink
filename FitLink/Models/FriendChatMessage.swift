import Foundation
import FirebaseFirestore

enum FriendChatMessageType: String, Codable, CaseIterable, Sendable {
    case text
    case image
    case file
    case dietPlan = "diet_plan"
    case workoutPlan = "workout_plan"
    case voice
    case challenge
}

enum MessageStatus: String, Codable, CaseIterable, Sendable {
    case sending
    case sent
    case delivered
    case read
    case failed
}

struct MessagePayload: Codable, Sendable {
    var planId: String?
    var planTitle: String?
    var planType: String?
    var voiceUrl: String?
    var voiceDuration: TimeInterval?
    var imageUrl: String?
    var imageThumbnailUrl: String?
    var fileUrl: String?
    var fileName: String?
    var fileSize: Int64?
    var challengeId: String?
    
    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case planTitle = "plan_title"
        case planType = "plan_type"
        case voiceUrl = "voice_url"
        case voiceDuration = "voice_duration"
        case imageUrl = "image_url"
        case imageThumbnailUrl = "image_thumbnail_url"
        case fileUrl = "file_url"
        case fileName = "file_name"
        case fileSize = "file_size"
        case challengeId = "challenge_id"
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let planId = planId { dict["plan_id"] = planId }
        if let planTitle = planTitle { dict["plan_title"] = planTitle }
        if let planType = planType { dict["plan_type"] = planType }
        if let voiceUrl = voiceUrl { dict["voice_url"] = voiceUrl }
        if let voiceDuration = voiceDuration { dict["voice_duration"] = voiceDuration }
        if let imageUrl = imageUrl { dict["image_url"] = imageUrl }
        if let imageThumbnailUrl = imageThumbnailUrl { dict["image_thumbnail_url"] = imageThumbnailUrl }
        if let fileUrl = fileUrl { dict["file_url"] = fileUrl }
        if let fileName = fileName { dict["file_name"] = fileName }
        if let fileSize = fileSize { dict["file_size"] = fileSize }
        if let challengeId = challengeId { dict["challenge_id"] = challengeId }
        return dict
    }
    
    static func fromDictionary(_ data: [String: Any]) -> MessagePayload {
        MessagePayload(
            planId: data["plan_id"] as? String,
            planTitle: data["plan_title"] as? String,
            planType: data["plan_type"] as? String,
            voiceUrl: data["voice_url"] as? String,
            voiceDuration: data["voice_duration"] as? TimeInterval,
            imageUrl: data["image_url"] as? String,
            imageThumbnailUrl: data["image_thumbnail_url"] as? String,
            fileUrl: data["file_url"] as? String,
            fileName: data["file_name"] as? String,
            fileSize: data["file_size"] as? Int64,
            challengeId: data["challenge_id"] as? String
        )
    }
}

struct FriendChatMessage: Identifiable, Codable, Sendable {
    let id: String
    let senderId: String
    let type: FriendChatMessageType
    var encryptedContent: String
    var iv: String
    var payload: MessagePayload?
    let timestamp: Date
    var status: MessageStatus
    var readAt: Date?
    var replyToId: String?
    
    var decryptedContent: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case type
        case encryptedContent = "encrypted_content"
        case iv
        case payload
        case timestamp
        case status
        case readAt = "read_at"
        case replyToId = "reply_to"
    }
    
    init(
        id: String = UUID().uuidString,
        senderId: String,
        type: FriendChatMessageType = .text,
        encryptedContent: String = "",
        iv: String = "",
        payload: MessagePayload? = nil,
        timestamp: Date = Date(),
        status: MessageStatus = .sending,
        readAt: Date? = nil,
        replyToId: String? = nil,
        decryptedContent: String? = nil
    ) {
        self.id = id
        self.senderId = senderId
        self.type = type
        self.encryptedContent = encryptedContent
        self.iv = iv
        self.payload = payload
        self.timestamp = timestamp
        self.status = status
        self.readAt = readAt
        self.replyToId = replyToId
        self.decryptedContent = decryptedContent
    }
    
    var isFromCurrentUser: Bool {
        false
    }
    
    func isFromUser(_ userId: String) -> Bool {
        senderId == userId
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: timestamp)
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "sender_id": senderId,
            "type": type.rawValue,
            "encrypted_content": encryptedContent,
            "iv": iv,
            "timestamp": Timestamp(date: timestamp),
            "status": status.rawValue
        ]
        
        if let payload = payload {
            dict["payload"] = payload.toDictionary()
        }
        if let readAt = readAt {
            dict["read_at"] = Timestamp(date: readAt)
        }
        if let replyToId = replyToId {
            dict["reply_to"] = replyToId
        }
        
        return dict
    }
    
    static func fromDictionary(_ data: [String: Any], id: String) -> FriendChatMessage? {
        guard let senderId = data["sender_id"] as? String,
              let typeRaw = data["type"] as? String,
              let type = FriendChatMessageType(rawValue: typeRaw),
              let encryptedContent = data["encrypted_content"] as? String,
              let iv = data["iv"] as? String else {
            return nil
        }
        
        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        let statusRaw = data["status"] as? String ?? MessageStatus.sent.rawValue
        let status = MessageStatus(rawValue: statusRaw) ?? .sent
        let readAt = (data["read_at"] as? Timestamp)?.dateValue()
        let replyToId = data["reply_to"] as? String
        
        var payload: MessagePayload?
        if let payloadData = data["payload"] as? [String: Any] {
            payload = MessagePayload.fromDictionary(payloadData)
        }
        
        return FriendChatMessage(
            id: id,
            senderId: senderId,
            type: type,
            encryptedContent: encryptedContent,
            iv: iv,
            payload: payload,
            timestamp: timestamp,
            status: status,
            readAt: readAt,
            replyToId: replyToId
        )
    }
    
    static var sample: FriendChatMessage {
        FriendChatMessage(
            id: "msg-1",
            senderId: "user-1",
            type: .text,
            encryptedContent: "encrypted",
            iv: "iv123",
            timestamp: Date(),
            status: .sent,
            decryptedContent: "Hello! How's your workout going?"
        )
    }
    
    static var sampleConversation: [FriendChatMessage] {
        [
            FriendChatMessage(
                id: "msg-1",
                senderId: "user-1",
                type: .text,
                timestamp: Date().addingTimeInterval(-3600),
                status: .read,
                decryptedContent: "Hey! Just finished my morning run!"
            ),
            FriendChatMessage(
                id: "msg-2",
                senderId: "user-2",
                type: .text,
                timestamp: Date().addingTimeInterval(-3500),
                status: .read,
                decryptedContent: "Nice! How far did you go?"
            ),
            FriendChatMessage(
                id: "msg-3",
                senderId: "user-1",
                type: .text,
                timestamp: Date().addingTimeInterval(-3400),
                status: .read,
                decryptedContent: "5K in 28 minutes. New personal best!"
            ),
            FriendChatMessage(
                id: "msg-4",
                senderId: "user-2",
                type: .text,
                timestamp: Date().addingTimeInterval(-3300),
                status: .sent,
                decryptedContent: "That's awesome! Check out my new workout plan"
            )
        ]
    }
}

extension FriendChatMessage: Equatable {
    static func == (lhs: FriendChatMessage, rhs: FriendChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

extension FriendChatMessage: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

import Foundation
import FirebaseFirestore
import FirebaseStorage
import Combine

enum ChatServiceError: LocalizedError {
    case chatNotFound
    case messageNotFound
    case encryptionNotInitialized
    case invalidParticipants
    case sendFailed
    case fetchFailed
    case listenerFailed
    case uploadFailed
    case invalidImageData
    
    var errorDescription: String? {
        switch self {
        case .chatNotFound:
            return "Chat not found"
        case .messageNotFound:
            return "Message not found"
        case .encryptionNotInitialized:
            return "Encryption not initialized for this chat"
        case .invalidParticipants:
            return "Invalid chat participants"
        case .sendFailed:
            return "Failed to send message"
        case .fetchFailed:
            return "Failed to fetch messages"
        case .listenerFailed:
            return "Failed to start message listener"
        case .uploadFailed:
            return "Failed to upload image"
        case .invalidImageData:
            return "Invalid image data"
        }
    }
}

actor ChatService {
    
    static let shared = ChatService()
    
    private let db = Firestore.firestore()
    private let chatsCollection = "friend_chats"
    private let messagesSubcollection = "friend_messages"
    private let userKeysCollection = "user_keys"
    private let challengesSubcollection = "challenges"
    
    private var messageListeners: [String: ListenerRegistration] = [:]
    private var chatListeners: [String: ListenerRegistration] = [:]
    
    private let encryptionService = ChatEncryptionService.shared
    
    private init() {}
    
    func getOrCreateChat(user1Id: String, user2Id: String) async throws -> FriendChat {
        let chatId = FriendChat.deterministicId(user1: user1Id, user2: user2Id)
        
        let docRef = db.collection(chatsCollection).document(chatId)
        let doc = try await docRef.getDocument()
        
        if doc.exists, let data = doc.data(), let chat = FriendChat.fromDictionary(data, id: chatId) {
            return chat
        }
        
        let newChat = FriendChat(
            id: chatId,
            participantIds: [user1Id, user2Id],
            encryptionInitialized: false
        )
        
        try await docRef.setData(newChat.toDictionary())
        
        return newChat
    }
    
    func getChat(chatId: String) async throws -> FriendChat? {
        let doc = try await db.collection(chatsCollection).document(chatId).getDocument()
        guard let data = doc.data() else { return nil }
        return FriendChat.fromDictionary(data, id: chatId)
    }
    
    func initializeEncryption(chatId: String, currentUserId: String, otherUserId: String) async throws {
        let publicKey = try await encryptionService.getPublicKey()
        
        try await db.collection(userKeysCollection).document(currentUserId).setData([
            "user_id": currentUserId,
            "public_key": publicKey.base64EncodedString(),
            "created_at": Timestamp(date: Date()),
            "device_id": UUID().uuidString
        ], merge: true)
        
        let otherUserKeyDoc = try await db.collection(userKeysCollection).document(otherUserId).getDocument()
        
        if let data = otherUserKeyDoc.data(),
           let publicKeyBase64 = data["public_key"] as? String,
           let publicKeyData = Data(base64Encoded: publicKeyBase64) {
            try await encryptionService.storeRemotePublicKey(publicKeyData, forUserId: otherUserId)
            
            try await db.collection(chatsCollection).document(chatId).updateData([
                "encryption_initialized": true
            ])
        }
    }
    
    func sendMessage(
        chatId: String,
        senderId: String,
        recipientId: String,
        content: String,
        type: FriendChatMessageType = .text,
        payload: MessagePayload? = nil,
        replyToId: String? = nil
    ) async throws -> FriendChatMessage {
        let (encryptedContent, iv) = try await encryptionService.encryptToBase64(
            message: content,
            withUserId: recipientId,
            chatId: chatId
        )
        
        let messageId = UUID().uuidString
        let message = FriendChatMessage(
            id: messageId,
            senderId: senderId,
            type: type,
            encryptedContent: encryptedContent,
            iv: iv,
            payload: payload,
            timestamp: Date(),
            status: .sent,
            replyToId: replyToId
        )
        
        let messageRef = db.collection(chatsCollection)
            .document(chatId)
            .collection(messagesSubcollection)
            .document(messageId)
        
        try await messageRef.setData(message.toDictionary())
        
        let lastMessage = LastMessagePreview(
            senderId: senderId,
            encryptedPreview: String(encryptedContent.prefix(50)),
            timestamp: message.timestamp,
            type: type
        )
        
        try await db.collection(chatsCollection).document(chatId).updateData([
            "last_message": lastMessage.toDictionary(),
            "updated_at": Timestamp(date: Date())
        ])
        
        return message
    }
    
    func fetchMessages(chatId: String, currentUserId: String, limit: Int = 50, before: Date? = nil) async throws -> [FriendChatMessage] {
        guard let chat = try await getChat(chatId: chatId) else {
            throw ChatServiceError.chatNotFound
        }
        
        guard let otherUserId = chat.otherParticipantId(currentUserId: currentUserId) else {
            throw ChatServiceError.invalidParticipants
        }
        
        var query = db.collection(chatsCollection)
            .document(chatId)
            .collection(messagesSubcollection)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
        
        if let before = before {
            query = query.whereField("timestamp", isLessThan: Timestamp(date: before))
        }
        
        let snapshot = try await query.getDocuments()
        
        var messages: [FriendChatMessage] = []
        
        for doc in snapshot.documents {
            guard var message = FriendChatMessage.fromDictionary(doc.data(), id: doc.documentID) else {
                continue
            }
            
            if message.senderId != currentUserId {
                do {
                    let decrypted = try await encryptionService.decryptFromBase64(
                        encryptedContent: message.encryptedContent,
                        iv: message.iv,
                        withUserId: otherUserId,
                        chatId: chatId
                    )
                    message.decryptedContent = decrypted
                } catch {
                    message.decryptedContent = "[Unable to decrypt]"
                }
            } else {
                do {
                    let decrypted = try await encryptionService.decryptFromBase64(
                        encryptedContent: message.encryptedContent,
                        iv: message.iv,
                        withUserId: otherUserId,
                        chatId: chatId
                    )
                    message.decryptedContent = decrypted
                } catch {
                    message.decryptedContent = "[Unable to decrypt]"
                }
            }
            
            messages.append(message)
        }
        
        return messages.reversed()
    }
    
    func updateTypingStatus(chatId: String, userId: String, isTyping: Bool) async throws {
        let update: [String: Any]
        if isTyping {
            update = ["typing_status.\(userId)": Timestamp(date: Date())]
        } else {
            update = ["typing_status.\(userId)": FieldValue.delete()]
        }
        
        try await db.collection(chatsCollection).document(chatId).updateData(update)
    }
    
    func markMessageAsRead(chatId: String, messageId: String) async throws {
        try await db.collection(chatsCollection)
            .document(chatId)
            .collection(messagesSubcollection)
            .document(messageId)
            .updateData([
                "status": MessageStatus.read.rawValue,
                "read_at": Timestamp(date: Date())
            ])
    }
    
    func markMessagesAsDelivered(chatId: String, messageIds: [String]) async throws {
        let batch = db.batch()
        
        for messageId in messageIds {
            let ref = db.collection(chatsCollection)
                .document(chatId)
                .collection(messagesSubcollection)
                .document(messageId)
            
            batch.updateData(["status": MessageStatus.delivered.rawValue], forDocument: ref)
        }
        
        try await batch.commit()
    }
    
    func getChatsForUser(userId: String) async throws -> [FriendChat] {
        let snapshot = try await db.collection(chatsCollection)
            .whereField("participant_ids", arrayContains: userId)
            .order(by: "updated_at", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            FriendChat.fromDictionary(doc.data(), id: doc.documentID)
        }
    }
    
    func createChallenge(
        chatId: String,
        challengerId: String,
        challengedId: String,
        type: ChallengeType,
        target: Int,
        durationDays: Int
    ) async throws -> Challenge {
        let challenge = Challenge(
            chatId: chatId,
            challengerId: challengerId,
            challengedId: challengedId,
            type: type,
            target: target,
            durationDays: durationDays
        )
        
        try await db.collection(chatsCollection)
            .document(chatId)
            .collection(challengesSubcollection)
            .document(challenge.id)
            .setData(challenge.toDictionary())
        
        return challenge
    }
    
    func respondToChallenge(chatId: String, challengeId: String, accept: Bool) async throws {
        let newStatus: ChallengeStatus = accept ? .active : .declined
        
        try await db.collection(chatsCollection)
            .document(chatId)
            .collection(challengesSubcollection)
            .document(challengeId)
            .updateData(["status": newStatus.rawValue])
    }
    
    func updateChallengeProgress(chatId: String, challengeId: String, userId: String, progress: Int) async throws {
        try await db.collection(chatsCollection)
            .document(chatId)
            .collection(challengesSubcollection)
            .document(challengeId)
            .updateData(["progress.\(userId)": progress])
    }
    
    func getActiveChallenges(chatId: String) async throws -> [Challenge] {
        let snapshot = try await db.collection(chatsCollection)
            .document(chatId)
            .collection(challengesSubcollection)
            .whereField("status", isEqualTo: ChallengeStatus.active.rawValue)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            Challenge.fromDictionary(doc.data(), id: doc.documentID)
        }
    }
    
    // MARK: - Image Upload
    
    func uploadImage(imageData: Data, chatId: String, senderId: String) async throws -> String {
        let storage = Storage.storage()
        let imageId = UUID().uuidString
        let path = "chat_images/\(chatId)/\(imageId).jpg"
        let storageRef = storage.reference().child(path)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    func sendImageMessage(
        chatId: String,
        senderId: String,
        recipientId: String,
        imageData: Data
    ) async throws -> FriendChatMessage {
        let imageUrl = try await uploadImage(imageData: imageData, chatId: chatId, senderId: senderId)
        
        let payload = MessagePayload(imageUrl: imageUrl)
        
        return try await sendMessage(
            chatId: chatId,
            senderId: senderId,
            recipientId: recipientId,
            content: "[Image]",
            type: .image,
            payload: payload
        )
    }
    
    func removeMessageListener(chatId: String) {
        messageListeners[chatId]?.remove()
        messageListeners.removeValue(forKey: chatId)
    }
    
    func removeChatListener(chatId: String) {
        chatListeners[chatId]?.remove()
        chatListeners.removeValue(forKey: chatId)
    }
    
    func removeAllListeners() {
        for (_, listener) in messageListeners {
            listener.remove()
        }
        messageListeners.removeAll()
        
        for (_, listener) in chatListeners {
            listener.remove()
        }
        chatListeners.removeAll()
    }
}

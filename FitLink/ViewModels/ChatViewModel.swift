import SwiftUI
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var messages: [FriendChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var isSending: Bool = false
    @Published var isOtherUserTyping: Bool = false
    @Published var errorMessage: String?
    @Published var chat: FriendChat?
    @Published var otherUser: User?
    
    // MARK: - Private Properties
    
    private let chatService = ChatService.shared
    private let friendService = FriendService.shared
    private let encryptionService = ChatEncryptionService.shared
    
    let currentUserId: String
    let friendId: String
    let chatId: String
    
    private var cancellables = Set<AnyCancellable>()
    private var typingDebounceTask: Task<Void, Never>?
    private var lastTypingUpdate: Date?
    
    // MARK: - Initialization
    
    init(currentUserId: String, friendId: String) {
        self.currentUserId = currentUserId
        self.friendId = friendId
        self.chatId = FriendChat.deterministicId(user1: currentUserId, user2: friendId)
        
        setupTypingDebounce()
        
        Task {
            await initializeChat()
        }
    }
    
    // MARK: - Setup
    
    private func setupTypingDebounce() {
        $inputText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                let shouldType = !text.isEmpty
                Task {
                    await self.updateTypingStatus(isTyping: shouldType)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Chat Initialization
    
    func initializeChat() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let chatResult = try await chatService.getOrCreateChat(user1Id: currentUserId, user2Id: friendId)
            self.chat = chatResult
            
            if !chatResult.encryptionInitialized {
                try await chatService.initializeEncryption(
                    chatId: chatId,
                    currentUserId: currentUserId,
                    otherUserId: friendId
                )
            }
            
            await loadMessages()
            
        } catch {
            errorMessage = ErrorHandler.shared.handle(error, context: "initializeChat").userMessage
        }
    }
    
    // MARK: - Message Operations
    
    func loadMessages() async {
        do {
            let fetchedMessages = try await chatService.fetchMessages(
                chatId: chatId,
                currentUserId: currentUserId,
                limit: 50
            )
            self.messages = fetchedMessages
            
            await markMessagesAsRead()
        } catch {
            errorMessage = ErrorHandler.shared.handle(error, context: "loadMessages").userMessage
        }
    }
    
    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        isSending = true
        let messageText = text
        inputText = ""
        
        do {
            await updateTypingStatus(isTyping: false)
            
            let message = try await chatService.sendMessage(
                chatId: chatId,
                senderId: currentUserId,
                recipientId: friendId,
                content: messageText
            )
            
            var messageWithContent = message
            messageWithContent.decryptedContent = messageText
            messages.append(messageWithContent)
            
        } catch {
            inputText = messageText
            errorMessage = ErrorHandler.shared.handle(error, context: "sendMessage").userMessage
        }
        
        isSending = false
    }
    
    func sendReply(to replyToId: String) async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        isSending = true
        let messageText = text
        inputText = ""
        
        do {
            await updateTypingStatus(isTyping: false)
            
            let message = try await chatService.sendMessage(
                chatId: chatId,
                senderId: currentUserId,
                recipientId: friendId,
                content: messageText,
                replyToId: replyToId
            )
            
            var messageWithContent = message
            messageWithContent.decryptedContent = messageText
            messages.append(messageWithContent)
            
        } catch {
            inputText = messageText
            errorMessage = ErrorHandler.shared.handle(error, context: "sendReply").userMessage
        }
        
        isSending = false
    }
    
    func sendImage(imageData: Data) async {
        isSending = true
        
        do {
            let message = try await chatService.sendImageMessage(
                chatId: chatId,
                senderId: currentUserId,
                recipientId: friendId,
                imageData: imageData
            )
            
            var messageWithContent = message
            messageWithContent.decryptedContent = "[Image]"
            messages.append(messageWithContent)
            
        } catch {
            errorMessage = ErrorHandler.shared.handle(error, context: "sendImage").userMessage
        }
        
        isSending = false
    }
    
    private func markMessagesAsRead() async {
        let unreadMessages = messages.filter {
            $0.senderId != currentUserId && $0.status != .read
        }
        
        for message in unreadMessages {
            do {
                try await chatService.markMessageAsRead(chatId: chatId, messageId: message.id)
            } catch {
                ErrorHandler.shared.log("Failed to mark message as read", severity: .warning, context: "ChatViewModel")
            }
        }
    }
    
    // MARK: - Typing Status
    
    func updateTypingStatus(isTyping: Bool) async {
        if let lastUpdate = lastTypingUpdate,
           Date().timeIntervalSince(lastUpdate) < 2.0 && isTyping {
            return
        }
        
        lastTypingUpdate = Date()
        
        do {
            try await chatService.updateTypingStatus(chatId: chatId, userId: currentUserId, isTyping: isTyping)
        } catch {
            ErrorHandler.shared.log("Failed to update typing status", severity: .warning, context: "ChatViewModel")
        }
    }
    
    // MARK: - Helper Methods
    
    func getDisplayContent(for message: FriendChatMessage) -> String {
        if let decrypted = message.decryptedContent {
            return decrypted
        }
        return "[Encrypted]"
    }
    
    func isFromCurrentUser(_ message: FriendChatMessage) -> Bool {
        message.senderId == currentUserId
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        Task {
            await updateTypingStatus(isTyping: false)
            await chatService.removeMessageListener(chatId: chatId)
            await chatService.removeChatListener(chatId: chatId)
        }
    }
    
    deinit {
        typingDebounceTask?.cancel()
    }
}

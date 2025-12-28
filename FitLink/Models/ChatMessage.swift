import Foundation

// MARK: - Chat Role

enum ChatRole: String, Codable {
    case user
    case assistant
}

// MARK: - Assistant Response Type

enum AssistantResponseType: String, Codable {
    case question   // LLM is asking a follow-up question
    case ready      // LLM has enough info to generate plan
}

// MARK: - Chat Message

struct ChatMessage: Identifiable, Codable, Hashable {
    var id: String
    var role: ChatRole
    var content: String
    var responseType: AssistantResponseType?  // Only for assistant messages
    var timestamp: Date
    
    init(
        id: String = UUID().uuidString,
        role: ChatRole,
        content: String,
        responseType: AssistantResponseType? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.responseType = responseType
        self.timestamp = timestamp
    }
    
    // Convenience initializers
    static func user(_ content: String) -> ChatMessage {
        ChatMessage(role: .user, content: content)
    }
    
    static func assistant(_ content: String, type: AssistantResponseType) -> ChatMessage {
        ChatMessage(role: .assistant, content: content, responseType: type)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case responseType = "response_type"
        case timestamp
    }
}

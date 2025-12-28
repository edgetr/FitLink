import Foundation
import Combine

// MARK: - Plan Generation State Machine
enum PlanGenerationState: Equatable {
    case idle
    case loading
    case conversing
    case ready
    case generating(progress: Double)
    case completed
    case failed(PlanGenerationError)
    
    var isActive: Bool {
        switch self {
        case .conversing, .ready, .generating:
            return true
        default:
            return false
        }
    }
    
    var isTerminal: Bool {
        switch self {
        case .completed, .failed:
            return true
        default:
            return false
        }
    }
    
    var canSendMessage: Bool {
        self == .conversing
    }
    
    var canStartGeneration: Bool {
        self == .ready
    }
    
    var displayProgress: Double {
        if case .generating(let progress) = self {
            return progress
        }
        return 0
    }
}

// MARK: - Plan Generation Error

enum PlanGenerationError: LocalizedError, Equatable {
    case userNotAuthenticated
    case emptyPreferences
    case networkError(String)
    case parsingError(String)
    case validationFailed([String])
    case insufficientData([String])
    case serviceError(String)
    case cancelled
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "Please sign in to generate plans."
        case .emptyPreferences:
            return "Please enter your preferences."
        case .networkError(let message):
            return "Network error: \(message)"
        case .parsingError:
            return "Failed to parse AI response. Please try again."
        case .validationFailed(let fields):
            return "Validation failed: \(fields.prefix(3).joined(separator: ", "))"
        case .insufficientData(let fields):
            return "Could not generate complete plan. Missing: \(fields.prefix(3).joined(separator: ", "))"
        case .serviceError(let message):
            return message
        case .cancelled:
            return "Generation was cancelled."
        case .unknown(let message):
            return message
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkError, .parsingError, .serviceError:
            return true
        default:
            return false
        }
    }
}

// MARK: - Conversation Persistence Keys

struct ConversationPersistenceKeys {
    let prefix: String
    
    var chatMessages: String { "\(prefix)_chat_messages" }
    var generationId: String { "\(prefix)_generation_id" }
    var preferences: String { "\(prefix)_preferences" }
    var readySummary: String { "\(prefix)_ready_summary" }
    var isReady: String { "\(prefix)_is_ready" }
    var isGenerating: String { "\(prefix)_is_generating" }
    var currentProgress: String { "\(prefix)_current_progress" }
    
    static let diet = ConversationPersistenceKeys(prefix: "diet_planner")
    static let workout = ConversationPersistenceKeys(prefix: "workout_planner")
}

// MARK: - Conversation Persistence Utility

final class ConversationPersistence {
    
    private let keys: ConversationPersistenceKeys
    private let defaults: UserDefaults
    
    init(keys: ConversationPersistenceKeys, defaults: UserDefaults = .standard) {
        self.keys = keys
        self.defaults = defaults
    }
    
    // MARK: - Save
    
    func save(
        messages: [ChatMessage],
        generationId: String?,
        preferences: String,
        readySummary: String?,
        state: PlanGenerationState
    ) {
        if let data = try? JSONEncoder().encode(messages) {
            defaults.set(data, forKey: keys.chatMessages)
        }
        
        defaults.set(generationId, forKey: keys.generationId)
        defaults.set(preferences, forKey: keys.preferences)
        defaults.set(readySummary, forKey: keys.readySummary)
        defaults.set(state == .ready, forKey: keys.isReady)
        
        if case .generating(let progress) = state {
            defaults.set(true, forKey: keys.isGenerating)
            defaults.set(progress, forKey: keys.currentProgress)
        } else {
            defaults.set(false, forKey: keys.isGenerating)
            defaults.set(0.0, forKey: keys.currentProgress)
        }
        
        appLog("Conversation state saved", level: .debug, category: .ai)
    }
    
    // MARK: - Restore
    
    struct RestoredState {
        let messages: [ChatMessage]
        let generationId: String?
        let preferences: String
        let readySummary: String?
        let state: PlanGenerationState
    }
    
    func restore() -> RestoredState? {
        guard let data = defaults.data(forKey: keys.chatMessages),
              let messages = try? JSONDecoder().decode([ChatMessage].self, from: data),
              !messages.isEmpty else {
            return nil
        }
        
        let generationId = defaults.string(forKey: keys.generationId)
        let preferences = defaults.string(forKey: keys.preferences) ?? ""
        let readySummary = defaults.string(forKey: keys.readySummary)
        let isGenerating = defaults.bool(forKey: keys.isGenerating)
        let isReady = defaults.bool(forKey: keys.isReady)
        let progress = defaults.double(forKey: keys.currentProgress)
        
        let state: PlanGenerationState
        if isGenerating {
            state = .generating(progress: progress)
        } else if isReady {
            state = .ready
        } else {
            state = .conversing
        }
        
        appLog("Conversation state restored: \(messages.count) messages, state: \(state)", level: .debug, category: .ai)
        
        return RestoredState(
            messages: messages,
            generationId: generationId,
            preferences: preferences,
            readySummary: readySummary,
            state: state
        )
    }
    
    // MARK: - Clear
    
    func clear() {
        defaults.removeObject(forKey: keys.chatMessages)
        defaults.removeObject(forKey: keys.generationId)
        defaults.removeObject(forKey: keys.preferences)
        defaults.removeObject(forKey: keys.readySummary)
        defaults.removeObject(forKey: keys.isReady)
        defaults.removeObject(forKey: keys.isGenerating)
        defaults.removeObject(forKey: keys.currentProgress)
        
        appLog("Conversation state cleared", level: .debug, category: .ai)
    }
}

// MARK: - Plan Generation Coordinator Protocol

@MainActor
protocol PlanGenerationCoordinatorProtocol: ObservableObject {
    associatedtype PlanType
    
    var state: PlanGenerationState { get }
    var chatMessages: [ChatMessage] { get }
    var preferences: String { get set }
    var currentGenerationId: String? { get }
    var readySummary: String? { get }
    var errorMessage: String? { get }
    var isProcessingMessage: Bool { get }
    var messageCount: Int { get }
    var isAtMaxMessages: Bool { get }
    var canSendMessage: Bool { get }
    
    func startConversation(initialPrompt: String) async
    func sendMessage(_ text: String) async
    func requestMoreQuestions() async
    func startPlanGeneration() async
    func startOver()
    func checkPendingGenerations() async
}

// MARK: - Base Plan Generation Coordinator

@MainActor
class BasePlanGenerationCoordinator: ObservableObject {
    
    @Published private(set) var state: PlanGenerationState = .idle
    @Published private(set) var chatMessages: [ChatMessage] = []
    @Published var preferences: String = ""
    @Published private(set) var currentGenerationId: String?
    @Published private(set) var readySummary: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isProcessingMessage: Bool = false
    
    let geminiService: GeminiAIService
    let planGenerationService: PlanGenerationService
    let contextProvider: UserContextProvider
    let persistence: ConversationPersistence
    let planType: GenerationPlanType
    
    var userId: String?
    
    var messageCount: Int {
        chatMessages.filter { $0.role == .user }.count
    }
    
    var isAtMaxMessages: Bool {
        messageCount >= PendingGeneration.maxMessages
    }
    
    var canSendMessage: Bool {
        state.canSendMessage && !isProcessingMessage
    }
    
    init(
        planType: GenerationPlanType,
        persistenceKeys: ConversationPersistenceKeys,
        geminiService: GeminiAIService = GeminiAIService(),
        planGenerationService: PlanGenerationService = .shared,
        contextProvider: UserContextProvider = .shared
    ) {
        self.planType = planType
        self.geminiService = geminiService
        self.planGenerationService = planGenerationService
        self.contextProvider = contextProvider
        self.persistence = ConversationPersistence(keys: persistenceKeys)
        
        restoreConversationState()
    }
    
    func transition(to newState: PlanGenerationState) {
        let oldState = state
        state = newState
        
        appLog("State transition: \(oldState) -> \(newState)", level: .debug, category: .ai)
        
        if case .failed(let error) = newState {
            errorMessage = error.errorDescription
            ErrorHandler.shared.log(
                "Plan generation failed: \(error.errorDescription ?? "Unknown")",
                severity: .error,
                context: "PlanGenerationCoordinator"
            )
        }
        
        saveConversationState()
    }
    
    func updateProgress(_ progress: Double) {
        if case .generating = state {
            state = .generating(progress: progress)
        }
    }
    
    func appendUserMessage(_ content: String) {
        let message = ChatMessage.user(content)
        chatMessages.append(message)
    }
    
    func appendAssistantMessage(_ content: String, type: AssistantResponseType) {
        let message = ChatMessage.assistant(content, type: type)
        chatMessages.append(message)
    }
    
    func removeLastMessage() {
        if !chatMessages.isEmpty {
            chatMessages.removeLast()
        }
    }
    
    func saveConversationState() {
        persistence.save(
            messages: chatMessages,
            generationId: currentGenerationId,
            preferences: preferences,
            readySummary: readySummary,
            state: state
        )
    }
    
    func restoreConversationState() {
        guard let restored = persistence.restore() else { return }
        
        chatMessages = restored.messages
        currentGenerationId = restored.generationId
        preferences = restored.preferences
        readySummary = restored.readySummary
        state = restored.state
    }
    
    func clearConversationState() {
        persistence.clear()
        chatMessages = []
        currentGenerationId = nil
        readySummary = nil
        preferences = ""
        errorMessage = nil
        state = .idle
    }
    
    func handleError(_ error: Error, context: String) {
        let appError = ErrorHandler.shared.handle(error, context: context)
        let planError = mapToPlanGenerationError(error)
        
        transition(to: .failed(planError))
        
        appLog("Error in \(context): \(appError.userMessage)", level: .error, category: .ai)
    }
    
    private func mapToPlanGenerationError(_ error: Error) -> PlanGenerationError {
        if let apiError = error as? GeminiAIService.APIError {
            return .serviceError(apiError.errorDescription ?? "AI service error")
        }
        
        if error is DecodingError {
            return .parsingError("Failed to parse AI response")
        }
        
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .networkError(nsError.localizedDescription)
        }
        
        return .unknown(error.localizedDescription)
    }
    
    func fetchUserContext() async -> String? {
        guard let userId = userId else { return nil }
        
        do {
            let context = try await contextProvider.getContext(for: userId)
            return context.formatForPrompt()
        } catch {
            appLog("Failed to fetch user context: \(error)", level: .warning, category: .ai)
            return nil
        }
    }
    
    func buildEnhancedPreferences(with context: String?) -> String {
        guard let context = context, !context.isEmpty else {
            return preferences
        }
        return "USER CONTEXT:\n\(context)\n\nUSER REQUEST:\n\(preferences)"
    }
    
    func setGenerationId(_ id: String) {
        currentGenerationId = id
    }
    
    func setReadySummary(_ summary: String?) {
        readySummary = summary
    }
    
    func setProcessingMessage(_ processing: Bool) {
        isProcessingMessage = processing
    }
    
    func startOver() {
        clearConversationState()
    }
}

// MARK: - Validation Result Protocol

protocol PlanValidationResult {
    var isValid: Bool { get }
    var completeness: Double { get }
    var missingFields: [String] { get }
}

// MARK: - Plan Validation Coordinator

struct PlanValidationCoordinator {
    
    static let partialSuccessThreshold = 0.70
    
    struct ValidationOutcome {
        let isValid: Bool
        let isPartialSuccess: Bool
        let completeness: Double
        let missingFields: [String]
        let shouldPersist: Bool
        
        var displayMessage: String? {
            if isValid {
                return nil
            } else if isPartialSuccess {
                return "Plan generated with \(missingFields.count) items using default values"
            } else {
                return "Plan generation failed: \(missingFields.prefix(3).joined(separator: ", "))"
            }
        }
    }
    
    static func evaluate(
        isValid: Bool,
        completeness: Double,
        missingFields: [String]
    ) -> ValidationOutcome {
        let isPartialSuccess = !isValid && completeness >= partialSuccessThreshold
        let shouldPersist = isValid || isPartialSuccess
        
        return ValidationOutcome(
            isValid: isValid,
            isPartialSuccess: isPartialSuccess,
            completeness: completeness,
            missingFields: missingFields,
            shouldPersist: shouldPersist
        )
    }
}

import Foundation

// MARK: - Conversational Response Structure

struct ConversationalResponse: Decodable {
    let type: String        // "question" or "ready"
    let message: String     // The message to display to user
    let summary: String?    // Only present when type is "ready" - summarizes collected info
    
    var responseType: AssistantResponseType {
        type == "ready" ? .ready : .question
    }
}

// MARK: - Model and Thinking Level Enums

enum GeminiModel: String {
    case flash = "gemini-3-flash-preview"
    case pro = "gemini-3-pro-preview"
    
    var displayName: String {
        switch self {
        case .flash: return "Gemini 3 Flash"
        case .pro: return "Gemini 3 Pro"
        }
    }
    
    var maxOutputTokens: Int {
        switch self {
        case .flash: return 65536
        case .pro: return 65536
        }
    }
}

enum ThinkingLevel: String, Encodable {
    case none = "none"           // No thinking (fastest)
    case minimal = "minimal"     // Flash only - very light
    case low = "low"             // Both models
    case medium = "medium"       // Flash only
    case high = "high"           // Both models - deepest reasoning
    
    var budgetTokens: Int? {
        switch self {
        case .none: return nil
        case .minimal: return 1024
        case .low: return 4096
        case .medium: return 8192
        case .high: return 24576
        }
    }
}

// MARK: - Task Types for Model Selection

enum AITaskType {
    case workoutPlanGeneration
    case dietPlanGeneration
    case conversationalGathering
    case clarifyingQuestions
    case planAdjustment
    case recipeSuggestion
    case exerciseAlternative
    
    var recommendedConfig: (model: GeminiModel, thinking: ThinkingLevel) {
        switch self {
        case .workoutPlanGeneration:
            return (.pro, .high)
        case .dietPlanGeneration:
            return (.pro, .high)
        case .conversationalGathering:
            return (.flash, .minimal)
        case .clarifyingQuestions:
            return (.flash, .minimal)
        case .planAdjustment:
            return (.flash, .medium)
        case .recipeSuggestion:
            return (.flash, .low)
        case .exerciseAlternative:
            return (.flash, .low)
        }
    }
    
    var maxTokens: Int {
        switch self {
        case .workoutPlanGeneration, .dietPlanGeneration:
            return 32000  // Large output for full 7-day plans
        case .planAdjustment:
            return 16000
        case .conversationalGathering, .clarifyingQuestions:
            return 2000
        case .recipeSuggestion, .exerciseAlternative:
            return 4000
        }
    }
    
    var temperature: Double {
        switch self {
        case .workoutPlanGeneration, .dietPlanGeneration:
            return 1.0  // Balanced creativity for varied plans
        case .conversationalGathering:
            return 0.7  // Slightly creative for natural conversation
        case .clarifyingQuestions:
            return 0.5  // More focused
        case .planAdjustment:
            return 0.8
        case .recipeSuggestion:
            return 0.9  // More creative
        case .exerciseAlternative:
            return 0.6  // More precise
        }
    }
}

// MARK: - Request Complexity Analysis

enum RequestComplexity {
    case clarifyingQuestions
    case simplePlan
    case complexPlan
    
    static func analyze(preferences: String) -> RequestComplexity {
        let lowercased = preferences.lowercased()
        let complexKeywords = [
            "allergy", "allergies", "diabetes", "keto", "celiac",
            "multiple", "restrictions", "medical", "condition",
            "gluten-free", "dairy-free", "vegan", "paleo",
            "low-sodium", "nut-free", "intolerance", "autoimmune"
        ]
        let matchCount = complexKeywords.filter { lowercased.contains($0) }.count
        
        if matchCount >= 2 {
            return .complexPlan
        }
        return .simplePlan
    }
}

// MARK: - User Context (Structured Context Management)

struct UserContext: Encodable {
    let preferences: String
    let clarificationAnswers: [String: String]?
    let userProfile: AIUserProfile?
}

struct AIUserProfile: Encodable {
    let fitnessLevel: String?
    let dietaryRestrictions: [String]?
    let healthGoals: [String]?
}

// MARK: - GeminiAIService

actor GeminiAIService {
    
    enum APIError: LocalizedError {
        case invalidResponse
        case timeout
        case rateLimited
        case serverError(Int)
        case parseError(String)
        case networkError(Error)
        case noAPIKey
        case invalidURL
        
        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid response from AI service."
            case .timeout:
                return "Request timed out. Please try again."
            case .rateLimited:
                return "Too many requests. Please wait a moment and try again."
            case .serverError(let code):
                return "Server error (code: \(code)). Please try again later."
            case .parseError(let detail):
                return "Failed to parse AI response: \(detail)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .noAPIKey:
                return "API key not configured. Please check your settings."
            case .invalidURL:
                return "Invalid API URL configuration."
            }
        }
    }
    
    // MARK: - Request/Response Structures
    
    private struct GeminiRequest: Encodable {
        let contents: [Content]
        let generationConfig: GenerationConfig?
        let systemInstruction: Content?
        
        struct Content: Encodable {
            let role: String?
            let parts: [Part]
        }
        
        struct Part: Encodable {
            let text: String
        }
        
        struct GenerationConfig: Encodable {
            let temperature: Double?
            let topP: Double?
            let topK: Int?
            let maxOutputTokens: Int?
            let responseMimeType: String?
            let thinkingConfig: ThinkingConfig?
            
            enum CodingKeys: String, CodingKey {
                case temperature
                case topP = "top_p"
                case topK = "top_k"
                case maxOutputTokens = "max_output_tokens"
                case responseMimeType = "response_mime_type"
                case thinkingConfig = "thinking_config"
            }
        }
        
        struct ThinkingConfig: Encodable {
            let thinkingBudget: Int?
            
            enum CodingKeys: String, CodingKey {
                case thinkingBudget = "thinking_budget"
            }
            
            init(level: ThinkingLevel) {
                self.thinkingBudget = level.budgetTokens
            }
        }
    }
    
    private struct GeminiResponse: Decodable {
        let candidates: [Candidate]?
        let error: GeminiError?
        let usageMetadata: UsageMetadata?
        
        struct Candidate: Decodable {
            let content: Content?
            let finishReason: String?
        }
        
        struct Content: Decodable {
            let parts: [Part]?
            let role: String?
        }
        
        struct Part: Decodable {
            let text: String?
        }
        
        struct GeminiError: Decodable {
            let message: String
            let status: String?
            let code: Int?
        }
        
        struct UsageMetadata: Decodable {
            let promptTokenCount: Int?
            let candidatesTokenCount: Int?
            let totalTokenCount: Int?
            let thoughtsTokenCount: Int?  // NEW: Track thinking tokens
        }
    }
    
    // MARK: - Properties
    
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    private let session: URLSession
    private let maxRetries = 3
    private let retryDelayBase: TimeInterval = 1.0
    
    // MARK: - Initialization
    
    init(apiKey: String) {
        self.apiKey = apiKey
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 180
        self.session = URLSession(configuration: config)
    }
    
    init() {
        let key = ConfigurationManager.shared.geminiAPIKey ?? ""
        self.apiKey = key
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 180
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Smart Routing
    
    static func recommendedModel(for request: RequestComplexity) -> (GeminiModel, ThinkingLevel) {
        switch request {
        case .clarifyingQuestions:
            return (.flash, .minimal)
        case .simplePlan:
            return (.flash, .medium)
        case .complexPlan:
            return (.pro, .high)
        }
    }
    
    // MARK: - Main API Methods
    
    func sendPrompt(
        _ prompt: String,
        systemPrompt: String,
        model: GeminiModel = .flash,
        thinkingLevel: ThinkingLevel = .medium,
        maxTokens: Int = 16000,
        temperature: Double = 1.0,
        jsonMode: Bool = true
    ) async throws -> String {
        guard !apiKey.isEmpty else {
            throw APIError.noAPIKey
        }
        
        let urlString = "\(baseURL)/\(model.rawValue):generateContent"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let request = GeminiRequest(
            contents: [
                .init(role: "user", parts: [.init(text: prompt)])
            ],
            generationConfig: .init(
                temperature: temperature,
                topP: nil,  // Let Gemini 3 use its defaults
                topK: nil,  // Let Gemini 3 use its defaults
                maxOutputTokens: maxTokens,
                responseMimeType: jsonMode ? "application/json" : nil,
                thinkingConfig: .init(level: thinkingLevel)
            ),
            systemInstruction: .init(role: "user", parts: [.init(text: systemPrompt)])
        )
        
        return try await sendWithRetry(url: url, request: request, model: model, attempt: 1)
    }
    
    func askClarifyingQuestions(_ prompt: String) async throws -> String {
        let systemPrompt = """
        You are an assistant that determines if more information is needed to create a meal plan.
        Always respond with valid JSON only. No markdown, no explanatory text.
        """
        
        return try await sendPrompt(
            prompt,
            systemPrompt: systemPrompt,
            model: .flash,
            thinkingLevel: .minimal,
            maxTokens: 2000,
            temperature: 0.5
        )
    }
    
    func sendPromptWithContext(
        _ prompt: String,
        systemPrompt: String,
        userContext: LLMUserContext,
        model: GeminiModel = .flash,
        thinkingLevel: ThinkingLevel = .medium,
        maxTokens: Int = 16000,
        temperature: Double = 1.0,
        jsonMode: Bool = true
    ) async throws -> String {
        let contextualPrompt = userContext.formatForPrompt() + "\n\n" + prompt
        
        return try await sendPrompt(
            contextualPrompt,
            systemPrompt: systemPrompt,
            model: model,
            thinkingLevel: thinkingLevel,
            maxTokens: maxTokens,
            temperature: temperature,
            jsonMode: jsonMode
        )
    }
    
    // MARK: - Task-Based API (Primary Interface)
    
    /// Send a prompt with automatic model/thinking selection based on task type
    func sendTask(
        _ prompt: String,
        systemPrompt: String,
        taskType: AITaskType,
        userContext: LLMUserContext? = nil,
        jsonMode: Bool = true
    ) async throws -> String {
        let config = taskType.recommendedConfig
        
        // Build contextual prompt if context provided
        var fullPrompt = prompt
        if let context = userContext {
            fullPrompt = context.formatForPrompt() + "\n\n" + prompt
        }
        
        return try await sendPrompt(
            fullPrompt,
            systemPrompt: systemPrompt,
            model: config.model,
            thinkingLevel: config.thinking,
            maxTokens: taskType.maxTokens,
            temperature: taskType.temperature,
            jsonMode: jsonMode
        )
    }
    
    // MARK: - Plan Generation (Pro + High Thinking)
    
    func generateWorkoutPlan(
        preferences: String,
        userContext: LLMUserContext,
        planType: WorkoutPlanType
    ) async throws -> String {
        let instructions = ContextAwarePromptBuilder.workoutPlanInstructions(from: userContext)
        
        let prompt: String
        switch planType {
        case .home:
            prompt = WorkoutPromptBuilder.buildHomePlanPrompt(
                preferences: preferences,
                additionalContext: [:]
            )
        case .gym:
            prompt = WorkoutPromptBuilder.buildGymPlanPrompt(
                preferences: preferences,
                additionalContext: [:]
            )
        }
        
        let systemPrompt = """
        \(WorkoutPromptBuilder.systemPrompt)
        
        \(instructions)
        """
        
        return try await sendTask(
            prompt,
            systemPrompt: systemPrompt,
            taskType: .workoutPlanGeneration,
            userContext: userContext
        )
    }
    
    func generateDietPlan(
        preferences: String,
        userContext: LLMUserContext
    ) async throws -> String {
        let instructions = ContextAwarePromptBuilder.dietPlanInstructions(from: userContext)
        
        let prompt = DietPlannerSystemPrompt.buildUserPrompt(preferences: preferences)
        
        let systemPrompt = """
        \(DietPlannerSystemPrompt.systemPrompt)
        
        \(instructions)
        """
        
        return try await sendTask(
            prompt,
            systemPrompt: systemPrompt,
            taskType: .dietPlanGeneration,
            userContext: userContext
        )
    }
    
    // MARK: - Plan Generation with Fallback
    
    /// If Pro fails, fallback to Flash with high thinking
    func generatePlanWithFallback(
        taskType: AITaskType,
        prompt: String,
        systemPrompt: String,
        userContext: LLMUserContext
    ) async throws -> String {
        do {
            // Try primary (Pro + High)
            return try await sendTask(
                prompt,
                systemPrompt: systemPrompt,
                taskType: taskType,
                userContext: userContext
            )
        } catch {
            log("Pro model failed, falling back to Flash: \(error)")
            
            // Fallback to Flash + High
            return try await sendPrompt(
                userContext.formatForPrompt() + "\n\n" + prompt,
                systemPrompt: systemPrompt,
                model: .flash,
                thinkingLevel: .high,
                maxTokens: taskType.maxTokens,
                temperature: taskType.temperature
            )
        }
    }
    
    // MARK: - Retry Logic
    
    private func sendWithRetry(url: URL, request: GeminiRequest, model: GeminiModel, attempt: Int) async throws -> String {
        do {
            return try await performRequest(url: url, request: request, model: model)
        } catch let error as APIError {
            switch error {
            case .noAPIKey, .invalidURL, .parseError:
                throw error
            case .rateLimited where attempt < maxRetries:
                let delay = retryDelayBase * pow(2.0, Double(attempt - 1))
                log("Rate limited, retrying in \(delay)s (attempt \(attempt)/\(maxRetries))")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await sendWithRetry(url: url, request: request, model: model, attempt: attempt + 1)
            case .serverError, .timeout, .networkError:
                if attempt < maxRetries {
                    let delay = retryDelayBase * pow(2.0, Double(attempt - 1))
                    log("Request failed, retrying in \(delay)s (attempt \(attempt)/\(maxRetries))")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await sendWithRetry(url: url, request: request, model: model, attempt: attempt + 1)
                }
                throw error
            default:
                throw error
            }
        } catch {
            if attempt < maxRetries {
                let delay = retryDelayBase * pow(2.0, Double(attempt - 1))
                log("Request failed with error: \(error), retrying in \(delay)s")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await sendWithRetry(url: url, request: request, model: model, attempt: attempt + 1)
            }
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Request Execution
    
    private func performRequest(url: URL, request: GeminiRequest, model: GeminiModel) async throws -> String {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        log("Sending request to Gemini API (model: \(model.rawValue), thinking budget: \(request.generationConfig?.thinkingConfig?.thinkingBudget.map { String($0) } ?? "default"))...")
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        log("Received response with status code: \(httpResponse.statusCode)")
        
        switch httpResponse.statusCode {
        case 200...299:
            break
        case 429:
            throw APIError.rateLimited
        case 400:
            if let errorText = String(data: data, encoding: .utf8) {
                log("Bad Request: \(errorText)")
            }
            throw APIError.serverError(httpResponse.statusCode)
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)
        default:
            if let errorText = String(data: data, encoding: .utf8) {
                log("API Error: \(errorText)")
            }
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            let geminiResponse = try decoder.decode(GeminiResponse.self, from: data)
            
            if let error = geminiResponse.error {
                throw APIError.parseError(error.message)
            }
            
            guard let candidates = geminiResponse.candidates,
                  let firstCandidate = candidates.first,
                  let content = firstCandidate.content,
                  let parts = content.parts,
                  let firstPart = parts.first,
                  let text = firstPart.text else {
                throw APIError.parseError("No content in response")
            }
            
            if let usage = geminiResponse.usageMetadata {
                var tokenLog = "Tokens - prompt: \(usage.promptTokenCount ?? 0), response: \(usage.candidatesTokenCount ?? 0)"
                if let thoughtsTokens = usage.thoughtsTokenCount, thoughtsTokens > 0 {
                    tokenLog += ", thinking: \(thoughtsTokens)"
                }
                log(tokenLog)
            }
            
            log("Successfully parsed response (\(text.count) characters)")
            return text
        } catch let decodingError as DecodingError {
            log("Decoding error: \(decodingError)")
            if let rawResponse = String(data: data, encoding: .utf8) {
                log("Raw response: \(rawResponse.prefix(500))")
            }
            throw APIError.parseError(decodingError.localizedDescription)
        }
    }
    
    // MARK: - Utility Methods
    
    private func log(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [GeminiAIService] \(message)")
        #endif
    }
    
    static func extractJSON(from response: String) -> String {
        var content = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if content.hasPrefix("```json") {
            content = String(content.dropFirst(7))
        } else if content.hasPrefix("```") {
            content = String(content.dropFirst(3))
        }
        
        if content.hasSuffix("```") {
            content = String(content.dropLast(3))
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func isValidJSON(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Structured Context Building
    
    static func buildUserPrompt(context: UserContext) -> String {
        var sections: [String] = []
        sections.append("User Preferences: \(context.preferences)")
        
        if let answers = context.clarificationAnswers, !answers.isEmpty {
            sections.append("Clarification Answers:")
            for (question, answer) in answers {
                sections.append("- \(question): \(answer)")
            }
        }
        
        if let profile = context.userProfile {
            if let restrictions = profile.dietaryRestrictions, !restrictions.isEmpty {
                sections.append("Dietary Restrictions: \(restrictions.joined(separator: ", "))")
            }
            if let goals = profile.healthGoals, !goals.isEmpty {
                sections.append("Health Goals: \(goals.joined(separator: ", "))")
            }
            if let fitnessLevel = profile.fitnessLevel {
                sections.append("Fitness Level: \(fitnessLevel)")
            }
        }
        
        return sections.joined(separator: "\n\n")
    }
    
    // MARK: - Conversational Chat Methods (Flash + Minimal Thinking)
    
    func sendDietConversation(
        conversationHistory: [ChatMessage],
        collectedContext: String,
        userContext: LLMUserContext? = nil,
        isForced: Bool = false
    ) async throws -> ConversationalResponse {
        let systemPrompt = buildDietConversationSystemPrompt(
            isForced: isForced,
            userContext: userContext
        )
        let userPrompt = buildConversationUserPrompt(
            history: conversationHistory,
            context: collectedContext
        )
        
        let response = try await sendTask(
            userPrompt,
            systemPrompt: systemPrompt,
            taskType: .conversationalGathering,
            userContext: nil,  // Context already in system prompt
            jsonMode: true
        )
        
        return try parseConversationalResponse(response)
    }
    
    func sendWorkoutConversation(
        conversationHistory: [ChatMessage],
        collectedContext: String,
        planTypes: [WorkoutPlanType],
        userContext: LLMUserContext? = nil,
        isForced: Bool = false
    ) async throws -> ConversationalResponse {
        let systemPrompt = buildWorkoutConversationSystemPrompt(
            planTypes: planTypes,
            isForced: isForced,
            userContext: userContext
        )
        let userPrompt = buildConversationUserPrompt(
            history: conversationHistory,
            context: collectedContext
        )
        
        let response = try await sendTask(
            userPrompt,
            systemPrompt: systemPrompt,
            taskType: .conversationalGathering,
            userContext: nil,  // Context already in system prompt
            jsonMode: true
        )
        
        return try parseConversationalResponse(response)
    }
    
    // MARK: - Context-Aware System Prompts
    
    private func buildDietConversationSystemPrompt(
        isForced: Bool,
        userContext: LLMUserContext?
    ) -> String {
        var prompt = ""
        
        // Add user context summary if available
        if let ctx = userContext {
            prompt += "USER BACKGROUND:\n"
            if let profile = ctx.profile {
                if !profile.dietaryRestrictions.isEmpty {
                    prompt += "- Known dietary restrictions: \(profile.dietaryRestrictions.joined(separator: ", "))\n"
                }
                if !profile.allergies.isEmpty {
                    prompt += "- Known allergies: \(profile.allergies.joined(separator: ", "))\n"
                }
                if let calories = profile.dailyCalorieTarget {
                    prompt += "- Calorie target: \(calories)\n"
                }
            }
            if let metrics = ctx.healthMetrics {
                prompt += "- Activity level: \(metrics.avgExerciseMinutes) min/day average\n"
                if let wake = metrics.typicalWakeTime {
                    prompt += "- Typically wakes at: \(wake.formatted)\n"
                }
            }
            prompt += "\n"
        }
        
        if isForced {
            prompt += """
            You are a nutrition assistant. The user has provided enough information.
            
            RESPOND WITH THIS EXACT JSON FORMAT:
            {
                "type": "ready",
                "message": "Great! I have everything I need to create your personalized meal plan.",
                "summary": "<Summarize what you learned about the user's dietary needs>"
            }
            """
        } else {
            prompt += """
            You are a friendly nutrition assistant gathering information to create a personalized 7-day meal plan.
            
            IMPORTANT: You already know some things about this user from their profile (shown above).
            DO NOT ask about things you already know. Focus on what's missing or unclear.
            
            BEHAVIOR RULES:
            1. Ask ONE focused, conversational question at a time
            2. Be warm and encouraging, not clinical
            3. Remember what the user already told you - don't repeat questions
            4. After gathering enough info (typically 2-4 exchanges if profile is complete), indicate you're ready
            5. You can be ready immediately if profile + initial message is comprehensive
            
            RESPOND WITH EXACTLY THIS JSON FORMAT:
            
            If you need more info:
            {"type": "question", "message": "<Your friendly question>"}
            
            If you have enough info:
            {"type": "ready", "message": "<Ready message>", "summary": "<Summary>"}
            """
        }
        
        return prompt
    }
    
    private func buildWorkoutConversationSystemPrompt(
        planTypes: [WorkoutPlanType],
        isForced: Bool,
        userContext: LLMUserContext?
    ) -> String {
        let planTypeText = planTypes.map { $0.displayName }.joined(separator: " and ")
        var prompt = ""
        
        // Add user context summary if available
        if let ctx = userContext {
            prompt += "USER BACKGROUND:\n"
            if let profile = ctx.profile {
                if let level = profile.fitnessLevel {
                    prompt += "- Fitness level: \(level)\n"
                }
                if !profile.primaryGoals.isEmpty {
                    prompt += "- Goals: \(profile.primaryGoals.joined(separator: ", "))\n"
                }
                if !profile.availableEquipment.isEmpty {
                    prompt += "- Equipment: \(profile.availableEquipment.joined(separator: ", "))\n"
                }
                if !profile.injuriesOrLimitations.isEmpty {
                    prompt += "- Limitations: \(profile.injuriesOrLimitations.joined(separator: ", "))\n"
                }
            }
            if let metrics = ctx.healthMetrics {
                prompt += "- Current activity: ~\(metrics.avgStepsPerDay) steps, \(metrics.avgExerciseMinutes) min exercise/day\n"
            }
            prompt += "\n"
        }
        
        if isForced {
            prompt += """
            You are a fitness assistant. The user has provided enough information.
            
            RESPOND WITH THIS EXACT JSON FORMAT:
            {
                "type": "ready",
                "message": "Perfect! I have everything I need to create your \(planTypeText).",
                "summary": "<Summarize what you learned about the user's fitness needs>"
            }
            """
        } else {
            prompt += """
            You are a friendly fitness coach gathering information to create a personalized \(planTypeText).
            
            IMPORTANT: You already know some things about this user from their profile (shown above).
            DO NOT ask about things you already know. Focus on what's missing or specific to this request.
            
            BEHAVIOR RULES:
            1. Ask ONE focused, conversational question at a time
            2. Be motivating and supportive
            3. After gathering enough info (typically 2-4 exchanges if profile is complete), indicate you're ready
            
            RESPOND WITH EXACTLY THIS JSON FORMAT:
            
            If you need more info:
            {"type": "question", "message": "<Your motivating question>"}
            
            If you have enough info:
            {"type": "ready", "message": "<Encouraging ready message>", "summary": "<Summary>"}
            """
        }
        
        return prompt
    }
    
    // MARK: - Legacy System Prompts (Deprecated - kept for backward compatibility)
    
    private func buildDietConversationSystemPrompt(isForced: Bool) -> String {
        if isForced {
            return """
            You are a nutrition assistant. The user has provided enough information.
            
            RESPOND WITH THIS EXACT JSON FORMAT:
            {
                "type": "ready",
                "message": "Great! I have everything I need to create your personalized meal plan.",
                "summary": "<Summarize what you learned about the user's dietary needs>"
            }
            
            Summarize their preferences, restrictions, goals, and any other relevant details.
            """
        }
        
        return """
        You are a friendly nutrition assistant gathering information to create a personalized 7-day meal plan.
        
        BEHAVIOR RULES:
        1. Ask ONE focused, conversational question at a time
        2. Be warm and encouraging, not clinical
        3. Remember what the user already told you - don't repeat questions
        4. After gathering enough info (typically 3-6 exchanges), indicate you're ready
        5. You can be ready earlier if user provides comprehensive info upfront
        
        INFORMATION TO GATHER (not all required):
        - Dietary restrictions or allergies
        - Calorie goals (if any)
        - Cooking time preference (quick meals vs elaborate)
        - Budget constraints
        - Cuisine preferences
        - Household size / servings needed
        - Specific health goals
        
        RESPOND WITH EXACTLY THIS JSON FORMAT:
        
        If you need more info:
        {
            "type": "question",
            "message": "<Your friendly question to the user>"
        }
        
        If you have enough info:
        {
            "type": "ready",
            "message": "<Friendly message saying you're ready to create their plan>",
            "summary": "<Brief summary of their preferences you collected>"
        }
        
        IMPORTANT: Output valid JSON only. No markdown, no explanatory text.
        """
    }
    
    private func buildWorkoutConversationSystemPrompt(
        planTypes: [WorkoutPlanType],
        isForced: Bool
    ) -> String {
        let planTypeText = planTypes.map { $0.displayName }.joined(separator: " and ")
        
        if isForced {
            return """
            You are a fitness assistant. The user has provided enough information.
            
            RESPOND WITH THIS EXACT JSON FORMAT:
            {
                "type": "ready",
                "message": "Perfect! I have everything I need to create your \(planTypeText).",
                "summary": "<Summarize what you learned about the user's fitness needs>"
            }
            
            Summarize their goals, experience level, equipment, schedule, and preferences.
            """
        }
        
        return """
        You are a friendly fitness coach gathering information to create a personalized \(planTypeText).
        
        BEHAVIOR RULES:
        1. Ask ONE focused, conversational question at a time
        2. Be motivating and supportive
        3. Remember what the user already told you - don't repeat questions
        4. After gathering enough info (typically 3-6 exchanges), indicate you're ready
        5. You can be ready earlier if user provides comprehensive info upfront
        
        INFORMATION TO GATHER (not all required):
        - Fitness goals (strength, weight loss, muscle gain, endurance)
        - Current fitness level / experience
        - Available equipment (if home workout)
        - Days per week they can work out
        - Time per session
        - Any injuries or limitations
        - Exercise preferences or dislikes
        
        RESPOND WITH EXACTLY THIS JSON FORMAT:
        
        If you need more info:
        {
            "type": "question",
            "message": "<Your friendly, motivating question>"
        }
        
        If you have enough info:
        {
            "type": "ready",
            "message": "<Encouraging message saying you're ready to create their plan>",
            "summary": "<Brief summary of their fitness profile>"
        }
        
        IMPORTANT: Output valid JSON only. No markdown, no explanatory text.
        """
    }
    
    private func buildConversationUserPrompt(
        history: [ChatMessage],
        context: String
    ) -> String {
        var prompt = "CONVERSATION HISTORY:\n"
        
        for message in history {
            let role = message.role == .user ? "User" : "Assistant"
            prompt += "\(role): \(message.content)\n"
        }
        
        prompt += "\nCOLLECTED CONTEXT SO FAR:\n\(context)\n"
        prompt += "\nBased on this conversation, provide your next response."
        
        return prompt
    }
    
    private func parseConversationalResponse(_ response: String) throws -> ConversationalResponse {
        let jsonString = GeminiAIService.extractJSON(from: response)
        
        guard let data = jsonString.data(using: .utf8) else {
            throw APIError.parseError("Invalid response encoding")
        }
        
        do {
            return try JSONDecoder().decode(ConversationalResponse.self, from: data)
        } catch {
            log("Failed to parse conversational response, using fallback: \(error)")
            return ConversationalResponse(
                type: "question",
                message: response.trimmingCharacters(in: .whitespacesAndNewlines),
                summary: nil
            )
        }
    }
    
    static func accumulateContext(
        existingContext: String,
        newUserMessage: String
    ) -> String {
        if existingContext.isEmpty {
            return newUserMessage
        }
        return "\(existingContext)\n\nAdditional info: \(newUserMessage)"
    }
}

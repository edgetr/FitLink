import Foundation

// MARK: - Habit AI Suggestion Models

struct HabitSuggestion: Codable {
    let title: String
    let icon: String
    let category: String
    let suggestedDurationMinutes: Int
    let preferredTimeOfDay: String
    let motivationalTip: String?
}

struct HabitAnalysis: Codable {
    let suggestion: HabitSuggestion
    let confidence: Double
}

// MARK: - HabitAIService

actor HabitAIService {
    
    static let shared = HabitAIService()
    
    private let geminiService: GeminiAIService
    
    private init() {
        self.geminiService = GeminiAIService()
    }
    
    // MARK: - Public API
    
    /// Analyzes user input and suggests habit details
    /// Uses Gemini Flash with no thinking for maximum speed
    func suggestHabitDetails(from userInput: String) async throws -> HabitSuggestion {
        let prompt = buildSuggestionPrompt(userInput: userInput)
        
        let response = try await geminiService.sendPrompt(
            prompt,
            systemPrompt: systemPrompt,
            model: .flash,
            thinkingLevel: .none,
            maxTokens: 1024,
            temperature: 0.3,
            jsonMode: true
        )
        
        return try parseSuggestion(from: response)
    }
    
    /// Suggests optimal timer duration based on habit type
    func suggestDuration(for habitName: String, category: HabitCategory) async throws -> Int {
        let prompt = """
        Suggest optimal focus timer duration in minutes for this habit:
        Name: \(habitName)
        Category: \(category.rawValue)
        
        Consider:
        - Typical attention span for this activity
        - Whether it benefits from short bursts or longer sessions
        - Common practices for this type of habit
        
        Respond with JSON: {"duration": <minutes>, "reason": "<brief reason>"}
        """
        
        let response = try await geminiService.sendPrompt(
            prompt,
            systemPrompt: "You are a productivity expert. Respond with valid JSON only.",
            model: .flash,
            thinkingLevel: .none,
            maxTokens: 256,
            temperature: 0.2,
            jsonMode: true
        )
        
        struct DurationResponse: Codable {
            let duration: Int
            let reason: String?
        }
        
        let jsonString = GeminiAIService.extractJSON(from: response)
        guard let data = jsonString.data(using: .utf8) else {
            return defaultDuration(for: category)
        }
        
        do {
            let parsed = try JSONDecoder().decode(DurationResponse.self, from: data)
            return max(5, min(120, parsed.duration))
        } catch {
            return defaultDuration(for: category)
        }
    }
    
    /// Generates motivational message based on streak
    func generateStreakMotivation(habitName: String, streakDays: Int) async throws -> String {
        let prompt = """
        Generate a short, encouraging message (max 15 words) for someone who has:
        - Habit: \(habitName)
        - Current streak: \(streakDays) days
        
        Be warm, specific to the streak length, and motivating.
        Respond with JSON: {"message": "<your message>"}
        """
        
        let response = try await geminiService.sendPrompt(
            prompt,
            systemPrompt: "You are a supportive habit coach. Respond with valid JSON only.",
            model: .flash,
            thinkingLevel: .none,
            maxTokens: 128,
            temperature: 0.7,
            jsonMode: true
        )
        
        struct MotivationResponse: Codable {
            let message: String
        }
        
        let jsonString = GeminiAIService.extractJSON(from: response)
        guard let data = jsonString.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(MotivationResponse.self, from: data) else {
            return defaultMotivation(for: streakDays)
        }
        
        return parsed.message
    }
    
    /// Suggests best time of day for a habit
    func suggestTimeOfDay(
        for habitName: String,
        category: HabitCategory,
        userWakeTime: Date? = nil,
        userSleepTime: Date? = nil
    ) async throws -> HabitTimeOfDay {
        var contextInfo = ""
        if let wake = userWakeTime {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            contextInfo += "User typically wakes at: \(formatter.string(from: wake))\n"
        }
        if let sleep = userSleepTime {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            contextInfo += "User typically sleeps at: \(formatter.string(from: sleep))\n"
        }
        
        let prompt = """
        Suggest the best time of day for this habit:
        Name: \(habitName)
        Category: \(category.rawValue)
        \(contextInfo)
        
        Options: morning, afternoon, evening, anytime
        
        Consider energy levels, habit type, and common best practices.
        Respond with JSON: {"timeOfDay": "<option>", "reason": "<brief reason>"}
        """
        
        let response = try await geminiService.sendPrompt(
            prompt,
            systemPrompt: "You are a habit optimization expert. Respond with valid JSON only.",
            model: .flash,
            thinkingLevel: .none,
            maxTokens: 256,
            temperature: 0.2,
            jsonMode: true
        )
        
        struct TimeResponse: Codable {
            let timeOfDay: String
            let reason: String?
        }
        
        let jsonString = GeminiAIService.extractJSON(from: response)
        guard let data = jsonString.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(TimeResponse.self, from: data) else {
            return defaultTimeOfDay(for: category)
        }
        
        return HabitTimeOfDay(rawValue: parsed.timeOfDay.lowercased()) ?? .anytime
    }
    
    /// Batch analyze multiple habit inputs (for onboarding or bulk creation)
    func batchSuggest(inputs: [String]) async throws -> [HabitSuggestion] {
        let prompt = """
        Analyze these habit descriptions and suggest details for each:
        \(inputs.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        
        For each, provide: title, icon (SF Symbol), category, duration (minutes), preferredTime, tip.
        
        Respond with JSON array:
        [
            {
                "title": "...",
                "icon": "...",
                "category": "...",
                "suggestedDurationMinutes": ...,
                "preferredTimeOfDay": "...",
                "motivationalTip": "..."
            }
        ]
        """
        
        let response = try await geminiService.sendPrompt(
            prompt,
            systemPrompt: systemPrompt,
            model: .flash,
            thinkingLevel: .minimal,
            maxTokens: 2048,
            temperature: 0.3,
            jsonMode: true
        )
        
        let jsonString = GeminiAIService.extractJSON(from: response)
        guard let data = jsonString.data(using: .utf8) else {
            throw HabitAIError.parseError("Invalid response encoding")
        }
        
        return try JSONDecoder().decode([HabitSuggestion].self, from: data)
    }
    
    // MARK: - Private Helpers
    
    private var systemPrompt: String {
        """
        You are a habit optimization assistant. Your role is to help users create effective habits.
        
        RULES:
        1. Always respond with valid JSON only - no markdown, no explanations
        2. Suggest appropriate SF Symbols for icons (e.g., "book.fill", "figure.run", "moon.zzz")
        3. Categories must be one of: health, fitness, productivity, learning, mindfulness, social, creativity, finance
        4. Duration should be realistic (5-120 minutes)
        5. Time of day must be: morning, afternoon, evening, or anytime
        6. Tips should be brief (max 20 words) and actionable
        
        ICON GUIDELINES (use exact SF Symbol names):
        - Reading/Learning: book.fill, brain.head.profile, graduationcap.fill
        - Exercise/Fitness: figure.run, dumbbell.fill, heart.fill
        - Meditation/Mindfulness: brain, leaf.fill, moon.stars.fill
        - Sleep: moon.zzz, bed.double.fill
        - Water/Nutrition: drop.fill, fork.knife, apple.logo
        - Work/Productivity: laptopcomputer, doc.text.fill, checklist
        - Social: person.2.fill, message.fill, phone.fill
        - Creative: paintbrush.fill, music.note, camera.fill
        - Finance: dollarsign.circle.fill, chart.line.uptrend.xyaxis
        - General: star.fill, checkmark.circle.fill, target
        """
    }
    
    private func buildSuggestionPrompt(userInput: String) -> String {
        """
        User wants to create a habit. Their input: "\(userInput)"
        
        Analyze this and suggest:
        1. A clear, concise title (improve if needed)
        2. An appropriate SF Symbol icon
        3. The best category
        4. Optimal focus duration in minutes
        5. Best time of day
        6. A brief motivational tip
        
        Respond with JSON:
        {
            "title": "<improved or cleaned up title>",
            "icon": "<SF Symbol name>",
            "category": "<category>",
            "suggestedDurationMinutes": <number>,
            "preferredTimeOfDay": "<time>",
            "motivationalTip": "<brief tip>"
        }
        """
    }
    
    private func parseSuggestion(from response: String) throws -> HabitSuggestion {
        let jsonString = GeminiAIService.extractJSON(from: response)
        guard let data = jsonString.data(using: .utf8) else {
            throw HabitAIError.parseError("Invalid response encoding")
        }
        
        do {
            return try JSONDecoder().decode(HabitSuggestion.self, from: data)
        } catch {
            log("Failed to parse suggestion: \(error)")
            throw HabitAIError.parseError(error.localizedDescription)
        }
    }
    
    private func defaultDuration(for category: HabitCategory) -> Int {
        switch category {
        case .health: return 15
        case .fitness: return 30
        case .productivity: return 25
        case .learning: return 25
        case .mindfulness: return 10
        case .social: return 20
        case .creativity: return 30
        case .finance: return 15
        }
    }
    
    private func defaultTimeOfDay(for category: HabitCategory) -> HabitTimeOfDay {
        switch category {
        case .fitness, .mindfulness: return .morning
        case .learning, .productivity: return .morning
        case .creativity: return .afternoon
        case .social: return .evening
        case .health, .finance: return .anytime
        }
    }
    
    private func defaultMotivation(for streakDays: Int) -> String {
        switch streakDays {
        case 0: return "Start your journey today!"
        case 1: return "Great start! Keep it going!"
        case 2...6: return "You're building momentum!"
        case 7...13: return "One week strong! Amazing!"
        case 14...29: return "Two weeks of dedication!"
        case 30...59: return "A whole month! Incredible!"
        case 60...89: return "Two months! You're unstoppable!"
        default: return "Legendary streak! You inspire others!"
        }
    }
    
    private func log(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [HabitAIService] \(message)")
        #endif
    }
}

// MARK: - Errors

enum HabitAIError: LocalizedError {
    case parseError(String)
    case networkError(Error)
    case noAPIKey
    
    var errorDescription: String? {
        switch self {
        case .parseError(let detail):
            return "Failed to parse AI response: \(detail)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noAPIKey:
            return "API key not configured"
        }
    }
}

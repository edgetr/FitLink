import Foundation

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
        }
    }
    
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    private let model = "gemini-3-flash-preview"
    private let session: URLSession
    private let maxRetries = 3
    private let retryDelayBase: TimeInterval = 1.0
    
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
    
    func sendPrompt(_ prompt: String, systemPrompt: String, maxTokens: Int = 16000, temperature: Double = 1.0, jsonMode: Bool = true) async throws -> String {
        guard !apiKey.isEmpty else {
            throw APIError.noAPIKey
        }
        
        let urlString = "\(baseURL)/\(model):generateContent"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let request = GeminiRequest(
            contents: [
                .init(role: "user", parts: [.init(text: prompt)])
            ],
            generationConfig: .init(
                temperature: temperature,
                topP: 0.8,
                topK: 10,
                maxOutputTokens: maxTokens,
                responseMimeType: jsonMode ? "application/json" : nil
            ),
            systemInstruction: .init(role: "user", parts: [.init(text: systemPrompt)])
        )
        
        return try await sendWithRetry(url: url, request: request, attempt: 1)
    }
    
    func askClarifyingQuestions(_ prompt: String) async throws -> String {
        let systemPrompt = """
        You are an assistant that determines if more information is needed to create a meal plan.
        Always respond with valid JSON only. No markdown, no explanatory text.
        """
        
        return try await sendPrompt(prompt, systemPrompt: systemPrompt, maxTokens: 2000, temperature: 0.5)
    }
    
    private func sendWithRetry(url: URL, request: GeminiRequest, attempt: Int) async throws -> String {
        do {
            return try await performRequest(url: url, request: request)
        } catch let error as APIError {
            switch error {
            case .noAPIKey, .invalidURL, .parseError:
                throw error
            case .rateLimited where attempt < maxRetries:
                let delay = retryDelayBase * pow(2.0, Double(attempt - 1))
                log("Rate limited, retrying in \(delay)s (attempt \(attempt)/\(maxRetries))")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await sendWithRetry(url: url, request: request, attempt: attempt + 1)
            case .serverError, .timeout, .networkError:
                if attempt < maxRetries {
                    let delay = retryDelayBase * pow(2.0, Double(attempt - 1))
                    log("Request failed, retrying in \(delay)s (attempt \(attempt)/\(maxRetries))")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await sendWithRetry(url: url, request: request, attempt: attempt + 1)
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
                return try await sendWithRetry(url: url, request: request, attempt: attempt + 1)
            }
            throw APIError.networkError(error)
        }
    }
    
    private func performRequest(url: URL, request: GeminiRequest) async throws -> String {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        log("Sending request to Gemini API (model: \(model))...")
        
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
                log("Tokens used - prompt: \(usage.promptTokenCount ?? 0), response: \(usage.candidatesTokenCount ?? 0)")
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
}

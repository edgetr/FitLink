//
//  PythonAIBridge.swift
//  FitLink
//
//  Created on 25.12.2025.
//

import Foundation

actor PythonAIBridge {
    
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
    
    private struct PerplexityRequest: Encodable {
        let model: String
        let messages: [Message]
        let maxTokens: Int?
        let temperature: Double?
        let stream: Bool
        
        struct Message: Encodable {
            let role: String
            let content: String
        }
        
        enum CodingKeys: String, CodingKey {
            case model, messages, stream, temperature
            case maxTokens = "max_tokens"
        }
    }
    
    private struct PerplexityResponse: Decodable {
        let id: String?
        let choices: [Choice]?
        let error: PerplexityError?
        let usage: Usage?
        
        struct Choice: Decodable {
            let message: Message?
            let finishReason: String?
            
            struct Message: Decodable {
                let role: String?
                let content: String?
            }
            
            enum CodingKeys: String, CodingKey {
                case message
                case finishReason = "finish_reason"
            }
        }
        
        struct PerplexityError: Decodable {
            let message: String
            let type: String?
            let code: String?
        }
        
        struct Usage: Decodable {
            let promptTokens: Int?
            let completionTokens: Int?
            let totalTokens: Int?
            
            enum CodingKeys: String, CodingKey {
                case promptTokens = "prompt_tokens"
                case completionTokens = "completion_tokens"
                case totalTokens = "total_tokens"
            }
        }
    }
    
    private let apiKey: String
    private let baseURL = "https://api.perplexity.ai/chat/completions"
    private let model = "llama-3.1-sonar-large-128k-online"
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
        let key = ConfigurationManager.shared.perplexityAPIKey ?? ""
        self.apiKey = key
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 180
        self.session = URLSession(configuration: config)
    }
    
    func sendPrompt(_ prompt: String, systemPrompt: String, maxTokens: Int = 8000, temperature: Double = 0.7) async throws -> String {
        guard !apiKey.isEmpty else {
            throw APIError.noAPIKey
        }
        
        guard let url = URL(string: baseURL) else {
            throw APIError.invalidURL
        }
        
        let request = PerplexityRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: prompt)
            ],
            maxTokens: maxTokens,
            temperature: temperature,
            stream: false
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
    
    private func sendWithRetry(url: URL, request: PerplexityRequest, attempt: Int) async throws -> String {
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
    
    private func performRequest(url: URL, request: PerplexityRequest) async throws -> String {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        log("Sending request to Perplexity API (model: \(model))...")
        
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
            let perplexityResponse = try decoder.decode(PerplexityResponse.self, from: data)
            
            if let error = perplexityResponse.error {
                throw APIError.parseError(error.message)
            }
            
            guard let choices = perplexityResponse.choices,
                  let firstChoice = choices.first,
                  let message = firstChoice.message,
                  let content = message.content else {
                throw APIError.parseError("No content in response")
            }
            
            if let usage = perplexityResponse.usage {
                log("Tokens used - prompt: \(usage.promptTokens ?? 0), completion: \(usage.completionTokens ?? 0)")
            }
            
            log("Successfully parsed response (\(content.count) characters)")
            return content
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
        print("[\(timestamp)] [PythonAIBridge] \(message)")
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

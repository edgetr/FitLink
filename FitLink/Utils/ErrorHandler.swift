//
//  ErrorHandler.swift
//  FitLink
//
//  Created on 25.12.2025.
//

import Foundation
import os.log

/// Centralized error handling with categorization, logging, and user-friendly message mapping.
final class ErrorHandler {
    
    // MARK: - Singleton
    
    static let shared = ErrorHandler()
    
    // MARK: - Error Categories
    
    /// High-level error categories for classification
    enum ErrorCategory: String {
        case network = "Network"
        case authentication = "Authentication"
        case database = "Database"
        case parsing = "Parsing"
        case aiService = "AI Service"
        case validation = "Validation"
        case permission = "Permission"
        case storage = "Storage"
        case unknown = "Unknown"
    }
    
    /// Severity levels for error logging
    enum Severity: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }
    
    // MARK: - App Error
    
    /// Unified app error type that wraps all errors
    struct AppError: LocalizedError, Identifiable {
        let id = UUID()
        let category: ErrorCategory
        let underlyingError: Error?
        let userMessage: String
        let technicalDetails: String?
        let recoveryAction: RecoveryAction?
        let timestamp: Date
        
        var errorDescription: String? { userMessage }
        
        init(
            category: ErrorCategory,
            underlyingError: Error? = nil,
            userMessage: String,
            technicalDetails: String? = nil,
            recoveryAction: RecoveryAction? = nil
        ) {
            self.category = category
            self.underlyingError = underlyingError
            self.userMessage = userMessage
            self.technicalDetails = technicalDetails
            self.recoveryAction = recoveryAction
            self.timestamp = Date()
        }
    }
    
    /// Possible recovery actions for errors
    enum RecoveryAction {
        case retry
        case refreshToken
        case checkConnection
        case contactSupport
        case openSettings
        case none
        
        var buttonTitle: String {
            switch self {
            case .retry: return "Try Again"
            case .refreshToken: return "Sign In Again"
            case .checkConnection: return "Check Connection"
            case .contactSupport: return "Contact Support"
            case .openSettings: return "Open Settings"
            case .none: return "OK"
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.fitlink.app", category: "ErrorHandler")
    private var errorHistory: [AppError] = []
    private let historyLimit = 50
    private let errorHistoryLock = NSLock()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Handles an error by categorizing, logging, and optionally reporting it
    /// - Parameters:
    ///   - error: The error to handle
    ///   - context: Additional context about where the error occurred
    ///   - severity: The severity level
    /// - Returns: An AppError with user-friendly messaging
    @discardableResult
    func handle(_ error: Error, context: String? = nil, severity: Severity = .error) -> AppError {
        let category = categorize(error)
        let messageCategory = mapToMessageCategory(category)
        let userMessage = UserFriendlyErrorMessages.message(for: error, category: messageCategory)
        let technicalDetails = buildTechnicalDetails(error, context: context)
        let recoveryAction = suggestRecoveryAction(for: category, error: error)
        
        let appError = AppError(
            category: category,
            underlyingError: error,
            userMessage: userMessage,
            technicalDetails: technicalDetails,
            recoveryAction: recoveryAction
        )
        
        log(appError, severity: severity)
        storeInHistory(appError)
        
        return appError
    }
    
    /// Logs an error without full handling
    func log(_ message: String, severity: Severity = .info, context: String? = nil) {
        let contextStr = context.map { " [\($0)]" } ?? ""
        let fullMessage = "[\(severity.rawValue)]\(contextStr) \(message)"
        
        logger.log(level: severity.osLogType, "\(fullMessage)")
        
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [ErrorHandler] \(fullMessage)")
        #endif
    }
    
    /// Retrieves recent error history
    func getRecentErrors(limit: Int = 10) -> [AppError] {
        errorHistoryLock.lock()
        defer { errorHistoryLock.unlock() }
        return Array(errorHistory.suffix(limit))
    }
    
    /// Clears error history
    func clearHistory() {
        errorHistoryLock.lock()
        defer { errorHistoryLock.unlock() }
        errorHistory.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func categorize(_ error: Error) -> ErrorCategory {
        // Check for URLSession errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                return .network
            default:
                return .network
            }
        }
        
        // Check for decoding errors
        if error is DecodingError {
            return .parsing
        }
        
        // Check for encoding errors
        if error is EncodingError {
            return .parsing
        }
        
        let errorTypeName = String(describing: type(of: error))
        if errorTypeName.contains("APIError") {
            let errorDesc = error.localizedDescription.lowercased()
            if errorDesc.contains("network") {
                return .network
            } else if errorDesc.contains("parse") {
                return .parsing
            } else if errorDesc.contains("api key") {
                return .authentication
            }
            return .aiService
        }
        
        // Check the error domain
        let nsError = error as NSError
        switch nsError.domain {
        case NSURLErrorDomain:
            return .network
        case "FIRAuthErrorDomain":
            return .authentication
        case "FIRFirestoreErrorDomain":
            return .database
        default:
            break
        }
        
        return .unknown
    }
    
    private func buildTechnicalDetails(_ error: Error, context: String?) -> String {
        var details = [String]()
        
        if let context = context {
            details.append("Context: \(context)")
        }
        
        details.append("Error: \(error.localizedDescription)")
        
        let nsError = error as NSError
        details.append("Domain: \(nsError.domain)")
        details.append("Code: \(nsError.code)")
        
        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            details.append("Underlying: \(underlyingError.localizedDescription)")
        }
        
        return details.joined(separator: "\n")
    }
    
    private func suggestRecoveryAction(for category: ErrorCategory, error: Error) -> RecoveryAction {
        switch category {
        case .network:
            return .checkConnection
        case .authentication:
            return .refreshToken
        case .permission:
            return .openSettings
        case .aiService:
            return .retry
        case .database, .parsing, .validation, .storage:
            return .retry
        case .unknown:
            return .none
        }
    }
    
    private func mapToMessageCategory(_ category: ErrorCategory) -> UserFriendlyErrorMessages.Category {
        switch category {
        case .network: return .network
        case .authentication: return .authentication
        case .database: return .database
        case .parsing: return .parsing
        case .aiService: return .aiService
        case .validation: return .validation
        case .permission: return .permission
        case .storage: return .storage
        case .unknown: return .unknown
        }
    }
    
    private func log(_ appError: AppError, severity: Severity) {
        var message = "[\(severity.rawValue)] [\(appError.category.rawValue)] \(appError.userMessage)"
        
        if let technicalDetails = appError.technicalDetails {
            message += "\nDetails: \(technicalDetails)"
        }
        
        logger.log(level: severity.osLogType, "\(message)")
        
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [ErrorHandler] \(message)")
        #endif
    }
    
    private func storeInHistory(_ error: AppError) {
        errorHistoryLock.lock()
        defer { errorHistoryLock.unlock() }
        
        errorHistory.append(error)
        
        // Trim history if needed
        if errorHistory.count > historyLimit {
            errorHistory.removeFirst(errorHistory.count - historyLimit)
        }
    }
}

// MARK: - Convenience Extensions

extension Error {
    /// Handles this error using the shared ErrorHandler
    @discardableResult
    func handle(context: String? = nil, severity: ErrorHandler.Severity = .error) -> ErrorHandler.AppError {
        ErrorHandler.shared.handle(self, context: context, severity: severity)
    }
}

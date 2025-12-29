//
//  UserFriendlyErrorMessages.swift
//  FitLink
//
//  Created on 25.12.2025.
//

import Foundation

/// Maps technical errors to user-friendly, localization-ready messages.
/// Provides clear, actionable feedback for common error scenarios.
enum UserFriendlyErrorMessages {
    
    // MARK: - Network Errors
    
    enum Network {
        static let noConnection = "Unable to connect. Please check your internet connection and try again."
        static let timeout = "The request took too long. Please check your connection and try again."
        static let serverUnreachable = "Unable to reach the server. Please try again later."
        static let connectionLost = "Your connection was interrupted. Please try again."
        static let `default` = "A network error occurred. Please check your connection and try again."
    }
    
    // MARK: - Authentication Errors
    
    enum Auth {
        static let invalidCredentials = "Invalid email or password. Please check your credentials and try again."
        static let emailAlreadyInUse = "This email is already registered. Try signing in instead."
        static let weakPassword = "Password is too weak. Please use at least 8 characters with a mix of letters and numbers."
        static let userNotFound = "No account found with this email. Please check or create a new account."
        static let sessionExpired = "Your session has expired. Please sign in again."
        static let networkError = "Unable to sign in. Please check your internet connection."
        static let tooManyAttempts = "Too many failed attempts. Please try again later."
        static let emailNotVerified = "Please verify your email address before signing in."
        static let `default` = "An authentication error occurred. Please try again."
    }
    
    // MARK: - Database Errors
    
    enum Database {
        static let saveFailed = "Failed to save your changes. Please try again."
        static let loadFailed = "Failed to load data. Please try again."
        static let deleteFailed = "Failed to delete. Please try again."
        static let notFound = "The requested item could not be found."
        static let permissionDenied = "You don't have permission to access this content."
        static let quotaExceeded = "Storage quota exceeded. Please free up some space."
        static let `default` = "A database error occurred. Please try again."
    }
    
    // MARK: - AI Service Errors
    
    enum AI {
        static let generationFailed = "Unable to generate content. Please try again with a different prompt."
        static let rateLimited = "You've made too many requests. Please wait a moment and try again."
        static let invalidResponse = "Received an unexpected response. Please try again."
        static let parseError = "Unable to process the AI response. Please try a simpler request."
        static let noAPIKey = "AI service is not configured. Please check your settings."
        static let serviceUnavailable = "AI service is temporarily unavailable. Please try again later."
        static let timeout = "The AI is taking too long to respond. Please try a shorter prompt."
        static let `default` = "Unable to generate plan. Please try again."
    }
    
    // MARK: - Validation Errors
    
    enum Validation {
        static let invalidEmail = "Please enter a valid email address."
        static let invalidPassword = "Password must be at least 8 characters."
        static let passwordMismatch = "Passwords don't match. Please try again."
        static let requiredField = "This field is required."
        static let invalidInput = "Please check your input and try again."
        static let `default` = "Please check your input and try again."
    }
    
    // MARK: - Permission Errors
    
    enum Permission {
        static let healthKit = "FitLink needs access to Health data to track your activity. Please enable in Settings."
        static let calendar = "FitLink needs calendar access to add meal reminders. Please enable in Settings."
        static let notifications = "Enable notifications to receive workout and meal reminders."
        static let camera = "FitLink needs camera access to take profile photos. Please enable in Settings."
        static let photoLibrary = "FitLink needs photo library access to select profile photos. Please enable in Settings."
        static let location = "FitLink needs location access for localized recommendations."
        static let `default` = "Permission is required for this feature. Please check Settings."
    }
    
    // MARK: - Storage Errors
    
    enum Storage {
        static let uploadFailed = "Failed to upload file. Please try again."
        static let downloadFailed = "Failed to download file. Please try again."
        static let fileTooLarge = "File is too large. Please choose a smaller file."
        static let invalidFormat = "Invalid file format. Please choose a supported format."
        static let `default` = "A storage error occurred. Please try again."
    }
    
    // MARK: - Social/Friends Errors
    
    enum Social {
        static let requestAlreadyExists = "You already have a pending friend request with this user."
        static let alreadyFriends = "You're already friends with this user."
        static let requestNotFound = "This friend request is no longer available."
        static let requestNotPending = "This friend request has already been handled."
        static let userNotFound = "This user could not be found."
        static let selfRequest = "You can't send a friend request to yourself."
        static let loadFriendsFailed = "Unable to load friends. Please try again."
        static let searchFailed = "Unable to search for users. Please try again."
        static let chatNotFound = "Unable to find this conversation."
        static let messageNotFound = "Message not found."
        static let encryptionNotInitialized = "Secure chat not ready. Please try again."
        static let sendMessageFailed = "Failed to send message. Please try again."
        static let loadMessagesFailed = "Failed to load messages. Please try again."
        static let encryptionFailed = "Failed to encrypt message. Please try again."
        static let decryptionFailed = "Unable to decrypt message."
        static let `default` = "A social feature error occurred. Please try again."
    }
    
    // MARK: - Generic Errors
    
    enum Generic {
        static let somethingWentWrong = "Something went wrong. Please try again."
        static let tryAgain = "An error occurred. Please try again."
        static let unexpectedError = "An unexpected error occurred. Please try again or contact support."
    }
    
    // MARK: - Error Category (standalone to avoid circular dependency)
    
    /// Error category used for message resolution
    enum Category: String {
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
    
    // MARK: - Message Resolution
    
    /// Returns a user-friendly message for the given error and category
    static func message(for error: Error, category: Category) -> String {
        // First, try to get a specific message based on the error type
        if let specificMessage = specificMessage(for: error) {
            return specificMessage
        }
        
        // Fall back to category-based messages
        switch category {
        case .network:
            return networkMessage(for: error)
        case .authentication:
            return authMessage(for: error)
        case .database:
            return Database.default
        case .parsing:
            return AI.parseError
        case .aiService:
            return aiMessage(for: error)
        case .validation:
            return Validation.default
        case .permission:
            return Permission.default
        case .storage:
            return Storage.default
        case .unknown:
            return Generic.somethingWentWrong
        }
    }
    
    /// Convenience overload that auto-categorizes the error
    static func message(for error: Error) -> String {
        let category = categorize(error)
        return message(for: error, category: category)
    }
    
    /// Categorizes an error into a user-friendly category
    private static func categorize(_ error: Error) -> Category {
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
        
        // Check for AI service errors by error description pattern
        let errorDesc = String(describing: type(of: error))
        if errorDesc.contains("APIError") || errorDesc.contains("AIService") {
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
    
    // MARK: - Private Helpers
    
    private static func specificMessage(for error: Error) -> String? {
        // Handle URLError specifically
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return Network.noConnection
            case .timedOut:
                return Network.timeout
            case .networkConnectionLost:
                return Network.connectionLost
            case .cannotFindHost, .cannotConnectToHost:
                return Network.serverUnreachable
            default:
                return nil
            }
        }
        
        // Handle DecodingError specifically
        if error is DecodingError {
            return AI.parseError
        }
        
        // Handle AI API errors by checking error type name
        let errorTypeName = String(describing: type(of: error))
        if errorTypeName.contains("APIError") {
            let errorDesc = error.localizedDescription.lowercased()
            if errorDesc.contains("invalid response") {
                return AI.invalidResponse
            } else if errorDesc.contains("timeout") || errorDesc.contains("timed out") {
                return AI.timeout
            } else if errorDesc.contains("rate") || errorDesc.contains("too many") {
                return AI.rateLimited
            } else if errorDesc.contains("server") {
                return AI.serviceUnavailable
            } else if errorDesc.contains("parse") {
                return AI.parseError
            } else if errorDesc.contains("network") {
                return Network.default
            } else if errorDesc.contains("api key") || errorDesc.contains("not configured") {
                return AI.noAPIKey
            } else {
                return AI.default
            }
        }
        
        return nil
    }
    
    private static func networkMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return Network.noConnection
            case .timedOut:
                return Network.timeout
            case .networkConnectionLost:
                return Network.connectionLost
            default:
                return Network.default
            }
        }
        return Network.default
    }
    
    private static func authMessage(for error: Error) -> String {
        let nsError = error as NSError
        
        // Firebase Auth error codes
        if nsError.domain == "FIRAuthErrorDomain" {
            switch nsError.code {
            case 17009: // Wrong password
                return Auth.invalidCredentials
            case 17011: // User not found
                return Auth.userNotFound
            case 17007: // Email already in use
                return Auth.emailAlreadyInUse
            case 17026: // Weak password
                return Auth.weakPassword
            case 17010: // Too many requests
                return Auth.tooManyAttempts
            case 17020: // Network error
                return Auth.networkError
            default:
                return Auth.default
            }
        }
        
        return Auth.default
    }
    
    private static func aiMessage(for error: Error) -> String {
        let errorTypeName = String(describing: type(of: error))
        if errorTypeName.contains("APIError") {
            let errorDesc = error.localizedDescription.lowercased()
            if errorDesc.contains("rate") || errorDesc.contains("too many") {
                return AI.rateLimited
            } else if errorDesc.contains("timeout") || errorDesc.contains("timed out") {
                return AI.timeout
            } else if errorDesc.contains("parse") {
                return AI.parseError
            } else if errorDesc.contains("api key") || errorDesc.contains("not configured") {
                return AI.noAPIKey
            }
        }
        return AI.default
    }
}

// MARK: - Localization Helpers

extension UserFriendlyErrorMessages {
    
    /// Returns a localized version of the message (placeholder for future localization)
    static func localized(_ key: String) -> String {
        // In the future, this would use NSLocalizedString
        // For now, just return the key as-is
        return key
    }
}

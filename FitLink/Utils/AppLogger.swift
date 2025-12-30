//
//  AppLogger.swift
//  FitLink
//
//  Security-focused logging utility with PII redaction.
//

import Foundation
import os.log

final class AppLogger {
    
    // MARK: - Singleton
    
    static let shared = AppLogger()
    
    // MARK: - Categories
    
    enum Category: String {
        case general = "General"
        case network = "Network"
        case auth = "Auth"
        case health = "Health"
        case ai = "AI"
        case cache = "Cache"
        case config = "Config"
        case navigation = "Navigation"
        case notification = "Notification"
        case location = "Location"
        case sync = "Sync"
        case liveActivity = "LiveActivity"
        case diet = "Diet"
        case workout = "Workout"
        case habit = "Habit"
        case user = "User"
        case image = "Image"
    }
    
    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case fault = "FAULT"
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .fault: return .fault
            }
        }
    }
    
    // MARK: - Properties
    
    private let subsystem = "com.fitlink.app"
    private var loggers: [Category: Logger] = [:]
    private let loggersLock = NSLock()
    
    private static let logDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Logging Methods
    
    func log(
        _ message: String,
        level: Level = .info,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let logger = getLogger(for: category)
        let redactedMessage = redact(message)
        
        #if DEBUG
        let timestamp = Self.logDateFormatter.string(from: Date())
        let filename = (file as NSString).lastPathComponent
        print("[\(timestamp)] [\(category.rawValue)] [\(level.rawValue)] \(redactedMessage) (\(filename):\(line))")
        #endif
        
        logger.log(level: level.osLogType, "[\(category.rawValue)] \(redactedMessage, privacy: .public)")
    }
    
    func debug(_ message: String, category: Category = .general) {
        #if DEBUG
        log(message, level: .debug, category: category)
        #endif
    }
    
    func info(_ message: String, category: Category = .general) {
        log(message, level: .info, category: category)
    }
    
    func warning(_ message: String, category: Category = .general) {
        log(message, level: .warning, category: category)
    }
    
    func error(_ message: String, category: Category = .general) {
        log(message, level: .error, category: category)
    }
    
    func fault(_ message: String, category: Category = .general) {
        log(message, level: .fault, category: category)
    }
    
    // MARK: - Category-Specific Convenience Methods
    
    func network(_ message: String, level: Level = .info) {
        log(message, level: level, category: .network)
    }
    
    func ai(_ message: String, level: Level = .info) {
        log(message, level: level, category: .ai)
    }
    
    func health(_ message: String, level: Level = .info) {
        log(message, level: level, category: .health)
    }
    
    func config(_ message: String, level: Level = .info) {
        log(message, level: level, category: .config)
    }
    
    // MARK: - PII Redaction
    
    private func redact(_ message: String) -> String {
        var result = message
        
        result = redactEmails(in: result)
        result = redactPhoneNumbers(in: result)
        result = redactAPIKeys(in: result)
        result = redactUUIDs(in: result)
        result = redactHealthValues(in: result)
        
        return result
    }
    
    private func redactEmails(in text: String) -> String {
        let pattern = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return redactPattern(pattern, in: text, replacement: "[EMAIL]")
    }
    
    private func redactPhoneNumbers(in text: String) -> String {
        let pattern = "\\+?[0-9]{1,4}[-.\\s]?\\(?[0-9]{1,3}\\)?[-.\\s]?[0-9]{1,4}[-.\\s]?[0-9]{1,9}"
        return redactPattern(pattern, in: text, replacement: "[PHONE]")
    }
    
    private func redactAPIKeys(in text: String) -> String {
        var result = text
        
        let patterns = [
            "AIza[0-9A-Za-z_\\-]{35}",
            "sk-[A-Za-z0-9]{48,}",
            "Bearer\\s+[A-Za-z0-9_\\-\\.]{20,}",
            "api[_-]?key[\"\\s]*[:=][\"\\s]*[\"'][A-Za-z0-9_\\-]{16,}[\"']"
        ]
        
        for pattern in patterns {
            result = redactPattern(pattern, in: result, replacement: "[REDACTED_KEY]")
        }
        
        return result
    }
    
    private func redactUUIDs(in text: String) -> String {
        let pattern = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
        return redactPattern(pattern, in: text, replacement: "[UUID]")
    }
    
    private func redactHealthValues(in text: String) -> String {
        var result = text
        
        let healthPatterns = [
            "(heart[_\\s]?rate|hr)[:\\s]*[0-9]+",
            "(weight)[:\\s]*[0-9]+\\.?[0-9]*\\s*(kg|lbs|lb)?",
            "(calories)[:\\s]*[0-9]+",
            "(steps)[:\\s]*[0-9]+",
            "(blood[_\\s]?pressure|bp)[:\\s]*[0-9]+/[0-9]+"
        ]
        
        for pattern in healthPatterns {
            result = redactPattern(pattern, in: result, replacement: "[HEALTH_DATA]", caseInsensitive: true)
        }
        
        return result
    }
    
    private func redactPattern(_ pattern: String, in text: String, replacement: String, caseInsensitive: Bool = false) -> String {
        do {
            var options: NSRegularExpression.Options = []
            if caseInsensitive {
                options.insert(.caseInsensitive)
            }
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let range = NSRange(text.startIndex..., in: text)
            return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
        } catch {
            return text
        }
    }
    
    // MARK: - Logger Management
    
    private func getLogger(for category: Category) -> Logger {
        loggersLock.lock()
        defer { loggersLock.unlock() }
        
        if let existing = loggers[category] {
            return existing
        }
        
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        loggers[category] = logger
        return logger
    }
}

// MARK: - Convenience Functions

func appLog(_ message: String, level: AppLogger.Level = .info, category: AppLogger.Category = .general) {
    AppLogger.shared.log(message, level: level, category: category)
}

func appDebug(_ message: String, category: AppLogger.Category = .general) {
    AppLogger.shared.debug(message, category: category)
}

func appWarning(_ message: String, category: AppLogger.Category = .general) {
    AppLogger.shared.warning(message, category: category)
}

func appError(_ message: String, category: AppLogger.Category = .general) {
    AppLogger.shared.error(message, category: category)
}

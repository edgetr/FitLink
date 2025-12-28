//
//  ConfigurationManager.swift
//  FitLink
//
//  Created on 24.12.2025.
//

import Foundation

/// Manages configuration and API keys loaded from a local plist file.
/// The plist file (APIConfig.local.plist) should be excluded from version control.
final class ConfigurationManager {
    
    // MARK: - Singleton
    
    static let shared = ConfigurationManager()
    
    // MARK: - Properties
    
    private var config: [String: Any] = [:]
    
    // MARK: - API Key Accessors
    
    var perplexityAPIKey: String? {
        return config["PERPLEXITY_API_KEY"] as? String
    }
    
    var openAIAPIKey: String? {
        return config["OPENAI_API_KEY"] as? String
    }
    
    var geminiAPIKey: String? {
        return config["GEMINI_API_KEY"] as? String
    }
    
    // MARK: - Initialization
    
    private init() {
        loadConfiguration()
    }
    
    // MARK: - Private Methods
    
    private func loadConfiguration() {
        guard let plistPath = Bundle.main.path(forResource: "APIConfig.local", ofType: "plist") else {
            AppLogger.shared.warning("APIConfig.local.plist not found. API features may not work.", category: .config)
            return
        }
        
        guard let plistData = FileManager.default.contents(atPath: plistPath) else {
            AppLogger.shared.warning("Could not read APIConfig.local.plist", category: .config)
            return
        }
        
        do {
            if let plistDict = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
                config = plistDict
                AppLogger.shared.info("Configuration loaded successfully", category: .config)
            }
        } catch {
            AppLogger.shared.error("Error parsing APIConfig.local.plist: \(error.localizedDescription)", category: .config)
        }
    }
    
    // MARK: - Public Methods
    
    /// Returns the value for a given configuration key.
    /// - Parameter key: The configuration key to look up.
    /// - Returns: The value if found, nil otherwise.
    func value(forKey key: String) -> Any? {
        return config[key]
    }
    
    /// Returns a string value for a given configuration key.
    /// - Parameter key: The configuration key to look up.
    /// - Returns: The string value if found, nil otherwise.
    func string(forKey key: String) -> String? {
        return config[key] as? String
    }
    
    /// Validates that required API keys are present.
    /// - Returns: True if all required keys are present and non-empty.
    func validateRequiredKeys() -> Bool {
        guard let perplexityKey = perplexityAPIKey,
              !perplexityKey.isEmpty,
              perplexityKey != "YOUR_PERPLEXITY_API_KEY_HERE" else {
            return false
        }
        return true
    }
}

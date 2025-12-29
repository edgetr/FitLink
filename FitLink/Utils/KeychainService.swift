import Foundation
import Security

enum KeychainError: LocalizedError, Sendable {
    case duplicateItem
    case itemNotFound
    case unexpectedData
    case unhandledError(status: OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .duplicateItem:
            return "Item already exists in keychain"
        case .itemNotFound:
            return "Item not found in keychain"
        case .unexpectedData:
            return "Unexpected data format in keychain"
        case .unhandledError(let status):
            return "Keychain error: \(status)"
        }
    }
}

final class KeychainService: Sendable {
    
    static let shared = KeychainService()
    
    private let serviceName = "com.fitlink.chat.encryption"
    
    private init() {}
    
    nonisolated func store(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            try update(data, for: key)
        } else if status != errSecSuccess {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    nonisolated func retrieve(for key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.unexpectedData
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    nonisolated func update(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        if status == errSecItemNotFound {
            try store(data, for: key)
        } else if status != errSecSuccess {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    nonisolated func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    nonisolated func exists(for key: String) -> Bool {
        do {
            return try retrieve(for: key) != nil
        } catch {
            return false
        }
    }
    
    nonisolated func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unhandledError(status: status)
        }
    }
}

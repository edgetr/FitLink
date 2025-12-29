import Foundation
import CryptoKit

enum EncryptionError: LocalizedError, Sendable {
    case privateKeyNotFound
    case publicKeyNotFound
    case keyDerivationFailed
    case encryptionFailed
    case decryptionFailed
    case invalidKeyData
    case keychainError(String)
    
    var errorDescription: String? {
        switch self {
        case .privateKeyNotFound:
            return "Private encryption key not found"
        case .publicKeyNotFound:
            return "Public encryption key not found"
        case .keyDerivationFailed:
            return "Failed to derive encryption key"
        case .encryptionFailed:
            return "Failed to encrypt message"
        case .decryptionFailed:
            return "Failed to decrypt message"
        case .invalidKeyData:
            return "Invalid key data format"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        }
    }
}

actor ChatEncryptionService {
    
    static let shared = ChatEncryptionService()
    
    private let keychain = KeychainService.shared
    private let privateKeyIdentifier = "chat_private_key"
    private let publicKeyPrefix = "chat_public_key_"
    
    private var cachedSymmetricKeys: [String: SymmetricKey] = [:]
    
    private init() {}
    
    func generateKeyPair() throws -> (privateKey: Curve25519.KeyAgreement.PrivateKey, publicKey: Data) {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKeyData = privateKey.publicKey.rawRepresentation
        
        do {
            try keychain.store(privateKey.rawRepresentation, for: privateKeyIdentifier)
        } catch {
            throw EncryptionError.keychainError(error.localizedDescription)
        }
        
        return (privateKey, publicKeyData)
    }
    
    func getPublicKey() throws -> Data {
        do {
            guard let privateKeyData = try keychain.retrieve(for: privateKeyIdentifier) else {
                let (_, publicKey) = try generateKeyPair()
                return publicKey
            }
            
            let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData)
            return privateKey.publicKey.rawRepresentation
        } catch let error as EncryptionError {
            throw error
        } catch {
            throw EncryptionError.keychainError(error.localizedDescription)
        }
    }
    
    func hasKeyPair() -> Bool {
        keychain.exists(for: privateKeyIdentifier)
    }
    
    func storeRemotePublicKey(_ publicKeyData: Data, forUserId userId: String) throws {
        do {
            try keychain.store(publicKeyData, for: publicKeyPrefix + userId)
        } catch {
            throw EncryptionError.keychainError(error.localizedDescription)
        }
    }
    
    func getRemotePublicKey(forUserId userId: String) throws -> Data? {
        do {
            return try keychain.retrieve(for: publicKeyPrefix + userId)
        } catch {
            throw EncryptionError.keychainError(error.localizedDescription)
        }
    }
    
    func deriveSharedKey(withUserId userId: String, chatId: String) throws -> SymmetricKey {
        let cacheKey = "\(chatId)_\(userId)"
        if let cached = cachedSymmetricKeys[cacheKey] {
            return cached
        }
        
        guard let privateKeyData = try keychain.retrieve(for: privateKeyIdentifier) else {
            throw EncryptionError.privateKeyNotFound
        }
        
        guard let remotePublicKeyData = try keychain.retrieve(for: publicKeyPrefix + userId) else {
            throw EncryptionError.publicKeyNotFound
        }
        
        let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData)
        let remotePublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: remotePublicKeyData)
        
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: remotePublicKey)
        
        let sharedInfo = privateKey.publicKey.rawRepresentation + remotePublicKey.rawRepresentation
        guard let saltData = chatId.data(using: .utf8) else {
            throw EncryptionError.keyDerivationFailed
        }
        
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: saltData,
            sharedInfo: sharedInfo,
            outputByteCount: 32
        )
        
        cachedSymmetricKeys[cacheKey] = symmetricKey
        
        return symmetricKey
    }
    
    func encrypt(message: String, withUserId userId: String, chatId: String) throws -> (ciphertext: Data, nonce: Data) {
        guard let messageData = message.data(using: .utf8) else {
            throw EncryptionError.encryptionFailed
        }
        
        let key = try deriveSharedKey(withUserId: userId, chatId: chatId)
        
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(messageData, using: key, nonce: nonce)
        
        let combined = sealedBox.ciphertext + sealedBox.tag
        
        return (combined, Data(nonce))
    }
    
    func decrypt(ciphertext: Data, nonce: Data, withUserId userId: String, chatId: String) throws -> String {
        let key = try deriveSharedKey(withUserId: userId, chatId: chatId)
        
        let nonceObj = try AES.GCM.Nonce(data: nonce)
        
        let tagLength = 16
        guard ciphertext.count > tagLength else {
            throw EncryptionError.decryptionFailed
        }
        
        let encryptedData = ciphertext.dropLast(tagLength)
        let tag = ciphertext.suffix(tagLength)
        
        let sealedBox = try AES.GCM.SealedBox(nonce: nonceObj, ciphertext: encryptedData, tag: tag)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        guard let message = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed
        }
        
        return message
    }
    
    func encryptToBase64(message: String, withUserId userId: String, chatId: String) throws -> (encryptedContent: String, iv: String) {
        let (ciphertext, nonce) = try encrypt(message: message, withUserId: userId, chatId: chatId)
        return (ciphertext.base64EncodedString(), nonce.base64EncodedString())
    }
    
    func decryptFromBase64(encryptedContent: String, iv: String, withUserId userId: String, chatId: String) throws -> String {
        guard let ciphertext = Data(base64Encoded: encryptedContent),
              let nonce = Data(base64Encoded: iv) else {
            throw EncryptionError.decryptionFailed
        }
        
        return try decrypt(ciphertext: ciphertext, nonce: nonce, withUserId: userId, chatId: chatId)
    }
    
    func clearCachedKeys() {
        cachedSymmetricKeys.removeAll()
    }
    
    func deleteAllKeys() throws {
        cachedSymmetricKeys.removeAll()
        do {
            try keychain.deleteAll()
        } catch {
            throw EncryptionError.keychainError(error.localizedDescription)
        }
    }
}

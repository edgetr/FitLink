import Foundation
import CryptoKit
import Combine

#if os(iOS)

/// Service for managing Watch pairing with TOTP-style codes
/// Code is deterministic based on time window - same code within 60-second window
@MainActor
final class WatchPairingService: ObservableObject {
    
    static let shared = WatchPairingService()
    
    // MARK: - Published State
    
    @Published private(set) var currentCode: String = "------"
    @Published private(set) var secondsRemaining: Int = 60
    @Published private(set) var isPairingPageOpen: Bool = false
    @Published private(set) var pendingPairingRequest: Bool = false
    @Published private(set) var isPaired: Bool = false
    
    // MARK: - Private Properties
    
    private var countdownTimer: Timer?
    private let codeValiditySeconds: Int = 60
    private let secretKey = "WatchPairingSecret"
    
    private init() {
        loadPairingState()
        ensureSecretExists()
    }
    
    // MARK: - Public Methods
    
    /// Called when user opens "Pair Apple Watch" page
    func startPairingSession() {
        isPairingPageOpen = true
        pendingPairingRequest = false
        
        // Calculate current code based on time window
        updateCodeForCurrentWindow()
        startCountdownTimer()
        
        log("Pairing session started")
    }
    
    /// Called when user leaves "Pair Apple Watch" page
    func endPairingSession() {
        isPairingPageOpen = false
        pendingPairingRequest = false
        stopCountdownTimer()
        currentCode = "------"
        secondsRemaining = codeValiditySeconds
        
        log("Pairing session ended")
    }
    
    /// Validates a code received from Watch
    /// - Returns: true if code matches and pairing page is open
    func validateCode(_ code: String) -> Bool {
        guard isPairingPageOpen else {
            log("Code rejected: pairing page not open")
            return false
        }
        
        // Recalculate code to ensure it's current
        let expectedCode = generateCodeForWindow(getCurrentWindow())
        
        guard code == expectedCode else {
            log("Code rejected: mismatch (received: \(code), expected: \(expectedCode))")
            return false
        }
        
        // Code matches - show confirmation pending
        pendingPairingRequest = true
        log("Code validated, awaiting user confirmation")
        return true
    }
    
    /// Called when user taps "Allow" on the pairing confirmation
    func confirmPairing() {
        guard pendingPairingRequest else { return }
        
        isPaired = true
        pendingPairingRequest = false
        savePairingState()
        
        // Push auth state to Watch
        Task {
            await WatchConnectivityService.shared.pushStateToWatch()
            await WatchConnectivityService.shared.sendPairingConfirmation()
        }
        
        log("Pairing confirmed and state pushed to Watch")
    }
    
    /// Called when user taps "Deny" on the pairing confirmation
    func denyPairing() {
        pendingPairingRequest = false
        
        Task {
            await WatchConnectivityService.shared.sendPairingDenied()
        }
        
        log("Pairing denied")
    }
    
    /// Unpair the Watch
    func unpair() {
        isPaired = false
        savePairingState()
        
        Task {
            await WatchConnectivityService.shared.sendUnpairCommand()
        }
        
        log("Watch unpaired")
    }
    
    // MARK: - TOTP Code Generation
    
    /// Get current time window (floor of timestamp / 60)
    private func getCurrentWindow() -> UInt64 {
        UInt64(Date().timeIntervalSince1970) / UInt64(codeValiditySeconds)
    }
    
    /// Generate 6-digit code for a given time window using HMAC
    private func generateCodeForWindow(_ window: UInt64) -> String {
        guard let secret = getSecret() else {
            log("No secret found, generating fallback code")
            return "000000"
        }
        
        // Convert window to data (big-endian)
        var windowBigEndian = window.bigEndian
        let windowData = Data(bytes: &windowBigEndian, count: 8)
        
        // Create HMAC-SHA256
        let key = SymmetricKey(data: secret)
        let hmac = HMAC<SHA256>.authenticationCode(for: windowData, using: key)
        let hmacData = Data(hmac)
        
        // Dynamic truncation (HOTP style)
        let offset = Int(hmacData[hmacData.count - 1] & 0x0f)
        let truncatedHash = hmacData.subdata(in: offset..<(offset + 4))
        
        var number: UInt32 = 0
        truncatedHash.withUnsafeBytes { bytes in
            number = bytes.load(as: UInt32.self).bigEndian
        }
        number = number & 0x7FFFFFFF // Clear top bit
        
        // Get 6-digit code
        let code = number % 1_000_000
        return String(format: "%06d", code)
    }
    
    /// Update code for current time window and calculate seconds remaining
    private func updateCodeForCurrentWindow() {
        let window = getCurrentWindow()
        currentCode = generateCodeForWindow(window)
        
        // Calculate seconds remaining in current window
        let currentTimestamp = Date().timeIntervalSince1970
        let windowStart = Double(window) * Double(codeValiditySeconds)
        let elapsed = currentTimestamp - windowStart
        secondsRemaining = max(0, codeValiditySeconds - Int(elapsed))
    }
    
    // MARK: - Secret Management
    
    private func ensureSecretExists() {
        if getSecret() == nil {
            // Generate new 32-byte secret
            var randomBytes = [UInt8](repeating: 0, count: 32)
            _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            let secret = Data(randomBytes)
            saveSecret(secret)
            log("Generated new pairing secret")
        }
    }
    
    private func getSecret() -> Data? {
        if let defaults = UserDefaults(suiteName: WatchSyncConstants.appGroupIdentifier) {
            return defaults.data(forKey: secretKey)
        }
        return nil
    }
    
    private func saveSecret(_ secret: Data) {
        if let defaults = UserDefaults(suiteName: WatchSyncConstants.appGroupIdentifier) {
            defaults.set(secret, forKey: secretKey)
        }
    }
    
    // MARK: - Timer Management
    
    private func startCountdownTimer() {
        stopCountdownTimer()
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    private func tick() {
        if secondsRemaining > 1 {
            secondsRemaining -= 1
        } else {
            // Window expired, generate new code
            updateCodeForCurrentWindow()
        }
    }
    
    // MARK: - Persistence
    
    private func loadPairingState() {
        if let defaults = UserDefaults(suiteName: WatchSyncConstants.appGroupIdentifier) {
            isPaired = defaults.bool(forKey: "watchPaired")
        }
    }
    
    private func savePairingState() {
        if let defaults = UserDefaults(suiteName: WatchSyncConstants.appGroupIdentifier) {
            defaults.set(isPaired, forKey: "watchPaired")
        }
    }
    
    private func log(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [WatchPairingService] \(message)")
        #endif
    }
}

#endif

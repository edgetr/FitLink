import Foundation
import SwiftUI
import Combine

// MARK: - Health Data Storage Policy

/// Defines where health data can be stored.
/// Default is `.onDeviceOnly` for maximum privacy.
enum HealthDataStoragePolicy: String, CaseIterable {
    /// Health data is read from HealthKit and used locally only.
    /// Nothing health-related is sent to Firestore.
    case onDeviceOnly = "on_device_only"
    
    /// Health data is synced to the cloud for cross-device access.
    /// Requires explicit user opt-in.
    case cloudSyncEnabled = "cloud_sync_enabled"
    
    var displayName: String {
        switch self {
        case .onDeviceOnly:
            return "On Device Only"
        case .cloudSyncEnabled:
            return "Cloud Sync Enabled"
        }
    }
    
    var description: String {
        switch self {
        case .onDeviceOnly:
            return "Your health data stays on this device. It's used to personalize your experience but never leaves your phone."
        case .cloudSyncEnabled:
            return "Your health data is synced to the cloud for access across devices. You can delete it anytime."
        }
    }
    
    var icon: String {
        switch self {
        case .onDeviceOnly:
            return "lock.shield.fill"
        case .cloudSyncEnabled:
            return "cloud.fill"
        }
    }
    
    /// Whether cloud writes are allowed under this policy
    var allowsCloudStorage: Bool {
        self == .cloudSyncEnabled
    }
}

// MARK: - Health Data Storage Settings

/// Single source of truth for health data storage preferences.
/// Uses @AppStorage for persistence across app launches.
@MainActor
final class HealthDataStorageSettings: ObservableObject {
    
    static let shared = HealthDataStorageSettings()
    
    private static let policyKey = "health_data_storage_policy"
    private static let lastCloudSyncKey = "health_data_last_cloud_sync"
    private static let cloudDataExistsKey = "health_data_cloud_exists"
    
    /// The current storage policy. Defaults to `.onDeviceOnly` for privacy.
    @AppStorage(HealthDataStorageSettings.policyKey)
    private var storedPolicyRawValue: String = HealthDataStoragePolicy.onDeviceOnly.rawValue
    
    /// Tracks whether user has any data in the cloud (for showing delete option)
    @AppStorage(HealthDataStorageSettings.cloudDataExistsKey)
    var hasCloudData: Bool = false
    
    /// Last time health data was synced to cloud
    @AppStorage(HealthDataStorageSettings.lastCloudSyncKey)
    private var lastCloudSyncTimestamp: Double = 0
    
    /// The current storage policy
    var policy: HealthDataStoragePolicy {
        get {
            HealthDataStoragePolicy(rawValue: storedPolicyRawValue) ?? .onDeviceOnly
        }
        set {
            storedPolicyRawValue = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    /// Whether cloud storage is currently enabled
    var isCloudSyncEnabled: Bool {
        policy == .cloudSyncEnabled
    }
    
    /// Last cloud sync date (nil if never synced)
    var lastCloudSyncDate: Date? {
        guard lastCloudSyncTimestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: lastCloudSyncTimestamp)
    }
    
    private init() {}
    
    /// Enable cloud sync (requires explicit user action)
    func enableCloudSync() {
        policy = .cloudSyncEnabled
        log("Cloud sync enabled by user")
    }
    
    /// Disable cloud sync and optionally trigger data deletion
    func disableCloudSync() {
        policy = .onDeviceOnly
        log("Cloud sync disabled by user")
    }
    
    /// Record that a cloud sync occurred
    func recordCloudSync() {
        lastCloudSyncTimestamp = Date().timeIntervalSince1970
        hasCloudData = true
    }
    
    /// Called after cloud data is deleted
    func recordCloudDataDeleted() {
        hasCloudData = false
        lastCloudSyncTimestamp = 0
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        #if DEBUG
        print("[HealthDataStorageSettings] \(message)")
        #endif
    }
}

// MARK: - Policy Check Extension

extension HealthDataStorageSettings {
    
    /// Check if a cloud operation should proceed.
    /// Returns false and logs if policy doesn't allow cloud storage.
    func shouldAllowCloudOperation(operation: String) -> Bool {
        guard policy.allowsCloudStorage else {
            log("Blocked cloud operation '\(operation)' - policy is \(policy.rawValue)")
            return false
        }
        return true
    }
}

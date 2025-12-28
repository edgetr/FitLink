import SwiftUI
import HealthKit
import CoreLocation
import UserNotifications
import Combine
import Photos
import AVFoundation

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Permission Status Enums

enum HealthPermissionStatus: Equatable {
    case notDetermined
    case authorized
    case denied
    case unavailable
}

enum LocationPermissionStatus: Equatable {
    case notDetermined
    case authorizedWhenInUse
    case authorizedAlways
    case denied
    case restricted
    case unavailable
    
    var isAuthorized: Bool {
        self == .authorizedWhenInUse || self == .authorizedAlways
    }
}

enum NotificationPermissionStatus: Equatable {
    case notDetermined
    case authorized
    case denied
    case provisional
}

enum PhotoLibraryPermissionStatus: Equatable {
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted
}

enum CameraPermissionStatus: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

// MARK: - PermissionCoordinator

/// Central coordinator for all permission requests in FitLink.
/// Ensures permissions are only requested when explicitly triggered by user action,
/// never during app initialization or view model creation.
@MainActor
final class PermissionCoordinator: ObservableObject {
    
    static let shared = PermissionCoordinator()
    
    // MARK: - Published Status
    
    @Published private(set) var healthStatus: HealthPermissionStatus = .notDetermined
    @Published private(set) var locationStatus: LocationPermissionStatus = .notDetermined
    @Published private(set) var notificationStatus: NotificationPermissionStatus = .notDetermined
    @Published private(set) var photoLibraryStatus: PhotoLibraryPermissionStatus = .notDetermined
    @Published private(set) var cameraStatus: CameraPermissionStatus = .notDetermined
    
    // MARK: - Convenience Properties
    
    var isHealthAuthorized: Bool { healthStatus == .authorized }
    var isLocationAuthorized: Bool { locationStatus.isAuthorized }
    var isNotificationAuthorized: Bool { notificationStatus == .authorized || notificationStatus == .provisional }
    var isPhotoLibraryAuthorized: Bool { photoLibraryStatus == .authorized || photoLibraryStatus == .limited }
    var isCameraAuthorized: Bool { cameraStatus == .authorized }
    
    var allPermissionsGranted: Bool {
        isHealthAuthorized && isLocationAuthorized && isNotificationAuthorized
    }
    
    // MARK: - Private Properties
    
    private let healthStore: HKHealthStore?
    private let locationDelegate = LocationPermissionDelegate()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        } else {
            healthStore = nil
            healthStatus = .unavailable
        }
        
        setupLocationDelegate()
        
        // Only check current status, never request during init
        Task {
            await refreshAllStatuses()
        }
    }
    
    // MARK: - Status Refresh (Read-Only)
    
    /// Refresh all permission statuses without requesting any permissions.
    /// Safe to call anytime - will never trigger system prompts.
    func refreshAllStatuses() async {
        checkHealthStatus()
        checkLocationStatus()
        await checkNotificationStatus()
        checkPhotoLibraryStatus()
        checkCameraStatus()
    }
    
    /// Check HealthKit authorization status without requesting.
    func checkHealthStatus() {
        guard let healthStore = healthStore else {
            healthStatus = .unavailable
            return
        }
        
        // Use stepCount as a representative type to check overall status
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            healthStatus = .unavailable
            return
        }
        
        let status = healthStore.authorizationStatus(for: stepType)
        
        switch status {
        case .notDetermined:
            healthStatus = .notDetermined
        case .sharingAuthorized:
            healthStatus = .authorized
        case .sharingDenied:
            healthStatus = .denied
        @unknown default:
            healthStatus = .notDetermined
        }
    }
    
    /// Check location authorization status without requesting.
    func checkLocationStatus() {
        if !CLLocationManager.locationServicesEnabled() {
            locationStatus = .unavailable
            return
        }
        
        let status = locationDelegate.locationManager.authorizationStatus
        locationStatus = mapCLAuthorizationStatus(status)
    }
    
    /// Check notification authorization status without requesting.
    func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = mapUNAuthorizationStatus(settings.authorizationStatus)
    }
    
    // MARK: - Permission Requests
    
    /// Request HealthKit authorization.
    /// Should only be called from onboarding steps or explicit user actions.
    /// - Returns: true if authorization was granted
    func requestHealth() async -> Bool {
        guard let healthStore = healthStore else {
            healthStatus = .unavailable
            return false
        }
        
        var typesToRead: Set<HKObjectType> = []
        
        // Quantity types
        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .activeEnergyBurned,
            .basalEnergyBurned,
            .appleExerciseTime,
            .appleStandTime,
            .distanceWalkingRunning,
            .flightsClimbed,
            .heartRate,
            .restingHeartRate,
            .heartRateVariabilitySDNN,
            .height,
            .bodyMass
        ]
        
        for identifier in quantityIdentifiers {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                typesToRead.insert(type)
            }
        }
        
        // Category types
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            typesToRead.insert(sleepType)
        }
        
        // Workout type
        typesToRead.insert(HKWorkoutType.workoutType())
        
        // Characteristics
        if let dobType = HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth) {
            typesToRead.insert(dobType)
        }
        if let sexType = HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex) {
            typesToRead.insert(sexType)
        }
        
        // Activity summary
        typesToRead.insert(HKActivitySummaryType.activitySummaryType())
        
        guard !typesToRead.isEmpty else {
            healthStatus = .unavailable
            return false
        }
        
        do {
            try await healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: typesToRead)
            healthStatus = .authorized
            return true
        } catch {
            debugLog("HealthKit authorization failed: \(error.localizedDescription)")
            healthStatus = .denied
            return false
        }
    }
    
    /// Request location authorization (when in use).
    /// Should only be called from onboarding steps or explicit user actions.
    /// - Returns: true if authorization was granted
    func requestLocation() async -> Bool {
        if !CLLocationManager.locationServicesEnabled() {
            locationStatus = .unavailable
            return false
        }
        
        let currentStatus = locationDelegate.locationManager.authorizationStatus
        
        if currentStatus == .notDetermined {
            locationDelegate.locationManager.requestWhenInUseAuthorization()
            
            // Wait for authorization status change
            return await withCheckedContinuation { continuation in
                locationDelegate.onAuthorizationChange = { [weak self] status in
                    guard let self = self else {
                        continuation.resume(returning: false)
                        return
                    }
                    self.locationStatus = self.mapCLAuthorizationStatus(status)
                    continuation.resume(returning: self.locationStatus.isAuthorized)
                }
            }
        }
        
        locationStatus = mapCLAuthorizationStatus(currentStatus)
        return locationStatus.isAuthorized
    }
    
    /// Request notification authorization.
    /// Should only be called from onboarding steps or explicit user actions.
    /// - Returns: true if authorization was granted
    func requestNotifications() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            notificationStatus = granted ? .authorized : .denied
            return granted
        } catch {
            debugLog("Notification authorization failed: \(error.localizedDescription)")
            notificationStatus = .denied
            return false
        }
    }
    
    // MARK: - Photo Library Permissions
    
    func checkPhotoLibraryStatus() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photoLibraryStatus = mapPHAuthorizationStatus(status)
    }
    
    func requestPhotoLibrary() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        photoLibraryStatus = mapPHAuthorizationStatus(status)
        return isPhotoLibraryAuthorized
    }
    
    // MARK: - Camera Permissions
    
    func checkCameraStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraStatus = mapAVAuthorizationStatus(status)
    }
    
    func requestCamera() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraStatus = granted ? .authorized : .denied
        return granted
    }
    
    // MARK: - Open Settings
    
    func openAppSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
    
    /// Open the Health app.
    func openHealthSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: "x-apple-health://") else { return }
        UIApplication.shared.open(url)
        #endif
    }
    
    // MARK: - Private Helpers
    
    private func setupLocationDelegate() {
        locationDelegate.onAuthorizationChange = { [weak self] status in
            guard let self = self else { return }
            Task { @MainActor in
                self.locationStatus = self.mapCLAuthorizationStatus(status)
            }
        }
    }
    
    private func mapCLAuthorizationStatus(_ status: CLAuthorizationStatus) -> LocationPermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorizedWhenInUse:
            return .authorizedWhenInUse
        case .authorizedAlways:
            return .authorizedAlways
        @unknown default:
            return .notDetermined
        }
    }
    
    private func mapUNAuthorizationStatus(_ status: UNAuthorizationStatus) -> NotificationPermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }
    
    private func mapPHAuthorizationStatus(_ status: PHAuthorizationStatus) -> PhotoLibraryPermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        @unknown default:
            return .notDetermined
        }
    }
    
    private func mapAVAuthorizationStatus(_ status: AVAuthorizationStatus) -> CameraPermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }
    
    private func debugLog(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [PermissionCoordinator] \(message)")
        #endif
    }
}

// MARK: - Location Permission Delegate

private class LocationPermissionDelegate: NSObject, CLLocationManagerDelegate {
    
    let locationManager = CLLocationManager()
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorizationChange?(manager.authorizationStatus)
    }
}

// MARK: - Environment Key

private struct PermissionCoordinatorKey: EnvironmentKey {
    static let defaultValue: PermissionCoordinator = .shared
}

extension EnvironmentValues {
    var permissionCoordinator: PermissionCoordinator {
        get { self[PermissionCoordinatorKey.self] }
        set { self[PermissionCoordinatorKey.self] = newValue }
    }
}

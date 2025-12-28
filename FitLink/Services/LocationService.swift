import Foundation
import CoreLocation
import Combine

/// CLLocationManager wrapper for location-based features
/// Used for localized recipe suggestions and location-aware content
final class LocationService: NSObject, ObservableObject {
    
    static let shared = LocationService()
    
    // MARK: - Published Properties
    
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var currentCity: String?
    @Published private(set) var currentCountry: String?
    
    // MARK: - Private Properties
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer // Low accuracy for recipes
        locationManager.distanceFilter = 1000 // Update every 1km
        
        // Update authorization status
        authorizationStatus = locationManager.authorizationStatus
        updateAuthorizationState()
    }
    
    // MARK: - Public Methods
    
    /// Request location authorization if not yet determined
    func requestAuthorizationIfNeeded() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            errorMessage = "Location access denied. Enable in Settings to get localized recipe suggestions."
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        @unknown default:
            break
        }
    }
    
    /// Request location authorization and wait for result
    func requestAuthorization() async -> Bool {
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            
            // Wait for authorization status to change
            return await withCheckedContinuation { continuation in
                $authorizationStatus
                    .dropFirst()
                    .first()
                    .sink { status in
                        let authorized = status == .authorizedWhenInUse || status == .authorizedAlways
                        continuation.resume(returning: authorized)
                    }
                    .store(in: &cancellables)
            }
        }
        
        return isAuthorized
    }
    
    /// Start updating location
    func startUpdatingLocation() {
        guard isAuthorized else {
            requestAuthorizationIfNeeded()
            return
        }
        locationManager.startUpdatingLocation()
    }
    
    /// Stop updating location to save battery
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    /// Request a single location update
    func requestSingleLocation() {
        guard isAuthorized else {
            requestAuthorizationIfNeeded()
            return
        }
        locationManager.requestLocation()
    }
    
    /// Get current location asynchronously
    func getCurrentLocation() async -> CLLocation? {
        if let location = currentLocation {
            return location
        }
        
        guard isAuthorized else {
            let authorized = await requestAuthorization()
            guard authorized else { return nil }
            return await getCurrentLocation()
        }
        
        locationManager.requestLocation()
        
        // Wait for location update
        return await withCheckedContinuation { continuation in
            $currentLocation
                .compactMap { $0 }
                .first()
                .sink { location in
                    continuation.resume(returning: location)
                }
                .store(in: &cancellables)
        }
    }
    
    /// Get the user's region/locale for localized content
    func getUserRegion() -> String {
        if let country = currentCountry {
            return country
        }
        return Locale.current.region?.identifier ?? "US"
    }
    
    /// Get distance from current location to a coordinate
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let current = currentLocation else { return nil }
        let destination = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return current.distance(from: destination)
    }
    
    // MARK: - Private Methods
    
    private func updateAuthorizationState() {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
            errorMessage = nil
        case .denied:
            isAuthorized = false
            errorMessage = "Location access denied. Enable in Settings for localized features."
        case .restricted:
            isAuthorized = false
            errorMessage = "Location access is restricted on this device."
        case .notDetermined:
            isAuthorized = false
            errorMessage = nil
        @unknown default:
            isAuthorized = false
        }
    }
    
    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            if let error = error {
                AppLogger.shared.debug("Geocoding error: \(error.localizedDescription)", category: .location)
                return
            }
            
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    self.currentCity = placemark.locality
                    self.currentCountry = placemark.country
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            self.updateAuthorizationState()
            
            if self.isAuthorized {
                self.startUpdatingLocation()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.currentLocation = location
            self.errorMessage = nil
        }
        
        // Reverse geocode for city/country
        reverseGeocode(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        AppLogger.shared.warning("Location update failed: \(error.localizedDescription)", category: .location)
        
        let clError = error as? CLError
        switch clError?.code {
        case .denied:
            DispatchQueue.main.async {
                self.errorMessage = "Location access denied."
            }
        case .locationUnknown:
            // Temporary error, will retry automatically
            break
        default:
            DispatchQueue.main.async {
                self.errorMessage = "Unable to determine location."
            }
        }
    }
}

// MARK: - Location Helpers

extension LocationService {
    
    /// Check if location services are enabled globally
    static var isLocationServicesEnabled: Bool {
        CLLocationManager.locationServicesEnabled()
    }
    
    /// Format distance for display
    static func formatDistance(_ meters: CLLocationDistance) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.unitStyle = .medium
        
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        return formatter.string(from: measurement)
    }
}

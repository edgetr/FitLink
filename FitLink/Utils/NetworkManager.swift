//
//  NetworkManager.swift
//  FitLink
//
//  Created on 25.12.2025.
//

import Foundation
import Network
import Combine

/// Monitors network reachability using NWPathMonitor and provides connectivity status.
/// Uses a singleton pattern for app-wide access.
final class NetworkManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = NetworkManager()
    
    // MARK: - Published Properties
    
    /// Current online status - true if network is available
    @Published private(set) var isOnline: Bool = true
    
    /// Current connection type
    @Published private(set) var connectionType: ConnectionType = .unknown
    
    /// Whether the connection is expensive (cellular, hotspot)
    @Published private(set) var isExpensive: Bool = false
    
    /// Whether the connection is constrained (Low Data Mode)
    @Published private(set) var isConstrained: Bool = false
    
    // MARK: - Connection Type
    
    enum ConnectionType: String {
        case wifi = "WiFi"
        case cellular = "Cellular"
        case wiredEthernet = "Ethernet"
        case unknown = "Unknown"
        case none = "No Connection"
    }
    
    // MARK: - Private Properties
    
    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.fitlink.networkmonitor", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Notifications
    
    /// Posted when network becomes available
    static let networkDidBecomeAvailable = Notification.Name("NetworkDidBecomeAvailable")
    
    /// Posted when network becomes unavailable
    static let networkDidBecomeUnavailable = Notification.Name("NetworkDidBecomeUnavailable")
    
    // MARK: - Initialization
    
    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Starts network monitoring
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: monitorQueue)
        log("Network monitoring started")
    }
    
    /// Stops network monitoring
    func stopMonitoring() {
        monitor.cancel()
        log("Network monitoring stopped")
    }
    
    /// Checks if a specific host is reachable
    /// - Parameter host: The hostname to check
    /// - Returns: True if the host is reachable
    func checkHostReachability(host: String) async -> Bool {
        guard isOnline else { return false }
        
        guard let url = URL(string: "https://\(host)") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return (200...399).contains(httpResponse.statusCode)
            }
            return false
        } catch {
            log("Host reachability check failed for \(host): \(error.localizedDescription)")
            return false
        }
    }
    
    /// Waits for network to become available with timeout
    /// - Parameter timeout: Maximum time to wait in seconds
    /// - Returns: True if network became available within timeout
    func waitForConnectivity(timeout: TimeInterval = 30) async -> Bool {
        if isOnline { return true }
        
        return await withCheckedContinuation { continuation in
            var didResume = false
            let timeoutTask = DispatchWorkItem {
                if !didResume {
                    didResume = true
                    continuation.resume(returning: false)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutTask)
            
            $isOnline
                .filter { $0 }
                .first()
                .sink { _ in
                    timeoutTask.cancel()
                    if !didResume {
                        didResume = true
                        continuation.resume(returning: true)
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Private Methods
    
    private func handlePathUpdate(_ path: NWPath) {
        let wasOnline = isOnline
        let newOnlineStatus = path.status == .satisfied
        
        isOnline = newOnlineStatus
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        connectionType = determineConnectionType(path)
        
        // Post notifications on status change
        if wasOnline != newOnlineStatus {
            if newOnlineStatus {
                NotificationCenter.default.post(name: Self.networkDidBecomeAvailable, object: nil)
                log("Network became available (\(connectionType.rawValue))")
            } else {
                NotificationCenter.default.post(name: Self.networkDidBecomeUnavailable, object: nil)
                log("Network became unavailable")
            }
        }
    }
    
    private func determineConnectionType(_ path: NWPath) -> ConnectionType {
        guard path.status == .satisfied else {
            return .none
        }
        
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        } else {
            return .unknown
        }
    }
    
    private func log(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [NetworkManager] \(message)")
        #endif
    }
}

// MARK: - SwiftUI Environment Key

import SwiftUI

private struct NetworkManagerKey: EnvironmentKey {
    static let defaultValue = NetworkManager.shared
}

extension EnvironmentValues {
    var networkManager: NetworkManager {
        get { self[NetworkManagerKey.self] }
        set { self[NetworkManagerKey.self] = newValue }
    }
}

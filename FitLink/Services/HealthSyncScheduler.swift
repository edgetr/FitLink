import BackgroundTasks
import UIKit

// MARK: - HealthSyncScheduler

final class HealthSyncScheduler {
    
    static let shared = HealthSyncScheduler()
    
    private let syncTaskIdentifier = "com.edgetr.FitLink.healthsync"
    private let collector = HealthDataCollector.shared
    private let lastSyncKeyPrefix = "last_health_sync_"
    private let currentUserKey = "current_user_id"
    
    @MainActor
    private var storageSettings: HealthDataStorageSettings { HealthDataStorageSettings.shared }
    
    private init() {}
    
    // MARK: - Register Background Task
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: syncTaskIdentifier,
            using: nil
        ) { task in
            self.handleHealthSync(task: task as? BGProcessingTask)
        }
    }
    
    // MARK: - Schedule Next Sync
    
    func scheduleBackgroundSync() {
        let request = BGProcessingTaskRequest(identifier: syncTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        let calendar = Calendar.current
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
           let scheduledDate = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: tomorrow) {
            request.earliestBeginDate = scheduledDate
        }
        
        do {
            try BGTaskScheduler.shared.submit(request)
            log("Background sync scheduled")
        } catch {
            log("Failed to schedule background sync: \(error)")
        }
    }
    
    // MARK: - Handle Background Sync
    
    private func handleHealthSync(task: BGProcessingTask?) {
        guard let task = task else { return }
        
        scheduleBackgroundSync()
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            do {
                guard let userId = UserDefaults.standard.string(forKey: currentUserKey) else {
                    task.setTaskCompleted(success: false)
                    return
                }
                
                try await collector.performDailySync(userId: userId)
                task.setTaskCompleted(success: true)
                log("Background sync completed successfully")
            } catch {
                log("Background sync failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    // MARK: - Foreground Sync
    
    func performForegroundSync(userId: String) async {
        do {
            let lastSyncKey = "\(lastSyncKeyPrefix)\(userId)"
            let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
            
            if lastSync == nil {
                try await collector.performInitialSync(userId: userId)
            } else {
                try await collector.performDailySync(userId: userId)
            }
            
            UserDefaults.standard.set(Date(), forKey: lastSyncKey)
        } catch {
            log("Foreground sync failed: \(error)")
        }
    }
    
    // MARK: - Check If Sync Needed
    
    func shouldPerformSync(userId: String) -> Bool {
        let lastSyncKey = "\(lastSyncKeyPrefix)\(userId)"
        let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date ?? .distantPast
        let hoursSinceSync = Date().timeIntervalSince(lastSync) / 3600
        return hoursSinceSync >= 1
    }
    
    // MARK: - Store Current User
    
    func setCurrentUser(_ userId: String) {
        UserDefaults.standard.set(userId, forKey: currentUserKey)
    }
    
    func clearCurrentUser() {
        UserDefaults.standard.removeObject(forKey: currentUserKey)
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        #if DEBUG
        print("[HealthSyncScheduler] \(message)")
        #endif
    }
}

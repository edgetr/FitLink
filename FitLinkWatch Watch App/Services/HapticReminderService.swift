import Foundation
import Combine
import UserNotifications
import WatchKit

#if os(watchOS)

@MainActor
final class HapticReminderService: ObservableObject {
    
    static let shared = HapticReminderService()
    
    @Published private(set) var isEnabled: Bool = true
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    
    private let kHapticRemindersEnabled = "HapticRemindersEnabled"
    
    private init() {
        isEnabled = defaults.bool(forKey: kHapticRemindersEnabled)
        if defaults.object(forKey: kHapticRemindersEnabled) == nil {
            isEnabled = true
            defaults.set(true, forKey: kHapticRemindersEnabled)
        }
    }
    
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound])
            log("Notification permission: \(granted)")
            return granted
        } catch {
            log("Notification permission error: \(error.localizedDescription)")
            return false
        }
    }
    
    func scheduleHabitReminder(habitId: String, habitName: String, at time: Date) {
        guard isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Time for \(habitName)"
        content.body = "Tap to start your focus session"
        content.sound = .default
        content.categoryIdentifier = "HABIT_REMINDER"
        content.userInfo = ["habitId": habitId]
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "habit_\(habitId)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { [weak self] error in
            if let error = error {
                self?.log("Failed to schedule reminder: \(error.localizedDescription)")
            } else {
                self?.log("Scheduled reminder for \(habitName) at \(components)")
            }
        }
    }
    
    func cancelHabitReminder(habitId: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["habit_\(habitId)"])
        log("Cancelled reminder for habit: \(habitId)")
    }
    
    func cancelAllReminders() {
        notificationCenter.removeAllPendingNotificationRequests()
        log("Cancelled all reminders")
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: kHapticRemindersEnabled)
        
        if !enabled {
            cancelAllReminders()
        }
        
        log("Haptic reminders \(enabled ? "enabled" : "disabled")")
    }
    
    func playHaptic(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
    
    func playSuccessHaptic() {
        playHaptic(.success)
    }
    
    func playNotificationHaptic() {
        playHaptic(.notification)
    }
    
    func playStartHaptic() {
        playHaptic(.start)
    }
    
    func playStopHaptic() {
        playHaptic(.stop)
    }
    
    private func log(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [HapticReminderService] \(message)")
        #endif
    }
}

#endif

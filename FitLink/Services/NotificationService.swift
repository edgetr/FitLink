import Foundation
import UserNotifications
import UIKit
import Combine

/// UNUserNotificationCenter wrapper for scheduling and managing local notifications
/// Handles reminders, habit notifications, meal prep alerts, and workout prompts
final class NotificationService: NSObject, ObservableObject {
    
    static let shared = NotificationService()
    
    // MARK: - Published Properties
    
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var errorMessage: String?
    
    // MARK: - Notification Categories
    
    enum NotificationCategory: String {
        case habitReminder = "HABIT_REMINDER"
        case mealPrep = "MEAL_PREP"
        case workoutReminder = "WORKOUT_REMINDER"
        case focusSession = "FOCUS_SESSION"
        case friendRequest = "FRIEND_REQUEST"
        case dailySummary = "DAILY_SUMMARY"
        case streak = "STREAK_ALERT"
        case planComplete = "PLAN_COMPLETE"
    }
    
    // MARK: - Notification Actions
    
    enum NotificationAction: String {
        case complete = "COMPLETE_ACTION"
        case snooze = "SNOOZE_ACTION"
        case skip = "SKIP_ACTION"
        case view = "VIEW_ACTION"
        case dismiss = "DISMISS_ACTION"
    }
    
    // MARK: - Private Properties
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        notificationCenter.delegate = self
        checkAuthorizationStatus()
        setupNotificationCategories()
    }
    
    // MARK: - Authorization
    
    /// Check current authorization status
    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    /// Request notification authorization if not yet determined
    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        
        switch settings.authorizationStatus {
        case .notDetermined:
            return await requestAuthorization()
        case .authorized, .provisional, .ephemeral:
            DispatchQueue.main.async {
                self.isAuthorized = true
                self.authorizationStatus = settings.authorizationStatus
            }
            return true
        case .denied:
            DispatchQueue.main.async {
                self.isAuthorized = false
                self.authorizationStatus = .denied
                self.errorMessage = "Notifications are disabled. Enable in Settings to receive reminders."
            }
            return false
        @unknown default:
            return false
        }
    }
    
    /// Request notification permission
    private func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge, .provisional]
            let granted = try await notificationCenter.requestAuthorization(options: options)
            
            DispatchQueue.main.async {
                self.isAuthorized = granted
                self.authorizationStatus = granted ? .authorized : .denied
            }
            
            return granted
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to request notification permission: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    // MARK: - Setup Categories
    
    private func setupNotificationCategories() {
        // Habit Reminder Actions
        let completeAction = UNNotificationAction(
            identifier: NotificationAction.complete.rawValue,
            title: "Complete",
            options: [.foreground]
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: NotificationAction.snooze.rawValue,
            title: "Snooze 15 min",
            options: []
        )
        
        let skipAction = UNNotificationAction(
            identifier: NotificationAction.skip.rawValue,
            title: "Skip Today",
            options: [.destructive]
        )
        
        let habitCategory = UNNotificationCategory(
            identifier: NotificationCategory.habitReminder.rawValue,
            actions: [completeAction, snoozeAction, skipAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Meal Prep Actions
        let viewAction = UNNotificationAction(
            identifier: NotificationAction.view.rawValue,
            title: "View Recipe",
            options: [.foreground]
        )
        
        let mealCategory = UNNotificationCategory(
            identifier: NotificationCategory.mealPrep.rawValue,
            actions: [viewAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Workout Reminder Actions
        let workoutCategory = UNNotificationCategory(
            identifier: NotificationCategory.workoutReminder.rawValue,
            actions: [viewAction, snoozeAction, skipAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Focus Session Actions
        let focusCategory = UNNotificationCategory(
            identifier: NotificationCategory.focusSession.rawValue,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Friend Request Actions
        let friendCategory = UNNotificationCategory(
            identifier: NotificationCategory.friendRequest.rawValue,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Plan Complete Actions
        let viewPlanAction = UNNotificationAction(
            identifier: NotificationAction.view.rawValue,
            title: "View Plan",
            options: [.foreground]
        )
        
        let planCompleteCategory = UNNotificationCategory(
            identifier: NotificationCategory.planComplete.rawValue,
            actions: [viewPlanAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([
            habitCategory,
            mealCategory,
            workoutCategory,
            focusCategory,
            friendCategory,
            planCompleteCategory
        ])
    }
    
    // MARK: - Schedule Notifications
    
    /// Schedule a habit reminder notification
    /// - Parameters:
    ///   - habitId: The unique identifier for the habit
    ///   - habitName: The name of the habit
    ///   - hour: The hour to remind (24-hour format)
    ///   - minute: The minute to remind
    ///   - weekdays: Which days to remind (1 = Sunday, 7 = Saturday). Empty for daily.
    func scheduleHabitReminder(
        habitId: String,
        habitName: String,
        hour: Int,
        minute: Int,
        weekdays: [Int] = []
    ) async throws {
        if !isAuthorized {
            let authorized = await requestAuthorizationIfNeeded()
            guard authorized else { throw NotificationError.notAuthorized }
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Habit Reminder"
        content.body = "Time to complete: \(habitName)"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.habitReminder.rawValue
        content.userInfo = ["habitId": habitId, "type": "habit"]
        
        if weekdays.isEmpty {
            // Daily reminder
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "habit-\(habitId)",
                content: content,
                trigger: trigger
            )
            
            try await notificationCenter.add(request)
        } else {
            // Specific weekdays
            for weekday in weekdays {
                var dateComponents = DateComponents()
                dateComponents.hour = hour
                dateComponents.minute = minute
                dateComponents.weekday = weekday
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "habit-\(habitId)-\(weekday)",
                    content: content,
                    trigger: trigger
                )
                
                try await notificationCenter.add(request)
            }
        }
    }
    
    /// Schedule a meal prep reminder
    /// - Parameters:
    ///   - mealId: The unique identifier for the meal
    ///   - mealName: The name of the meal/recipe
    ///   - prepTime: Time in minutes before meal to remind
    ///   - mealDate: The date and time of the meal
    func scheduleMealPrepReminder(
        mealId: String,
        mealName: String,
        prepTime: Int,
        mealDate: Date
    ) async throws {
        if !isAuthorized {
            let authorized = await requestAuthorizationIfNeeded()
            guard authorized else { throw NotificationError.notAuthorized }
        }
        
        let reminderDate = Calendar.current.date(byAdding: .minute, value: -prepTime, to: mealDate) ?? mealDate
        
        let content = UNMutableNotificationContent()
        content.title = "Meal Prep Reminder"
        content.body = "Start preparing: \(mealName)"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.mealPrep.rawValue
        content.userInfo = ["mealId": mealId, "type": "meal"]
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "meal-\(mealId)",
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
    }
    
    /// Schedule a workout reminder
    /// - Parameters:
    ///   - workoutDay: The day number (1-7)
    ///   - focusAreas: The focus areas for the workout (e.g., ["Chest", "Triceps"])
    ///   - hour: The hour to remind
    ///   - minute: The minute to remind
    func scheduleWorkoutReminder(
        workoutDay: Int,
        focusAreas: [String],
        hour: Int,
        minute: Int
    ) async throws {
        if !isAuthorized {
            let authorized = await requestAuthorizationIfNeeded()
            guard authorized else { throw NotificationError.notAuthorized }
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Workout Time!"
        content.body = focusAreas.isEmpty 
            ? "Time for your workout"
            : "Today's focus: \(focusAreas.joined(separator: ", "))"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.workoutReminder.rawValue
        content.userInfo = ["day": workoutDay, "type": "workout"]
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.weekday = workoutDay
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "workout-\(workoutDay)",
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
    }
    
    /// Schedule a focus session completion notification
    /// - Parameters:
    ///   - habitName: The name of the habit being focused on
    ///   - duration: Duration in seconds until notification
    func scheduleFocusSessionComplete(
        habitName: String,
        duration: TimeInterval
    ) async throws {
        if !isAuthorized {
            let authorized = await requestAuthorizationIfNeeded()
            guard authorized else { throw NotificationError.notAuthorized }
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Focus Session Complete! 🎉"
        content.body = "Great job focusing on: \(habitName)"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.focusSession.rawValue
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        let request = UNNotificationRequest(
            identifier: "focus-session",
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
    }
    
    /// Schedule a friend request notification
    /// - Parameters:
    ///   - fromName: The name of the person who sent the request
    ///   - requestId: The request identifier
    func scheduleNewFriendRequest(fromName: String, requestId: String) async throws {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "New Friend Request"
        content.body = "\(fromName) wants to connect with you!"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.friendRequest.rawValue
        content.userInfo = ["requestId": requestId, "type": "friend"]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "friend-\(requestId)",
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
    }
    
    /// Schedule a streak reminder when user might break their streak
    /// - Parameters:
    ///   - habitName: The name of the habit
    ///   - currentStreak: The current streak count
    func scheduleStreakReminder(habitName: String, currentStreak: Int) async throws {
        guard isAuthorized, currentStreak >= 3 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Don't Break Your Streak! 🔥"
        content.body = "You have a \(currentStreak)-day streak on \(habitName). Complete it today!"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.streak.rawValue
        
        // Schedule for 8 PM if not completed
        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "streak-\(habitName.hashValue)",
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
    }
    
    // MARK: - Plan Completion Notifications
    
    /// Schedule a notification when AI plan generation completes
    /// - Parameters:
    ///   - planType: The type of plan that was generated
    ///   - planName: Display name for the plan
    func schedulePlanCompleteNotification(
        planType: GenerationPlanType,
        planName: String
    ) async throws {
        if !isAuthorized {
            let authorized = await requestAuthorizationIfNeeded()
            guard authorized else { throw NotificationError.notAuthorized }
        }
        
        let content = UNMutableNotificationContent()
        content.title = planType.notificationTitle
        content.body = "Tap to view your personalized \(planName.lowercased())."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.planComplete.rawValue
        content.userInfo = [
            "type": "plan_complete",
            "planType": planType.rawValue
        ]
        content.badge = 1
        
        // Trigger immediately (1 second delay for reliability)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "plan-complete-\(planType.rawValue)-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
        
        log("Scheduled plan complete notification for \(planType.rawValue)")
    }
    
    /// Cancel pending plan completion notifications
    func cancelPlanCompleteNotifications() {
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let identifiers = requests
                .filter { $0.identifier.hasPrefix("plan-complete-") }
                .map { $0.identifier }
            self?.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
    
    // MARK: - Cancel Notifications
    
    /// Cancel a specific notification by identifier
    func cancelNotification(identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    /// Cancel all notifications for a habit
    func cancelHabitNotifications(habitId: String) {
        let prefix = "habit-\(habitId)"
        
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let identifiers = requests
                .filter { $0.identifier.hasPrefix(prefix) }
                .map { $0.identifier }
            self?.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
    
    /// Cancel all workout reminders
    func cancelAllWorkoutReminders() {
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let identifiers = requests
                .filter { $0.identifier.hasPrefix("workout-") }
                .map { $0.identifier }
            self?.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
    
    /// Cancel all meal prep reminders
    func cancelAllMealReminders() {
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let identifiers = requests
                .filter { $0.identifier.hasPrefix("meal-") }
                .map { $0.identifier }
            self?.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
    
    /// Cancel all pending notifications
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
    
    // MARK: - Badge Management
    
    /// Update the app badge count
    @MainActor
    func setBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { error in
            if let error = error {
                AppLogger.shared.error("Failed to set badge: \(error.localizedDescription)", category: .notification)
            }
        }
    }
    
    /// Clear the app badge
    @MainActor
    func clearBadge() {
        setBadgeCount(0)
    }
    
    // MARK: - Immediate Local Notifications
    
    /// Send an immediate local notification
    /// - Parameters:
    ///   - title: The notification title
    ///   - body: The notification body message
    ///   - category: Optional notification category
    func sendLocalNotification(
        title: String,
        body: String,
        category: NotificationCategory? = nil
    ) {
        guard isAuthorized else {
            log("Cannot send notification - not authorized")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        if let category = category {
            content.categoryIdentifier = category.rawValue
        }
        
        // Trigger immediately (1 second delay for reliability)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { [weak self] error in
            if let error = error {
                self?.log("Failed to send notification: \(error.localizedDescription)")
            } else {
                self?.log("Sent notification: \(title)")
            }
        }
    }
    
    // MARK: - Pending Notifications
    
    /// Get all pending notification requests
    func getPendingNotifications() async -> [UNNotificationRequest] {
        await notificationCenter.pendingNotificationRequests()
    }
    
    /// Get all delivered notifications
    func getDeliveredNotifications() async -> [UNNotification] {
        await notificationCenter.deliveredNotifications()
    }
    
    // MARK: - Private Helpers
    
    private func log(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [NotificationService] \(message)")
        #endif
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Handle notification action response
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        // Check if this is a plan complete notification
        if let type = userInfo["type"] as? String, type == "plan_complete" {
            if let planTypeRaw = userInfo["planType"] as? String {
                // Post notification to navigate to the appropriate view
                NotificationCenter.default.post(
                    name: .navigateToPlan,
                    object: nil,
                    userInfo: ["planType": planTypeRaw]
                )
            }
        }
        
        // Post general notification for app to handle
        NotificationCenter.default.post(
            name: .didReceiveNotificationAction,
            object: nil,
            userInfo: [
                "action": actionIdentifier,
                "userInfo": userInfo
            ]
        )
        
        completionHandler()
    }
}

// MARK: - Error Types

enum NotificationError: LocalizedError {
    case notAuthorized
    case schedulingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Notification permission not granted. Please enable notifications in Settings."
        case .schedulingFailed(let reason):
            return "Failed to schedule notification: \(reason)"
        }
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let didReceiveNotificationAction = Notification.Name("didReceiveNotificationAction")
    static let planGenerationCompleted = Notification.Name("planGenerationCompleted")
    static let navigateToPlan = Notification.Name("navigateToPlan")
}

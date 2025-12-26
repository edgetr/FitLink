import Foundation

final class StreakManager {
    
    static let shared = StreakManager()
    
    private let calendar = Calendar.current
    private let appUsageKey = "FitLink_AppUsageDates"
    
    private init() {}
    
    func recordAppUsage() {
        var dates = getAppUsageDates()
        let today = calendar.startOfDay(for: Date())
        
        if !dates.contains(where: { calendar.isDate($0, inSameDayAs: today) }) {
            dates.append(today)
            saveAppUsageDates(dates)
        }
    }
    
    func getAppStreak() -> Int {
        let dates = getAppUsageDates()
        guard !dates.isEmpty else { return 0 }
        
        let sortedDates = Set(dates.map { calendar.startOfDay(for: $0) }).sorted(by: >)
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        guard let mostRecent = sortedDates.first,
              mostRecent == today || mostRecent == yesterday else {
            return 0
        }
        
        var streak = 0
        var currentDate = mostRecent
        
        for date in sortedDates {
            if date == currentDate {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else if date < currentDate {
                break
            }
        }
        
        return streak
    }
    
    private func getAppUsageDates() -> [Date] {
        guard let data = UserDefaults.standard.data(forKey: appUsageKey),
              let dates = try? JSONDecoder().decode([Date].self, from: data) else {
            return []
        }
        return dates
    }
    
    private func saveAppUsageDates(_ dates: [Date]) {
        if let data = try? JSONEncoder().encode(dates) {
            UserDefaults.standard.set(data, forKey: appUsageKey)
        }
    }
    
    struct HabitData {
        let completionDates: [Date]
        let createdAt: Date
    }
    
    // MARK: - Current Streak
    
    /// Calculate the current streak for a habit
    /// Current streak counts consecutive days of completion ending today (or yesterday if today not yet completed)
    /// - Parameter habitData: The habit data containing completion dates
    /// - Returns: The number of consecutive days in the current streak
    func getCurrentStreak(for habitData: HabitData) -> Int {
        let completionDates = habitData.completionDates.map { normalizeDate($0) }
        guard !completionDates.isEmpty else { return 0 }
        
        let sortedDates = Set(completionDates).sorted(by: >)
        let today = normalizeDate(Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // Check if streak is still active (completed today or yesterday)
        guard let mostRecent = sortedDates.first,
              mostRecent == today || mostRecent == yesterday else {
            return 0
        }
        
        var streak = 0
        var currentDate = mostRecent
        
        for date in sortedDates {
            if date == currentDate {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else if date < currentDate {
                // Gap in streak, stop counting
                break
            }
        }
        
        return streak
    }
    
    /// Calculate the current streak ending with a specific date
    /// - Parameters:
    ///   - habitData: The habit data containing completion dates
    ///   - endingAt: The date to check streak ending at
    /// - Returns: The number of consecutive days
    func getCurrentStreak(for habitData: HabitData, endingAt: Date) -> Int {
        let completionDates = habitData.completionDates.map { normalizeDate($0) }
        guard !completionDates.isEmpty else { return 0 }
        
        let sortedDates = Set(completionDates).sorted(by: >)
        let targetDate = normalizeDate(endingAt)
        
        guard sortedDates.contains(targetDate) else { return 0 }
        
        var streak = 0
        var currentDate = targetDate
        
        for date in sortedDates.filter({ $0 <= targetDate }).sorted(by: >) {
            if date == currentDate {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else if date < currentDate {
                break
            }
        }
        
        return streak
    }
    
    // MARK: - Longest Streak
    
    /// Calculate the longest streak for a habit
    /// - Parameter habitData: The habit data containing completion dates
    /// - Returns: The number of consecutive days in the longest streak
    func getLongestStreak(for habitData: HabitData) -> Int {
        let completionDates = habitData.completionDates.map { normalizeDate($0) }
        guard !completionDates.isEmpty else { return 0 }
        
        let sortedDates = Set(completionDates).sorted()
        
        var longestStreak = 1
        var currentStreak = 1
        var previousDate = sortedDates[0]
        
        for i in 1..<sortedDates.count {
            let currentDate = sortedDates[i]
            let expectedNextDay = calendar.date(byAdding: .day, value: 1, to: previousDate)!
            
            if currentDate == expectedNextDay {
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                currentStreak = 1
            }
            
            previousDate = currentDate
        }
        
        return longestStreak
    }
    
    // MARK: - Additional Statistics
    
    /// Get the total number of completed days
    /// - Parameter habitData: The habit data containing completion dates
    /// - Returns: The total number of unique days with completions
    func getTotalCompletedDays(for habitData: HabitData) -> Int {
        let uniqueDates = Set(habitData.completionDates.map { normalizeDate($0) })
        return uniqueDates.count
    }
    
    /// Get the completion rate for the last N days
    /// - Parameters:
    ///   - habitData: The habit data containing completion dates
    ///   - days: Number of days to calculate rate for
    /// - Returns: A value between 0.0 and 1.0 representing completion rate
    func getCompletionRate(for habitData: HabitData, lastDays days: Int) -> Double {
        guard days > 0 else { return 0.0 }
        
        let today = normalizeDate(Date())
        let completedSet = Set(habitData.completionDates.map { normalizeDate($0) })
        
        var completedCount = 0
        var checkDate = today
        
        for _ in 0..<days {
            if completedSet.contains(checkDate) {
                completedCount += 1
            }
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        
        return Double(completedCount) / Double(days)
    }
    
    /// Check if the habit was completed on a specific date
    /// - Parameters:
    ///   - habitData: The habit data containing completion dates
    ///   - date: The date to check
    /// - Returns: Whether the habit was completed on that date
    func isCompleted(for habitData: HabitData, on date: Date) -> Bool {
        let normalizedDate = normalizeDate(date)
        return habitData.completionDates.contains { normalizeDate($0) == normalizedDate }
    }
    
    /// Get streak status with description
    /// - Parameter habitData: The habit data containing completion dates
    /// - Returns: A tuple with current streak, longest streak, and a motivational message
    func getStreakStatus(for habitData: HabitData) -> (current: Int, longest: Int, message: String) {
        let current = getCurrentStreak(for: habitData)
        let longest = getLongestStreak(for: habitData)
        
        let message: String
        switch current {
        case 0:
            message = "Start your streak today!"
        case 1..<7:
            message = "Keep it up! You're building momentum."
        case 7..<30:
            message = "Great consistency! You're forming a habit."
        case 30..<90:
            message = "Amazing dedication! You're unstoppable."
        case 90..<365:
            message = "Incredible! This is now part of your lifestyle."
        default:
            message = "Legendary streak! You're an inspiration!"
        }
        
        return (current, longest, message)
    }
    
    // MARK: - Private Helpers
    
    /// Normalize a date to midnight in the current timezone
    /// - Parameter date: The date to normalize
    /// - Returns: The date with time components stripped
    private func normalizeDate(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
}

// MARK: - Convenience Extension for Habit Model

extension StreakManager {
    /// Calculate streaks directly from completion dates array
    /// - Parameter completionDates: Array of completion dates
    /// - Returns: Tuple with current and longest streak
    func getStreaks(from completionDates: [Date], createdAt: Date = Date()) -> (current: Int, longest: Int) {
        let habitData = HabitData(completionDates: completionDates, createdAt: createdAt)
        return (getCurrentStreak(for: habitData), getLongestStreak(for: habitData))
    }
}

import Foundation

// MARK: - PatternAnalyzer

struct PatternAnalyzer {
    
    static func analyzePatterns(from metrics: [DailyHealthMetrics]) -> HealthPatterns {
        guard !metrics.isEmpty else {
            return HealthPatterns.empty
        }
        
        return HealthPatterns(
            avgStepsPerDay: calculateAverageSteps(metrics),
            avgCaloriesBurned: calculateAverageCalories(metrics),
            avgExerciseMinutes: calculateAverageExercise(metrics),
            avgSleepHours: calculateAverageSleep(metrics),
            avgRestingHeartRate: calculateAverageRestingHR(metrics),
            peakActivityHours: detectPeakActivityHours(metrics),
            typicalWakeTime: detectTypicalWakeTime(metrics),
            typicalSleepTime: detectTypicalSleepTime(metrics),
            mostActiveWeekdays: detectMostActiveWeekdays(metrics),
            activityTrend: detectActivityTrend(metrics)
        )
    }
    
    // MARK: - Averages
    
    private static func calculateAverageSteps(_ metrics: [DailyHealthMetrics]) -> Int {
        let total = metrics.reduce(0) { $0 + $1.steps }
        return metrics.isEmpty ? 0 : total / metrics.count
    }
    
    private static func calculateAverageCalories(_ metrics: [DailyHealthMetrics]) -> Int {
        let total = metrics.reduce(0) { $0 + $1.activeCalories }
        return metrics.isEmpty ? 0 : total / metrics.count
    }
    
    private static func calculateAverageExercise(_ metrics: [DailyHealthMetrics]) -> Int {
        let total = metrics.reduce(0) { $0 + $1.exerciseMinutes }
        return metrics.isEmpty ? 0 : total / metrics.count
    }
    
    private static func calculateAverageSleep(_ metrics: [DailyHealthMetrics]) -> Double {
        let validSleep = metrics.compactMap { $0.sleepHours }
        guard !validSleep.isEmpty else { return 0 }
        return validSleep.reduce(0, +) / Double(validSleep.count)
    }
    
    private static func calculateAverageRestingHR(_ metrics: [DailyHealthMetrics]) -> Int {
        let validHR = metrics.compactMap { $0.restingHeartRate }
        guard !validHR.isEmpty else { return 0 }
        return validHR.reduce(0, +) / validHR.count
    }
    
    // MARK: - Peak Activity Hours
    
    private static func detectPeakActivityHours(_ metrics: [DailyHealthMetrics]) -> [Int] {
        var hourlyTotals: [Int: Int] = [:]
        
        for metric in metrics {
            for (hour, steps) in metric.hourlySteps.enumerated() {
                hourlyTotals[hour, default: 0] += steps
            }
        }
        
        let sorted = hourlyTotals.sorted { $0.value > $1.value }
        return Array(sorted.prefix(3).map { $0.key })
    }
    
    // MARK: - Sleep Patterns
    
    private static func detectTypicalWakeTime(_ metrics: [DailyHealthMetrics]) -> TimeComponents? {
        let wakeTimes = metrics.compactMap { $0.sleepEndTime }
        guard !wakeTimes.isEmpty else { return nil }
        
        let calendar = Calendar.current
        var hourSum = 0
        var minuteSum = 0
        
        for time in wakeTimes {
            hourSum += calendar.component(.hour, from: time)
            minuteSum += calendar.component(.minute, from: time)
        }
        
        let avgHour = hourSum / wakeTimes.count
        let avgMinute = minuteSum / wakeTimes.count
        
        return TimeComponents(hour: avgHour, minute: avgMinute)
    }
    
    private static func detectTypicalSleepTime(_ metrics: [DailyHealthMetrics]) -> TimeComponents? {
        let sleepTimes = metrics.compactMap { $0.sleepStartTime }
        guard !sleepTimes.isEmpty else { return nil }
        
        let calendar = Calendar.current
        var hourSum = 0
        var minuteSum = 0
        
        for time in sleepTimes {
            var hour = calendar.component(.hour, from: time)
            if hour < 12 { hour += 24 }
            hourSum += hour
            minuteSum += calendar.component(.minute, from: time)
        }
        
        var avgHour = hourSum / sleepTimes.count
        let avgMinute = minuteSum / sleepTimes.count
        
        if avgHour >= 24 { avgHour -= 24 }
        
        return TimeComponents(hour: avgHour, minute: avgMinute)
    }
    
    // MARK: - Most Active Weekdays
    
    private static func detectMostActiveWeekdays(_ metrics: [DailyHealthMetrics]) -> [Int] {
        var weekdaySteps: [Int: [Int]] = [:]
        let calendar = Calendar.current
        
        for metric in metrics {
            let weekday = calendar.component(.weekday, from: metric.date)
            weekdaySteps[weekday, default: []].append(metric.steps)
        }
        
        let averages = weekdaySteps.mapValues { steps -> Int in
            steps.isEmpty ? 0 : steps.reduce(0, +) / steps.count
        }
        
        let sorted = averages.sorted { $0.value > $1.value }
        return Array(sorted.prefix(3).map { $0.key })
    }
    
    // MARK: - Activity Trend
    
    private static func detectActivityTrend(_ metrics: [DailyHealthMetrics]) -> ActivityTrend {
        guard metrics.count >= 14 else { return .insufficientData }
        
        let sorted = metrics.sorted { $0.date < $1.date }
        let midpoint = sorted.count / 2
        
        let firstHalf = Array(sorted.prefix(midpoint))
        let secondHalf = Array(sorted.suffix(midpoint))
        
        let firstAvg = Double(firstHalf.reduce(0) { $0 + $1.steps }) / Double(firstHalf.count)
        let secondAvg = Double(secondHalf.reduce(0) { $0 + $1.steps }) / Double(secondHalf.count)
        
        let changePercentage = (secondAvg - firstAvg) / firstAvg
        
        if changePercentage > 0.1 {
            return .improving
        } else if changePercentage < -0.1 {
            return .declining
        } else {
            return .stable
        }
    }
}

// MARK: - HealthPatterns

struct HealthPatterns {
    var avgStepsPerDay: Int
    var avgCaloriesBurned: Int
    var avgExerciseMinutes: Int
    var avgSleepHours: Double
    var avgRestingHeartRate: Int
    var peakActivityHours: [Int]
    var typicalWakeTime: TimeComponents?
    var typicalSleepTime: TimeComponents?
    var mostActiveWeekdays: [Int]
    var activityTrend: ActivityTrend
    
    static let empty = HealthPatterns(
        avgStepsPerDay: 0,
        avgCaloriesBurned: 0,
        avgExerciseMinutes: 0,
        avgSleepHours: 0,
        avgRestingHeartRate: 0,
        peakActivityHours: [],
        typicalWakeTime: nil,
        typicalSleepTime: nil,
        mostActiveWeekdays: [],
        activityTrend: .insufficientData
    )
}

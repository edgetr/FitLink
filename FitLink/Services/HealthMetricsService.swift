import Foundation
import FirebaseFirestore

final class HealthMetricsService {
    
    static let shared = HealthMetricsService()
    
    private let db = Firestore.firestore()
    private let collectionName = "health_metrics"
    private let dailyMetricsSubcollection = "daily_metrics"
    private let rollingWindowDays = 30
    
    private init() {}
    
    // MARK: - Aggregate Store Operations
    
    func getMetricsStore(for userId: String) async throws -> HealthMetricsStore? {
        let document = try await db.collection(collectionName).document(userId).getDocument()
        
        guard document.exists, let data = document.data() else {
            return nil
        }
        
        var store = HealthMetricsStore.fromDictionary(data, id: userId)
        store?.dailyMetrics = try await loadDailyMetrics(for: userId)
        return store
    }
    
    func createMetricsStore(for userId: String) async throws -> HealthMetricsStore {
        let store = HealthMetricsStore(id: userId, userId: userId)
        try await saveMetricsStore(store)
        return store
    }
    
    func saveMetricsStore(_ store: HealthMetricsStore) async throws {
        var updatedStore = store
        updatedStore.lastSyncedAt = Date()
        try await db.collection(collectionName).document(store.id).setData(updatedStore.toDictionary())
    }
    
    func updateAggregates(for userId: String) async throws {
        let dailyMetrics = try await loadDailyMetrics(for: userId)
        guard !dailyMetrics.isEmpty else { return }
        
        let avgSteps = dailyMetrics.reduce(0) { $0 + $1.steps } / dailyMetrics.count
        let avgCalories = dailyMetrics.reduce(0) { $0 + $1.activeCalories } / dailyMetrics.count
        let avgExercise = dailyMetrics.reduce(0) { $0 + $1.exerciseMinutes } / dailyMetrics.count
        
        let sleepEntries = dailyMetrics.compactMap { $0.sleepHours }
        let avgSleep = sleepEntries.isEmpty ? 0 : sleepEntries.reduce(0, +) / Double(sleepEntries.count)
        
        let hrEntries = dailyMetrics.compactMap { $0.restingHeartRate }
        let avgHR = hrEntries.isEmpty ? 0 : hrEntries.reduce(0, +) / hrEntries.count
        
        let peakHours = calculatePeakActivityHours(from: dailyMetrics)
        let (wakeTime, sleepTime) = calculateTypicalSleepTimes(from: dailyMetrics)
        let activeWeekdays = calculateMostActiveWeekdays(from: dailyMetrics)
        let trend = calculateActivityTrend(from: dailyMetrics)
        
        var updates: [String: Any] = [
            "avg_steps_per_day": avgSteps,
            "avg_calories_burned": avgCalories,
            "avg_exercise_minutes": avgExercise,
            "avg_sleep_hours": avgSleep,
            "avg_resting_heart_rate": avgHR,
            "peak_activity_hours": peakHours,
            "most_active_weekdays": activeWeekdays,
            "activity_trend": trend.rawValue,
            "last_synced_at": Timestamp(date: Date())
        ]
        
        if let oldest = dailyMetrics.min(by: { $0.date < $1.date })?.date {
            updates["oldest_data_date"] = Timestamp(date: oldest)
        }
        if let newest = dailyMetrics.max(by: { $0.date < $1.date })?.date {
            updates["newest_data_date"] = Timestamp(date: newest)
        }
        if let wakeTime = wakeTime {
            updates["typical_wake_time"] = wakeTime.toDictionary()
        }
        if let sleepTime = sleepTime {
            updates["typical_sleep_time"] = sleepTime.toDictionary()
        }
        
        try await db.collection(collectionName).document(userId).setData(updates, merge: true)
    }
    
    func deleteMetricsStore(for userId: String) async throws {
        let dailyDocs = try await db.collection(collectionName)
            .document(userId)
            .collection(dailyMetricsSubcollection)
            .getDocuments()
        
        for doc in dailyDocs.documents {
            try await doc.reference.delete()
        }
        
        try await db.collection(collectionName).document(userId).delete()
    }
    
    // MARK: - Daily Metrics Operations
    
    func loadDailyMetrics(for userId: String) async throws -> [DailyHealthMetrics] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -rollingWindowDays, to: Date()) ?? Date()
        
        let snapshot = try await db.collection(collectionName)
            .document(userId)
            .collection(dailyMetricsSubcollection)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: cutoffDate))
            .order(by: "date", descending: true)
            .limit(to: rollingWindowDays)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            DailyHealthMetrics.fromDictionary(doc.data(), id: doc.documentID)
        }
    }
    
    func getDailyMetrics(for userId: String, date: Date) async throws -> DailyHealthMetrics? {
        let docId = DailyHealthMetrics.makeId(userId: userId, date: date)
        let document = try await db.collection(collectionName)
            .document(userId)
            .collection(dailyMetricsSubcollection)
            .document(docId)
            .getDocument()
        
        guard document.exists, let data = document.data() else {
            return nil
        }
        
        return DailyHealthMetrics.fromDictionary(data, id: docId)
    }
    
    func saveDailyMetrics(_ metrics: DailyHealthMetrics, userId: String) async throws {
        try await db.collection(collectionName)
            .document(userId)
            .collection(dailyMetricsSubcollection)
            .document(metrics.id)
            .setData(metrics.toDictionary())
    }
    
    func saveDailyMetricsBatch(_ metricsArray: [DailyHealthMetrics], userId: String) async throws {
        let batch = db.batch()
        
        for metrics in metricsArray {
            let docRef = db.collection(collectionName)
                .document(userId)
                .collection(dailyMetricsSubcollection)
                .document(metrics.id)
            batch.setData(metrics.toDictionary(), forDocument: docRef)
        }
        
        try await batch.commit()
    }
    
    func deleteDailyMetrics(id: String, userId: String) async throws {
        try await db.collection(collectionName)
            .document(userId)
            .collection(dailyMetricsSubcollection)
            .document(id)
            .delete()
    }
    
    // MARK: - Rolling Window Maintenance
    
    func maintainRollingWindow(for userId: String) async throws -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -rollingWindowDays, to: Date()) ?? Date()
        
        let snapshot = try await db.collection(collectionName)
            .document(userId)
            .collection(dailyMetricsSubcollection)
            .whereField("date", isLessThan: Timestamp(date: cutoffDate))
            .getDocuments()
        
        var deletedCount = 0
        for doc in snapshot.documents {
            try await doc.reference.delete()
            deletedCount += 1
        }
        
        return deletedCount
    }
    
    // MARK: - Pattern Calculations
    
    private func calculatePeakActivityHours(from metrics: [DailyHealthMetrics]) -> [Int] {
        var hourlyTotals = Array(repeating: 0, count: 24)
        
        for daily in metrics {
            for (hour, steps) in daily.hourlySteps.enumerated() where hour < 24 {
                hourlyTotals[hour] += steps
            }
        }
        
        let indexed = hourlyTotals.enumerated().map { ($0.offset, $0.element) }
        let sorted = indexed.sorted { $0.1 > $1.1 }
        return Array(sorted.prefix(5).map { $0.0 })
    }
    
    private func calculateTypicalSleepTimes(from metrics: [DailyHealthMetrics]) -> (wake: TimeComponents?, sleep: TimeComponents?) {
        var wakeTimes: [(hour: Int, minute: Int)] = []
        var sleepTimes: [(hour: Int, minute: Int)] = []
        
        for daily in metrics {
            if let end = daily.sleepEndTime {
                let components = Calendar.current.dateComponents([.hour, .minute], from: end)
                if let h = components.hour, let m = components.minute {
                    wakeTimes.append((h, m))
                }
            }
            if let start = daily.sleepStartTime {
                let components = Calendar.current.dateComponents([.hour, .minute], from: start)
                if let h = components.hour, let m = components.minute {
                    sleepTimes.append((h, m))
                }
            }
        }
        
        let avgWake: TimeComponents? = wakeTimes.isEmpty ? nil : {
            let avgH = wakeTimes.reduce(0) { $0 + $1.hour } / wakeTimes.count
            let avgM = wakeTimes.reduce(0) { $0 + $1.minute } / wakeTimes.count
            return TimeComponents(hour: avgH, minute: avgM)
        }()
        
        let avgSleep: TimeComponents? = sleepTimes.isEmpty ? nil : {
            let avgH = sleepTimes.reduce(0) { $0 + $1.hour } / sleepTimes.count
            let avgM = sleepTimes.reduce(0) { $0 + $1.minute } / sleepTimes.count
            return TimeComponents(hour: avgH, minute: avgM)
        }()
        
        return (avgWake, avgSleep)
    }
    
    private func calculateMostActiveWeekdays(from metrics: [DailyHealthMetrics]) -> [Int] {
        var weekdayTotals = Array(repeating: 0, count: 7)
        var weekdayCounts = Array(repeating: 0, count: 7)
        
        for daily in metrics {
            let weekday = Calendar.current.component(.weekday, from: daily.date)
            weekdayTotals[weekday - 1] += daily.steps
            weekdayCounts[weekday - 1] += 1
        }
        
        let averages = weekdayTotals.enumerated().map { i, total -> (weekday: Int, avg: Int) in
            let count = weekdayCounts[i]
            return (i + 1, count > 0 ? total / count : 0)
        }
        
        return averages.sorted { $0.avg > $1.avg }.prefix(3).map { $0.weekday }
    }
    
    private func calculateActivityTrend(from metrics: [DailyHealthMetrics]) -> ActivityTrend {
        guard metrics.count >= 14 else { return .insufficientData }
        
        let sorted = metrics.sorted { $0.date < $1.date }
        let midpoint = sorted.count / 2
        
        let firstHalf = Array(sorted.prefix(midpoint))
        let secondHalf = Array(sorted.suffix(sorted.count - midpoint))
        
        let firstAvg = firstHalf.reduce(0) { $0 + $1.steps } / max(firstHalf.count, 1)
        let secondAvg = secondHalf.reduce(0) { $0 + $1.steps } / max(secondHalf.count, 1)
        
        let percentChange = firstAvg > 0 ? Double(secondAvg - firstAvg) / Double(firstAvg) : 0
        
        if percentChange > 0.1 { return .improving }
        if percentChange < -0.1 { return .declining }
        return .stable
    }
    
    // MARK: - Convenience Methods
    
    func getOrCreateMetricsStore(for userId: String) async throws -> HealthMetricsStore {
        if let existing = try await getMetricsStore(for: userId) {
            return existing
        }
        return try await createMetricsStore(for: userId)
    }
}

// MARK: - Errors

enum HealthMetricsServiceError: LocalizedError {
    case storeNotFound
    case invalidData
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .storeNotFound:
            return "Health metrics store not found."
        case .invalidData:
            return "Invalid health metrics data."
        case .saveFailed:
            return "Failed to save health metrics."
        }
    }
}

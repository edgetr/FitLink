import HealthKit
import Foundation

// MARK: - HealthKitRepository

actor HealthKitRepository {
    
    static let shared = HealthKitRepository()
    
    private let healthStore = HKHealthStore()
    private let anchorStore = HealthKitAnchorStore.shared
    
    private init() {}
    
    // MARK: - Optimized Hourly Data Collection
    
    func fetchHourlyData(
        _ identifier: HKQuantityTypeIdentifier,
        date: Date,
        unit: HKUnit,
        options: HKStatisticsOptions = .cumulativeSum
    ) async throws -> [Double] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return Array(repeating: 0, count: 24)
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return Array(repeating: 0, count: 24)
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        let intervalComponents = DateComponents(hour: 1)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: startOfDay,
                intervalComponents: intervalComponents
            )
            
            query.initialResultsHandler = { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let statsCollection = results else {
                    continuation.resume(returning: Array(repeating: 0, count: 24))
                    return
                }
                
                var hourlyData = Array(repeating: 0.0, count: 24)
                
                statsCollection.enumerateStatistics(from: startOfDay, to: endOfDay) { statistics, _ in
                    let hour = calendar.component(.hour, from: statistics.startDate)
                    guard hour < 24 else { return }
                    
                    let value: Double
                    switch options {
                    case .cumulativeSum:
                        value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    case .discreteAverage:
                        value = statistics.averageQuantity()?.doubleValue(for: unit) ?? 0
                    case .discreteMax:
                        value = statistics.maximumQuantity()?.doubleValue(for: unit) ?? 0
                    case .discreteMin:
                        value = statistics.minimumQuantity()?.doubleValue(for: unit) ?? 0
                    default:
                        value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    }
                    
                    hourlyData[hour] = value
                }
                
                continuation.resume(returning: hourlyData)
            }
            
            healthStore.execute(query)
        }
    }
    
    func fetchHourlyHeartRate(date: Date) async throws -> [Int?] {
        let unit = HKUnit.count().unitDivided(by: .minute())
        let hourlyData = try await fetchHourlyData(
            .heartRate,
            date: date,
            unit: unit,
            options: .discreteAverage
        )
        
        return hourlyData.map { value in
            value > 0 ? Int(value) : nil
        }
    }
    
    // MARK: - Multi-Day Aggregates
    
    func fetchDailyAggregates(
        _ identifier: HKQuantityTypeIdentifier,
        startDate: Date,
        endDate: Date,
        unit: HKUnit,
        options: HKStatisticsOptions = .cumulativeSum
    ) async throws -> [Date: Double] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return [:]
        }
        
        let calendar = Calendar.current
        let anchorDate = calendar.startOfDay(for: startDate)
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let intervalComponents = DateComponents(day: 1)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: anchorDate,
                intervalComponents: intervalComponents
            )
            
            query.initialResultsHandler = { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let statsCollection = results else {
                    continuation.resume(returning: [:])
                    return
                }
                
                var dailyData: [Date: Double] = [:]
                
                statsCollection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let dayStart = calendar.startOfDay(for: statistics.startDate)
                    
                    let value: Double
                    switch options {
                    case .cumulativeSum:
                        value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    case .discreteAverage:
                        value = statistics.averageQuantity()?.doubleValue(for: unit) ?? 0
                    case .discreteMax:
                        value = statistics.maximumQuantity()?.doubleValue(for: unit) ?? 0
                    case .discreteMin:
                        value = statistics.minimumQuantity()?.doubleValue(for: unit) ?? 0
                    default:
                        value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    }
                    
                    dailyData[dayStart] = value
                }
                
                continuation.resume(returning: dailyData)
            }
            
            healthStore.execute(query)
        }
    }
    
    func fetchHourlyDataForRange(
        _ identifier: HKQuantityTypeIdentifier,
        startDate: Date,
        endDate: Date,
        unit: HKUnit,
        options: HKStatisticsOptions = .cumulativeSum
    ) async throws -> [Date: [Double]] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return [:]
        }
        
        let calendar = Calendar.current
        let anchorDate = calendar.startOfDay(for: startDate)
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let intervalComponents = DateComponents(hour: 1)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: anchorDate,
                intervalComponents: intervalComponents
            )
            
            query.initialResultsHandler = { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let statsCollection = results else {
                    continuation.resume(returning: [:])
                    return
                }
                
                var dailyHourlyData: [Date: [Double]] = [:]
                
                statsCollection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let dayStart = calendar.startOfDay(for: statistics.startDate)
                    let hour = calendar.component(.hour, from: statistics.startDate)
                    
                    guard hour < 24 else { return }
                    
                    if dailyHourlyData[dayStart] == nil {
                        dailyHourlyData[dayStart] = Array(repeating: 0, count: 24)
                    }
                    
                    let value: Double
                    switch options {
                    case .cumulativeSum:
                        value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    case .discreteAverage:
                        value = statistics.averageQuantity()?.doubleValue(for: unit) ?? 0
                    default:
                        value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    }
                    
                    dailyHourlyData[dayStart]?[hour] = value
                }
                
                continuation.resume(returning: dailyHourlyData)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Incremental Sync
    
    func fetchIncrementalSamples(
        _ identifier: HKQuantityTypeIdentifier,
        userId: String
    ) async throws -> (samples: [HKQuantitySample], deletedIds: [UUID]) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return ([], [])
        }
        
        let anchorKey = "\(userId)_\(identifier.rawValue)"
        let storedAnchor = anchorStore.getAnchor(forKey: anchorKey)
        let localAnchorStore = anchorStore
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: quantityType,
                predicate: nil,
                anchor: storedAnchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, deletedObjects, newAnchor, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let newAnchor = newAnchor {
                    localAnchorStore.saveAnchor(newAnchor, forKey: anchorKey)
                }
                
                let quantitySamples = (samples as? [HKQuantitySample]) ?? []
                let deletedIds = deletedObjects?.compactMap { $0.uuid } ?? []
                
                continuation.resume(returning: (quantitySamples, deletedIds))
            }
            
            healthStore.execute(query)
        }
    }
    
    func fetchIncrementalCategorySamples(
        _ identifier: HKCategoryTypeIdentifier,
        userId: String
    ) async throws -> (samples: [HKCategorySample], deletedIds: [UUID]) {
        guard let categoryType = HKCategoryType.categoryType(forIdentifier: identifier) else {
            return ([], [])
        }
        
        let anchorKey = "\(userId)_\(identifier.rawValue)"
        let storedAnchor = anchorStore.getAnchor(forKey: anchorKey)
        let localAnchorStore = anchorStore
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: categoryType,
                predicate: nil,
                anchor: storedAnchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, deletedObjects, newAnchor, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let newAnchor = newAnchor {
                    localAnchorStore.saveAnchor(newAnchor, forKey: anchorKey)
                }
                
                let categorySamples = (samples as? [HKCategorySample]) ?? []
                let deletedIds = deletedObjects?.compactMap { $0.uuid } ?? []
                
                continuation.resume(returning: (categorySamples, deletedIds))
            }
            
            healthStore.execute(query)
        }
    }
    
    func clearAnchors(userId: String) {
        anchorStore.clearAnchors(forUserPrefix: userId)
    }
}

// MARK: - HealthKitAnchorStore

final class HealthKitAnchorStore: @unchecked Sendable {
    
    static let shared = HealthKitAnchorStore()
    
    private let userDefaults = UserDefaults.standard
    private let anchorKeyPrefix = "hk_anchor_"
    
    private init() {}
    
    func getAnchor(forKey key: String) -> HKQueryAnchor? {
        let storageKey = anchorKeyPrefix + key
        guard let data = userDefaults.data(forKey: storageKey) else {
            return nil
        }
        
        do {
            return try NSKeyedUnarchiver.unarchivedObject(
                ofClass: HKQueryAnchor.self,
                from: data
            )
        } catch {
            log("Failed to unarchive anchor for key \(key): \(error)")
            return nil
        }
    }
    
    func saveAnchor(_ anchor: HKQueryAnchor, forKey key: String) {
        let storageKey = anchorKeyPrefix + key
        
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: anchor,
                requiringSecureCoding: true
            )
            userDefaults.set(data, forKey: storageKey)
        } catch {
            log("Failed to archive anchor for key \(key): \(error)")
        }
    }
    
    func removeAnchor(forKey key: String) {
        let storageKey = anchorKeyPrefix + key
        userDefaults.removeObject(forKey: storageKey)
    }
    
    func clearAnchors(forUserPrefix userId: String) {
        let prefix = anchorKeyPrefix + userId
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        for key in allKeys where key.hasPrefix(prefix) {
            userDefaults.removeObject(forKey: key)
        }
    }
    
    private func log(_ message: String) {
        #if DEBUG
        print("[HealthKitAnchorStore] \(message)")
        #endif
    }
}

// MARK: - HealthKitRepositoryError

enum HealthKitRepositoryError: LocalizedError {
    case queryFailed(String)
    case invalidType
    case noData
    
    var errorDescription: String? {
        switch self {
        case .queryFailed(let reason):
            return "HealthKit query failed: \(reason)"
        case .invalidType:
            return "Invalid HealthKit type specified."
        case .noData:
            return "No health data available."
        }
    }
}

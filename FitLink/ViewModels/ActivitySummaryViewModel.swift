import SwiftUI
import UIKit
import Combine
import HealthKit

enum HealthKitAuthorizationStatus {
    case notDetermined
    case authorized
    case denied
    case unavailable
}

enum SleepStage: String, CaseIterable {
    case awake = "Awake"
    case rem = "REM"
    case core = "Core"
    case deep = "Deep"
    
    var color: Color {
        switch self {
        case .awake: return Color.orange
        case .rem: return Color.cyan
        case .core: return Color.indigo
        case .deep: return Color(red: 0.3, green: 0.2, blue: 0.5)
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .awake: return 0
        case .rem: return 1
        case .core: return 2
        case .deep: return 3
        }
    }
}

struct HourlyDataPoint: Identifiable {
    let id = UUID()
    let hour: Int
    let value: Double
    let isCurrentHour: Bool
    let referenceDate: Date
    
    init(hour: Int, value: Double, isCurrentHour: Bool = false, referenceDate: Date = Date()) {
        self.hour = hour
        self.value = value
        self.isCurrentHour = isCurrentHour
        self.referenceDate = referenceDate
    }
    
    var hourLabel: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if isCurrentHour && calendar.isDateInToday(referenceDate) {
            formatter.dateFormat = "h:mma"
            return formatter.string(from: Date())
        } else {
            formatter.dateFormat = "ha"
            let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: referenceDate) ?? referenceDate
            return formatter.string(from: date)
        }
    }
}

struct SleepDataPoint: Identifiable {
    let id = UUID()
    let hour: Int
    let minute: Int
    let stage: SleepStage
    let referenceDate: Date
    
    init(hour: Int, minute: Int, stage: SleepStage, referenceDate: Date = Date()) {
        self.hour = hour
        self.minute = minute
        self.stage = stage
        self.referenceDate = referenceDate
    }
    
    var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: referenceDate) ?? referenceDate
        return formatter.string(from: date)
    }
    
    var timeValue: Double {
        Double(hour) + Double(minute) / 60.0
    }
}

// MARK: - Daily Health Snapshot

struct DailyHealthSnapshot {
    let date: Date
    let steps: Int
    let calories: Int
    let exerciseMinutes: Int
    let heartRate: Int
    let sleepHours: Double
    let hourlySteps: [HourlyDataPoint]
    let hourlyCalories: [HourlyDataPoint]
    let hourlyHeartRate: [HourlyDataPoint]
    let hourlyExerciseMinutes: [HourlyDataPoint]
    let sleepStages: [SleepDataPoint]
    
    static let empty = DailyHealthSnapshot(
        date: Date(),
        steps: 0,
        calories: 0,
        exerciseMinutes: 0,
        heartRate: 0,
        sleepHours: 0,
        hourlySteps: [],
        hourlyCalories: [],
        hourlyHeartRate: [],
        hourlyExerciseMinutes: [],
        sleepStages: []
    )
}

class ActivitySummaryViewModel: ObservableObject {
    @Published var steps: Int = 0
    @Published var calories: Int = 0
    @Published var exerciseMinutes: Int = 0
    @Published var heartRate: Int = 0
    @Published var sleepHours: Double = 0.0
    @Published var isLoading = false
    @Published var authorizationStatus: HealthKitAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    @Published var currentDisplayDate: Date = Date()
    
    @Published var hourlyCalories: [HourlyDataPoint] = []
    @Published var hourlySteps: [HourlyDataPoint] = []
    @Published var hourlyHeartRate: [HourlyDataPoint] = []
    @Published var sleepStages: [SleepDataPoint] = []
    @Published var hourlyExerciseMinutes: [HourlyDataPoint] = []
    
    private var healthStore: HKHealthStore?
    private var cancellables = Set<AnyCancellable>()
    private var snapshotCache: [Date: DailyHealthSnapshot] = [:]
    
    var formattedSteps: String {
        formatNumber(steps)
    }
    
    var formattedCalories: String {
        formatNumber(calories)
    }
    
    var formattedExerciseMinutes: String {
        "\(exerciseMinutes) min"
    }
    
    var formattedHeartRate: String {
        "\(heartRate) bpm"
    }
    
    var formattedSleepHours: String {
        String(format: "%.1fh", sleepHours)
    }
    
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    var needsAuthorization: Bool {
        authorizationStatus == .notDetermined || authorizationStatus == .denied
    }
    
    var showAuthorizationWarning: Bool {
        authorizationStatus == .denied || authorizationStatus == .unavailable
    }
    
    init() {
        setupHealthKit()
    }
    
    private func setupHealthKit() {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .unavailable
            loadMockData()
            return
        }
        
        healthStore = HKHealthStore()
        checkAuthorizationStatus()
    }
    
    func requestAuthorization() {
        guard let healthStore = healthStore else {
            authorizationStatus = .unavailable
            return
        }
        
        var typesToRead: Set<HKObjectType> = []
        
        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .activeEnergyBurned,
            .appleExerciseTime,
            .heartRate
        ]
        
        for identifier in quantityIdentifiers {
            if let quantityType = HKObjectType.quantityType(forIdentifier: identifier) {
                typesToRead.insert(quantityType)
            }
        }
        
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            typesToRead.insert(sleepType)
        }
        
        guard !typesToRead.isEmpty else {
            authorizationStatus = .unavailable
            errorMessage = "HealthKit types not available on this device"
            return
        }
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.authorizationStatus = .authorized
                    self?.fetchTodayActivityData()
                } else {
                    self?.authorizationStatus = .denied
                    self?.errorMessage = error?.localizedDescription ?? "Authorization denied"
                }
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        guard let healthStore = healthStore,
              let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            authorizationStatus = .unavailable
            return
        }
        
        let status = healthStore.authorizationStatus(for: stepType)
        
        switch status {
        case .notDetermined:
            // Do NOT request authorization during init - wait for explicit user action
            authorizationStatus = .notDetermined
        case .sharingAuthorized:
            authorizationStatus = .authorized
            fetchTodayActivityData()
        case .sharingDenied:
            authorizationStatus = .denied
        @unknown default:
            authorizationStatus = .notDetermined
        }
    }
    
    func fetchTodayActivityData() {
        guard let healthStore = healthStore else {
            return
        }
        
        isLoading = true
        
        let group = DispatchGroup()
        
        group.enter()
        fetchSteps(healthStore: healthStore) { [weak self] value in
            self?.steps = value
            group.leave()
        }
        
        group.enter()
        fetchActiveEnergy(healthStore: healthStore) { [weak self] value in
            self?.calories = value
            group.leave()
        }
        
        group.enter()
        fetchExerciseMinutes(healthStore: healthStore) { [weak self] value in
            self?.exerciseMinutes = value
            group.leave()
        }
        
        group.enter()
        fetchHeartRate(healthStore: healthStore) { [weak self] value in
            self?.heartRate = value
            group.leave()
        }
        
        fetchHourlySteps(healthStore: healthStore)
        fetchHourlyCalories(healthStore: healthStore)
        fetchHourlyExerciseMinutes(healthStore: healthStore)
        fetchHourlyHeartRate(healthStore: healthStore)
        fetchSleepAnalysis(healthStore: healthStore)
        
        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
        }
    }
    
    @MainActor
    func fetchActivityData(for date: Date) async {
        let calendar = Calendar.current
        let cacheKey = calendar.startOfDay(for: date)
        
        if let cached = snapshotCache[cacheKey] {
            applySnapshot(cached)
            return
        }
        
        guard let healthStore = healthStore else {
            if !HKHealthStore.isHealthDataAvailable() {
                loadMockData(for: date)
            }
            return
        }
        
        isLoading = true
        currentDisplayDate = date
        
        async let stepsValue = fetchStepsAsync(healthStore: healthStore, for: date)
        async let caloriesValue = fetchActiveEnergyAsync(healthStore: healthStore, for: date)
        async let exerciseValue = fetchExerciseMinutesAsync(healthStore: healthStore, for: date)
        async let heartRateValue = fetchHeartRateAsync(healthStore: healthStore, for: date)
        async let hourlyStepsData = fetchHourlyDataAsync(for: .stepCount, unit: .count(), healthStore: healthStore, date: date)
        async let hourlyCaloriesData = fetchHourlyDataAsync(for: .activeEnergyBurned, unit: .kilocalorie(), healthStore: healthStore, date: date)
        async let hourlyExerciseData = fetchHourlyDataAsync(for: .appleExerciseTime, unit: .minute(), healthStore: healthStore, date: date)
        async let hourlyHeartRateData = fetchHourlyHeartRateAsync(healthStore: healthStore, for: date)
        async let sleepData = fetchSleepAnalysisAsync(healthStore: healthStore, for: date)
        
        let (steps, calories, exercise, heart, hSteps, hCalories, hExercise, hHeart, sleep) = await (
            stepsValue,
            caloriesValue,
            exerciseValue,
            heartRateValue,
            hourlyStepsData,
            hourlyCaloriesData,
            hourlyExerciseData,
            hourlyHeartRateData,
            sleepData
        )
        
        let snapshot = DailyHealthSnapshot(
            date: cacheKey,
            steps: steps,
            calories: calories,
            exerciseMinutes: exercise,
            heartRate: heart,
            sleepHours: sleep.totalHours,
            hourlySteps: hSteps,
            hourlyCalories: hCalories,
            hourlyHeartRate: hHeart,
            hourlyExerciseMinutes: hExercise,
            sleepStages: sleep.stages
        )
        
        snapshotCache[cacheKey] = snapshot
        applySnapshot(snapshot)
        isLoading = false
    }
    
    @MainActor
    private func applySnapshot(_ snapshot: DailyHealthSnapshot) {
        steps = snapshot.steps
        calories = snapshot.calories
        exerciseMinutes = snapshot.exerciseMinutes
        heartRate = snapshot.heartRate
        sleepHours = snapshot.sleepHours
        hourlySteps = snapshot.hourlySteps
        hourlyCalories = snapshot.hourlyCalories
        hourlyHeartRate = snapshot.hourlyHeartRate
        hourlyExerciseMinutes = snapshot.hourlyExerciseMinutes
        sleepStages = snapshot.sleepStages
        currentDisplayDate = snapshot.date
    }
    
    private func fetchSteps(healthStore: HKHealthStore, completion: @escaping (Int) -> Void) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(0)
            return
        }
        
        let predicate = createTodayPredicate()
        
        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            DispatchQueue.main.async {
                guard let result = result, let sum = result.sumQuantity() else {
                    completion(0)
                    return
                }
                
                let value = Int(sum.doubleValue(for: HKUnit.count()))
                completion(value)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func fetchActiveEnergy(healthStore: HKHealthStore, completion: @escaping (Int) -> Void) {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion(0)
            return
        }
        
        let predicate = createTodayPredicate()
        
        let query = HKStatisticsQuery(
            quantityType: energyType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            DispatchQueue.main.async {
                guard let result = result, let sum = result.sumQuantity() else {
                    completion(0)
                    return
                }
                
                let value = Int(sum.doubleValue(for: HKUnit.kilocalorie()))
                completion(value)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func fetchExerciseMinutes(healthStore: HKHealthStore, completion: @escaping (Int) -> Void) {
        guard let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else {
            completion(0)
            return
        }
        
        let predicate = createTodayPredicate()
        
        let query = HKStatisticsQuery(
            quantityType: exerciseType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            DispatchQueue.main.async {
                guard let result = result, let sum = result.sumQuantity() else {
                    completion(0)
                    return
                }
                
                let value = Int(sum.doubleValue(for: HKUnit.minute()))
                completion(value)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func createPredicate(for date: Date) -> NSPredicate {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let isToday = calendar.isDateInToday(date)
        let endDate = isToday ? Date() : calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        return HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endDate,
            options: .strictStartDate
        )
    }
    
    private func createTodayPredicate() -> NSPredicate {
        createPredicate(for: Date())
    }
    
    // MARK: - Hourly Data Fetching
    
    private func fetchHourlyData(
        for quantityType: HKQuantityType,
        unit: HKUnit,
        healthStore: HKHealthStore,
        completion: @escaping ([HourlyDataPoint]) -> Void
    ) {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let currentHour = calendar.component(.hour, from: now)
        
        var interval = DateComponents()
        interval.hour = 1
        
        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: startOfDay,
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { _, results, error in
            var hourlyData: [HourlyDataPoint] = []
            
            guard let results = results else {
                DispatchQueue.main.async {
                    completion((0...23).map { HourlyDataPoint(hour: $0, value: 0, isCurrentHour: $0 == currentHour) })
                }
                return
            }
            
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
            
            results.enumerateStatistics(from: startOfDay, to: endOfDay) { statistics, _ in
                let hour = calendar.component(.hour, from: statistics.startDate)
                let value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                hourlyData.append(HourlyDataPoint(hour: hour, value: value, isCurrentHour: hour == currentHour))
            }
            
            if hourlyData.count < 24 {
                let existingHours = Set(hourlyData.map { $0.hour })
                for hour in 0...23 where !existingHours.contains(hour) {
                    hourlyData.append(HourlyDataPoint(hour: hour, value: 0, isCurrentHour: hour == currentHour))
                }
            }
            
            hourlyData.sort { $0.hour < $1.hour }
            
            DispatchQueue.main.async {
                completion(hourlyData)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func fetchHourlySteps(healthStore: HKHealthStore) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        fetchHourlyData(for: stepType, unit: .count(), healthStore: healthStore) { [weak self] data in
            self?.hourlySteps = data
        }
    }
    
    private func fetchHourlyCalories(healthStore: HKHealthStore) {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        fetchHourlyData(for: energyType, unit: .kilocalorie(), healthStore: healthStore) { [weak self] data in
            self?.hourlyCalories = data
        }
    }
    
    private func fetchHourlyExerciseMinutes(healthStore: HKHealthStore) {
        guard let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else { return }
        fetchHourlyData(for: exerciseType, unit: .minute(), healthStore: healthStore) { [weak self] data in
            self?.hourlyExerciseMinutes = data
        }
    }
    
    // MARK: - Heart Rate Fetching
    
    private func fetchHeartRate(healthStore: HKHealthStore, completion: @escaping (Int) -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion(0)
            return
        }
        
        let predicate = createTodayPredicate()
        
        let query = HKStatisticsQuery(
            quantityType: heartRateType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage
        ) { _, result, _ in
            DispatchQueue.main.async {
                guard let result = result, let avg = result.averageQuantity() else {
                    completion(0)
                    return
                }
                let value = Int(avg.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
                completion(value)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func fetchHourlyHeartRate(healthStore: HKHealthStore) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let currentHour = calendar.component(.hour, from: now)
        
        var interval = DateComponents()
        interval.hour = 1
        
        let query = HKStatisticsCollectionQuery(
            quantityType: heartRateType,
            quantitySamplePredicate: nil,
            options: .discreteAverage,
            anchorDate: startOfDay,
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { _, results, _ in
            var hourlyData: [HourlyDataPoint] = []
            
            guard let results = results else {
                DispatchQueue.main.async { [weak self] in
                    self?.hourlyHeartRate = (0...23).map { HourlyDataPoint(hour: $0, value: 0, isCurrentHour: $0 == currentHour) }
                }
                return
            }
            
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
            
            results.enumerateStatistics(from: startOfDay, to: endOfDay) { statistics, _ in
                let hour = calendar.component(.hour, from: statistics.startDate)
                let value = statistics.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0
                hourlyData.append(HourlyDataPoint(hour: hour, value: value, isCurrentHour: hour == currentHour))
            }
            
            let existingHours = Set(hourlyData.map { $0.hour })
            for hour in 0...23 where !existingHours.contains(hour) {
                hourlyData.append(HourlyDataPoint(hour: hour, value: 0, isCurrentHour: hour == currentHour))
            }
            
            hourlyData.sort { $0.hour < $1.hour }
            
            DispatchQueue.main.async { [weak self] in
                self?.hourlyHeartRate = hourlyData
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Sleep Analysis Fetching
    
    private func fetchSleepAnalysis(healthStore: HKHealthStore) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let startOfYesterday = calendar.startOfDay(for: yesterday)
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfYesterday,
            end: now,
            options: .strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, _ in
            guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                DispatchQueue.main.async {
                    self?.sleepStages = []
                    self?.sleepHours = 0
                }
                return
            }
            
            var sleepDataPoints: [SleepDataPoint] = []
            var totalSleepSeconds: TimeInterval = 0
            
            for sample in samples {
                let stage: SleepStage
                switch sample.value {
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    stage = .awake
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    stage = .rem
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    stage = .core
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    stage = .deep
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    stage = .core
                default:
                    continue
                }
                
                if stage != .awake {
                    totalSleepSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                }
                
                let hour = calendar.component(.hour, from: sample.startDate)
                let minute = calendar.component(.minute, from: sample.startDate)
                sleepDataPoints.append(SleepDataPoint(hour: hour, minute: minute, stage: stage))
            }
            
            DispatchQueue.main.async {
                self?.sleepStages = sleepDataPoints
                self?.sleepHours = totalSleepSeconds / 3600.0
            }
        }
        
        healthStore.execute(query)
    }
    
    private func fetchStepsAsync(healthStore: HKHealthStore, for date: Date) async -> Int {
        await withCheckedContinuation { continuation in
            guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
                continuation.resume(returning: 0)
                return
            }
            
            let predicate = createPredicate(for: date)
            
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: Int(sum.doubleValue(for: HKUnit.count())))
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchActiveEnergyAsync(healthStore: HKHealthStore, for date: Date) async -> Int {
        await withCheckedContinuation { continuation in
            guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
                continuation.resume(returning: 0)
                return
            }
            
            let predicate = createPredicate(for: date)
            
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: Int(sum.doubleValue(for: HKUnit.kilocalorie())))
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchExerciseMinutesAsync(healthStore: HKHealthStore, for date: Date) async -> Int {
        await withCheckedContinuation { continuation in
            guard let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else {
                continuation.resume(returning: 0)
                return
            }
            
            let predicate = createPredicate(for: date)
            
            let query = HKStatisticsQuery(
                quantityType: exerciseType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: Int(sum.doubleValue(for: HKUnit.minute())))
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchHeartRateAsync(healthStore: HKHealthStore, for date: Date) async -> Int {
        await withCheckedContinuation { continuation in
            guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
                continuation.resume(returning: 0)
                return
            }
            
            let predicate = createPredicate(for: date)
            
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, _ in
                guard let result = result, let avg = result.averageQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: Int(avg.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))))
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchHourlyDataAsync(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        healthStore: HKHealthStore,
        date: Date
    ) async -> [HourlyDataPoint] {
        await withCheckedContinuation { continuation in
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
                continuation.resume(returning: [])
                return
            }
            
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let isToday = calendar.isDateInToday(date)
            let currentHour = isToday ? calendar.component(.hour, from: Date()) : -1
            
            var interval = DateComponents()
            interval.hour = 1
            
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: nil,
                options: identifier == .heartRate ? .discreteAverage : .cumulativeSum,
                anchorDate: startOfDay,
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { _, results, _ in
                var hourlyData: [HourlyDataPoint] = []
                
                guard let results = results else {
                    let emptyData = (0...23).map { HourlyDataPoint(hour: $0, value: 0, isCurrentHour: $0 == currentHour, referenceDate: date) }
                    continuation.resume(returning: emptyData)
                    return
                }
                
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
                
                results.enumerateStatistics(from: startOfDay, to: endOfDay) { statistics, _ in
                    let hour = calendar.component(.hour, from: statistics.startDate)
                    let value: Double
                    if identifier == .heartRate {
                        value = statistics.averageQuantity()?.doubleValue(for: unit) ?? 0
                    } else {
                        value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    }
                    hourlyData.append(HourlyDataPoint(hour: hour, value: value, isCurrentHour: hour == currentHour, referenceDate: date))
                }
                
                let existingHours = Set(hourlyData.map { $0.hour })
                for hour in 0...23 where !existingHours.contains(hour) {
                    hourlyData.append(HourlyDataPoint(hour: hour, value: 0, isCurrentHour: hour == currentHour, referenceDate: date))
                }
                
                hourlyData.sort { $0.hour < $1.hour }
                continuation.resume(returning: hourlyData)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchHourlyHeartRateAsync(healthStore: HKHealthStore, for date: Date) async -> [HourlyDataPoint] {
        await fetchHourlyDataAsync(for: .heartRate, unit: HKUnit.count().unitDivided(by: .minute()), healthStore: healthStore, date: date)
    }
    
    private func fetchSleepAnalysisAsync(healthStore: HKHealthStore, for date: Date) async -> (stages: [SleepDataPoint], totalHours: Double) {
        await withCheckedContinuation { continuation in
            guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
                continuation.resume(returning: ([], 0))
                return
            }
            
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let previousDay = calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let predicate = HKQuery.predicateForSamples(
                withStart: previousDay,
                end: endOfDay,
                options: .strictStartDate
            )
            
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: ([], 0))
                    return
                }
                
                var sleepDataPoints: [SleepDataPoint] = []
                var totalSleepSeconds: TimeInterval = 0
                
                for sample in samples {
                    let stage: SleepStage
                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        stage = .awake
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        stage = .rem
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                        stage = .core
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        stage = .deep
                    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                        stage = .core
                    default:
                        continue
                    }
                    
                    if stage != .awake {
                        totalSleepSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                    }
                    
                    let hour = calendar.component(.hour, from: sample.startDate)
                    let minute = calendar.component(.minute, from: sample.startDate)
                    sleepDataPoints.append(SleepDataPoint(hour: hour, minute: minute, stage: stage, referenceDate: date))
                }
                
                continuation.resume(returning: (sleepDataPoints, totalSleepSeconds / 3600.0))
            }
            
            healthStore.execute(query)
        }
    }
    
    private func loadMockData() {
        loadMockData(for: Date())
    }
    
    private func loadMockData(for date: Date) {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let currentHour = isToday ? calendar.component(.hour, from: Date()) : 23
        
        steps = Int.random(in: 3000...8000)
        calories = Int.random(in: 200...500)
        exerciseMinutes = Int.random(in: 15...60)
        heartRate = Int.random(in: 65...85)
        sleepHours = Double.random(in: 5.5...8.5)
        
        hourlyCalories = generateMockHourlyData(baseValue: 20, variance: 15, currentHour: currentHour, referenceDate: date)
        hourlySteps = generateMockHourlyData(baseValue: 300, variance: 200, currentHour: currentHour, referenceDate: date)
        hourlyHeartRate = generateMockHourlyData(baseValue: 70, variance: 15, currentHour: currentHour, referenceDate: date)
        hourlyExerciseMinutes = generateMockHourlyData(baseValue: 2, variance: 3, currentHour: currentHour, referenceDate: date)
        sleepStages = generateMockSleepStages(for: date)
        currentDisplayDate = date
    }
    
    private func generateMockHourlyData(baseValue: Double, variance: Double, currentHour: Int, referenceDate: Date = Date()) -> [HourlyDataPoint] {
        return (0...23).map { hour in
            let randomValue = hour <= currentHour ? max(0, baseValue + Double.random(in: -variance...variance)) : 0
            return HourlyDataPoint(hour: hour, value: randomValue, isCurrentHour: hour == currentHour, referenceDate: referenceDate)
        }
    }
    
    private func generateMockSleepStages(for date: Date = Date()) -> [SleepDataPoint] {
        var stages: [SleepDataPoint] = []
        
        let sleepSchedule: [(startHour: Int, startMin: Int, stage: SleepStage)] = [
            (23, 0, .awake),
            (23, 15, .core),
            (23, 45, .deep),
            (0, 30, .core),
            (1, 0, .rem),
            (1, 30, .core),
            (2, 0, .deep),
            (2, 45, .core),
            (3, 15, .rem),
            (3, 45, .deep),
            (4, 30, .core),
            (5, 0, .rem),
            (5, 30, .core),
            (6, 0, .awake),
            (6, 10, .core),
            (6, 30, .awake)
        ]
        
        for entry in sleepSchedule {
            stages.append(SleepDataPoint(hour: entry.startHour, minute: entry.startMin, stage: entry.stage, referenceDate: date))
        }
        
        return stages
    }
    
    func openHealthSettings() {
        if let url = URL(string: "x-apple-health://") {
            UIApplication.shared.open(url)
        }
    }
    
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    func refreshData() {
        if authorizationStatus == .authorized {
            fetchTodayActivityData()
        } else {
            requestAuthorization()
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

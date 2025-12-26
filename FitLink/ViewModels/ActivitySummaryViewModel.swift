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
    
    init(hour: Int, value: Double, isCurrentHour: Bool = false) {
        self.hour = hour
        self.value = value
        self.isCurrentHour = isCurrentHour
    }
    
    var hourLabel: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if isCurrentHour {
            formatter.dateFormat = "h:mma"
            return formatter.string(from: Date())
        } else {
            formatter.dateFormat = "ha"
            let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
            return formatter.string(from: date)
        }
    }
}

struct SleepDataPoint: Identifiable {
    let id = UUID()
    let hour: Int
    let minute: Int
    let stage: SleepStage
    
    var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
    
    var timeValue: Double {
        Double(hour) + Double(minute) / 60.0
    }
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
    
    @Published var hourlyCalories: [HourlyDataPoint] = []
    @Published var hourlySteps: [HourlyDataPoint] = []
    @Published var hourlyHeartRate: [HourlyDataPoint] = []
    @Published var sleepStages: [SleepDataPoint] = []
    @Published var hourlyExerciseMinutes: [HourlyDataPoint] = []
    
    private var healthStore: HKHealthStore?
    private var cancellables = Set<AnyCancellable>()
    
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
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
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
            authorizationStatus = .notDetermined
            requestAuthorization()
        case .sharingAuthorized:
            authorizationStatus = .authorized
            fetchTodayActivityData()
        case .sharingDenied:
            authorizationStatus = .denied
        @unknown default:
            authorizationStatus = .notDetermined
            requestAuthorization()
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
    
    private func createTodayPredicate() -> NSPredicate {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        return HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )
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
    
    private func loadMockData() {
        steps = 4523
        calories = 287
        exerciseMinutes = 32
        heartRate = 72
        sleepHours = 7.5
        
        let currentHour = Calendar.current.component(.hour, from: Date())
        
        hourlyCalories = generateMockHourlyData(baseValue: 20, variance: 15, currentHour: currentHour)
        hourlySteps = generateMockHourlyData(baseValue: 300, variance: 200, currentHour: currentHour)
        hourlyHeartRate = generateMockHourlyData(baseValue: 70, variance: 15, currentHour: currentHour)
        hourlyExerciseMinutes = generateMockHourlyData(baseValue: 2, variance: 3, currentHour: currentHour)
        sleepStages = generateMockSleepStages()
    }
    
    private func generateMockHourlyData(baseValue: Double, variance: Double, currentHour: Int) -> [HourlyDataPoint] {
        return (0...23).map { hour in
            let randomValue = hour <= currentHour ? max(0, baseValue + Double.random(in: -variance...variance)) : 0
            return HourlyDataPoint(hour: hour, value: randomValue, isCurrentHour: hour == currentHour)
        }
    }
    
    private func generateMockSleepStages() -> [SleepDataPoint] {
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
            stages.append(SleepDataPoint(hour: entry.startHour, minute: entry.startMin, stage: entry.stage))
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

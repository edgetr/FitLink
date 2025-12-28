import HealthKit
import FirebaseFirestore

// MARK: - HealthDataCollector

actor HealthDataCollector {
    
    static let shared = HealthDataCollector()
    
    private let healthStore = HKHealthStore()
    private let db = Firestore.firestore()
    private let metricsService = HealthMetricsService.shared
    private let repository = HealthKitRepository.shared
    
    @MainActor
    private var storageSettings: HealthDataStorageSettings { HealthDataStorageSettings.shared }
    
    // MARK: - HealthKit Types to Collect
    
    private let quantityTypes: [HKQuantityTypeIdentifier] = [
        .stepCount,
        .activeEnergyBurned,
        .basalEnergyBurned,
        .appleExerciseTime,
        .appleStandTime,
        .distanceWalkingRunning,
        .flightsClimbed,
        .heartRate,
        .restingHeartRate,
        .heartRateVariabilitySDNN
    ]
    
    private let categoryTypes: [HKCategoryTypeIdentifier] = [
        .sleepAnalysis
    ]
    
    private let workoutType = HKWorkoutType.workoutType()
    
    private init() {}
    
    // MARK: - Authorization
    
    func requestFullAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }
        
        var typesToRead: Set<HKObjectType> = []
        
        for identifier in quantityTypes {
            if let type = HKQuantityType.quantityType(forIdentifier: identifier) {
                typesToRead.insert(type)
            }
        }
        
        for identifier in categoryTypes {
            if let type = HKCategoryType.categoryType(forIdentifier: identifier) {
                typesToRead.insert(type)
            }
        }
        
        typesToRead.insert(workoutType)
        
        // Characteristics (read once)
        if let dobType = HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth) {
            typesToRead.insert(dobType)
        }
        if let sexType = HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex) {
            typesToRead.insert(sexType)
        }
        if let heightType = HKQuantityType.quantityType(forIdentifier: .height) {
            typesToRead.insert(heightType)
        }
        if let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            typesToRead.insert(weightType)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
    
    // MARK: - Initial Sync (Last 30 Days)
    
    func performInitialSync(userId: String) async throws {
        let endDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) else {
            throw HealthDataCollectorError.invalidDateRange
        }
        
        log("Starting optimized 30-day sync for user: \(userId)")
        
        let dailyMetrics = try await collectMetricsBatch(startDate: startDate, endDate: endDate, userId: userId)
        
        let patterns = PatternAnalyzer.analyzePatterns(from: dailyMetrics)
        
        let shouldPersistToCloud = await storageSettings.policy.allowsCloudStorage
        
        if shouldPersistToCloud {
            try await saveHealthMetrics(
                userId: userId,
                dailyMetrics: dailyMetrics,
                patterns: patterns
            )
            try await syncUserCharacteristics(userId: userId)
            await storageSettings.recordCloudSync()
            log("Initial sync complete: \(dailyMetrics.count) days of data saved to cloud")
        } else {
            log("Initial sync complete: \(dailyMetrics.count) days collected (on-device only, not persisted to cloud)")
        }
    }
    
    // MARK: - Optimized Batch Collection
    
    private func collectMetricsBatch(startDate: Date, endDate: Date, userId: String) async throws -> [DailyHealthMetrics] {
        let calendar = Calendar.current
        
        async let stepsData = repository.fetchDailyAggregates(.stepCount, startDate: startDate, endDate: endDate, unit: .count())
        async let activeCalData = repository.fetchDailyAggregates(.activeEnergyBurned, startDate: startDate, endDate: endDate, unit: .kilocalorie())
        async let basalCalData = repository.fetchDailyAggregates(.basalEnergyBurned, startDate: startDate, endDate: endDate, unit: .kilocalorie())
        async let exerciseData = repository.fetchDailyAggregates(.appleExerciseTime, startDate: startDate, endDate: endDate, unit: .minute())
        async let standData = repository.fetchDailyAggregates(.appleStandTime, startDate: startDate, endDate: endDate, unit: .count())
        async let distanceData = repository.fetchDailyAggregates(.distanceWalkingRunning, startDate: startDate, endDate: endDate, unit: .meterUnit(with: .kilo))
        async let flightsData = repository.fetchDailyAggregates(.flightsClimbed, startDate: startDate, endDate: endDate, unit: .count())
        
        async let hourlyStepsData = repository.fetchHourlyDataForRange(.stepCount, startDate: startDate, endDate: endDate, unit: .count())
        async let hourlyCaloriesData = repository.fetchHourlyDataForRange(.activeEnergyBurned, startDate: startDate, endDate: endDate, unit: .kilocalorie())
        
        let (steps, activeCal, basalCal, exercise, stand, distance, flights, hourlySteps, hourlyCals) =
            try await (stepsData, activeCalData, basalCalData, exerciseData, standData, distanceData, flightsData, hourlyStepsData, hourlyCaloriesData)
        
        var dailyMetrics: [DailyHealthMetrics] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            let dayStart = calendar.startOfDay(for: currentDate)
            let dateId = DailyHealthMetrics.makeId(userId: userId, date: currentDate)
            
            let daySteps = Int(steps[dayStart] ?? 0)
            let dayActiveCal = Int(activeCal[dayStart] ?? 0)
            let dayBasalCal = Int(basalCal[dayStart] ?? 0)
            let dayExercise = Int(exercise[dayStart] ?? 0)
            let dayStand = Int(stand[dayStart] ?? 0)
            let dayDistance = distance[dayStart] ?? 0
            let dayFlights = Int(flights[dayStart] ?? 0)
            
            let dayHourlySteps = (hourlySteps[dayStart] ?? Array(repeating: 0, count: 24)).map { Int($0) }
            let dayHourlyCals = (hourlyCals[dayStart] ?? Array(repeating: 0, count: 24)).map { Int($0) }
            
            async let restingHR = fetchAverage(.restingHeartRate, start: dayStart, end: calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart)
            async let avgHR = fetchAverage(.heartRate, start: dayStart, end: calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart)
            async let maxHR = fetchMax(.heartRate, start: dayStart, end: calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart)
            async let hrv = fetchHRV(start: dayStart, end: calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart)
            async let sleepData = fetchSleepData(start: dayStart, end: calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart)
            async let hourlyHR = repository.fetchHourlyHeartRate(date: currentDate)
            async let workouts = fetchWorkouts(start: dayStart, end: calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart)
            
            let (restingHRVal, avgHRVal, maxHRVal, hrvVal, sleep, hHR, workoutSessions) =
                try await (restingHR, avgHR, maxHR, hrv, sleepData, hourlyHR, workouts)
            
            let metrics = DailyHealthMetrics(
                id: dateId,
                date: currentDate,
                steps: daySteps,
                activeCalories: dayActiveCal,
                totalCalories: dayActiveCal + dayBasalCal,
                exerciseMinutes: dayExercise,
                standHours: dayStand,
                distanceKm: dayDistance,
                flightsClimbed: dayFlights,
                restingHeartRate: restingHRVal > 0 ? Int(restingHRVal) : nil,
                avgHeartRate: avgHRVal > 0 ? Int(avgHRVal) : nil,
                maxHeartRate: maxHRVal > 0 ? Int(maxHRVal) : nil,
                heartRateVariability: hrvVal > 0 ? hrvVal : nil,
                sleepHours: sleep.totalHours,
                sleepStartTime: sleep.startTime,
                sleepEndTime: sleep.endTime,
                sleepQuality: sleep.quality,
                sleepStages: sleep.stages,
                hourlySteps: dayHourlySteps,
                hourlyCalories: dayHourlyCals,
                hourlyHeartRate: hHR,
                workoutSessions: workoutSessions
            )
            
            dailyMetrics.append(metrics)
            
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        return dailyMetrics
    }
    
    // MARK: - Daily Sync
    
    func performDailySync(userId: String) async throws {
        let today = Calendar.current.startOfDay(for: Date())
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) else {
            throw HealthDataCollectorError.invalidDateRange
        }
        
        let shouldPersistToCloud = await storageSettings.policy.allowsCloudStorage
        
        if shouldPersistToCloud {
            if let metrics = try await collectDayMetrics(for: yesterday, userId: userId) {
                try await appendDailyMetrics(userId: userId, metrics: metrics)
            }
            
            if let todayMetrics = try await collectDayMetrics(for: today, userId: userId) {
                try await updateTodayMetrics(userId: userId, metrics: todayMetrics)
            }
            
            try await recalculatePatterns(userId: userId)
            try await pruneOldData(userId: userId)
            await storageSettings.recordCloudSync()
            log("Daily sync complete (cloud storage)")
        } else {
            log("Daily sync skipped - on-device only mode (data still available for LLM context)")
        }
    }
    
    // MARK: - Collect Day Metrics
    
    private func collectDayMetrics(for date: Date, userId: String) async throws -> DailyHealthMetrics? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }
        
        let dateId = DailyHealthMetrics.makeId(userId: userId, date: date)
        
        async let steps = fetchSum(.stepCount, start: startOfDay, end: endOfDay, unit: .count())
        async let activeCalories = fetchSum(.activeEnergyBurned, start: startOfDay, end: endOfDay, unit: .kilocalorie())
        async let basalCalories = fetchSum(.basalEnergyBurned, start: startOfDay, end: endOfDay, unit: .kilocalorie())
        async let exerciseMinutes = fetchSum(.appleExerciseTime, start: startOfDay, end: endOfDay, unit: .minute())
        async let standHours = fetchSum(.appleStandTime, start: startOfDay, end: endOfDay, unit: .count())
        async let distance = fetchSum(.distanceWalkingRunning, start: startOfDay, end: endOfDay, unit: .meterUnit(with: .kilo))
        async let flights = fetchSum(.flightsClimbed, start: startOfDay, end: endOfDay, unit: .count())
        
        async let restingHR = fetchAverage(.restingHeartRate, start: startOfDay, end: endOfDay)
        async let avgHR = fetchAverage(.heartRate, start: startOfDay, end: endOfDay)
        async let maxHR = fetchMax(.heartRate, start: startOfDay, end: endOfDay)
        async let hrv = fetchHRV(start: startOfDay, end: endOfDay)
        
        async let sleepData = fetchSleepData(start: startOfDay, end: endOfDay)
        async let hourlySteps = repository.fetchHourlyData(.stepCount, date: startOfDay, unit: .count())
        async let hourlyCalories = repository.fetchHourlyData(.activeEnergyBurned, date: startOfDay, unit: .kilocalorie())
        async let hourlyHR = repository.fetchHourlyHeartRate(date: startOfDay)
        async let workouts = fetchWorkouts(start: startOfDay, end: endOfDay)
        
        let (stepsVal, activeCalVal, basalCalVal, exerciseVal, standVal, distanceVal, flightsVal,
             restingHRVal, avgHRVal, maxHRVal, hrvVal, sleep, hSteps, hCals, hHR, workoutSessions) =
            try await (steps, activeCalories, basalCalories, exerciseMinutes, standHours, distance, flights,
                       restingHR, avgHR, maxHR, hrv, sleepData, hourlySteps, hourlyCalories, hourlyHR, workouts)
        
        return DailyHealthMetrics(
            id: dateId,
            date: date,
            steps: Int(stepsVal),
            activeCalories: Int(activeCalVal),
            totalCalories: Int(activeCalVal + basalCalVal),
            exerciseMinutes: Int(exerciseVal),
            standHours: Int(standVal),
            distanceKm: distanceVal,
            flightsClimbed: Int(flightsVal),
            restingHeartRate: restingHRVal > 0 ? Int(restingHRVal) : nil,
            avgHeartRate: avgHRVal > 0 ? Int(avgHRVal) : nil,
            maxHeartRate: maxHRVal > 0 ? Int(maxHRVal) : nil,
            heartRateVariability: hrvVal > 0 ? hrvVal : nil,
            sleepHours: sleep.totalHours,
            sleepStartTime: sleep.startTime,
            sleepEndTime: sleep.endTime,
            sleepQuality: sleep.quality,
            sleepStages: sleep.stages,
            hourlySteps: hSteps.map { Int($0) },
            hourlyCalories: hCals.map { Int($0) },
            hourlyHeartRate: hHR,
            workoutSessions: workoutSessions
        )
    }
    
    // MARK: - HealthKit Query Helpers
    
    private func fetchSum(
        _ identifier: HKQuantityTypeIdentifier,
        start: Date,
        end: Date,
        unit: HKUnit
    ) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchAverage(
        _ identifier: HKQuantityTypeIdentifier,
        start: Date,
        end: Date
    ) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let unit: HKUnit = HKUnit.count().unitDivided(by: .minute())
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = result?.averageQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchHRV(start: Date, end: Date) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return 0
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let unit: HKUnit = .secondUnit(with: .milli)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = result?.averageQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchMax(
        _ identifier: HKQuantityTypeIdentifier,
        start: Date,
        end: Date
    ) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let unit: HKUnit = HKUnit.count().unitDivided(by: .minute())
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteMax
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = result?.maximumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchSleepData(start: Date, end: Date) async throws -> SleepDataResult {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return SleepDataResult.empty
        }
        
        // Look at sleep from the previous night (start from 6PM previous day)
        let calendar = Calendar.current
        guard let sleepWindowStart = calendar.date(byAdding: .hour, value: -6, to: start) else {
            return SleepDataResult.empty
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: sleepWindowStart, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: SleepDataResult.empty)
                    return
                }
                
                var awakeMinutes = 0
                var remMinutes = 0
                var coreMinutes = 0
                var deepMinutes = 0
                var sleepStart: Date?
                var sleepEnd: Date?
                
                for sample in samples {
                    let duration = Int(sample.endDate.timeIntervalSince(sample.startDate) / 60)
                    
                    if sleepStart == nil || sample.startDate < sleepStart! {
                        sleepStart = sample.startDate
                    }
                    if sleepEnd == nil || sample.endDate > sleepEnd! {
                        sleepEnd = sample.endDate
                    }
                    
                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        awakeMinutes += duration
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        remMinutes += duration
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                        coreMinutes += duration
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        deepMinutes += duration
                    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                        coreMinutes += duration
                    default:
                        break
                    }
                }
                
                let stages = SleepStageBreakdown(
                    awakeMinutes: awakeMinutes,
                    remMinutes: remMinutes,
                    coreMinutes: coreMinutes,
                    deepMinutes: deepMinutes
                )
                
                let totalSleepHours = Double(stages.totalSleepMinutes) / 60.0
                let deepPercentage = stages.totalSleepMinutes > 0 ? Double(deepMinutes) / Double(stages.totalSleepMinutes) : 0
                let quality = SleepQuality.from(efficiency: stages.sleepEfficiency, deepPercentage: deepPercentage)
                
                continuation.resume(returning: SleepDataResult(
                    totalHours: totalSleepHours,
                    startTime: sleepStart,
                    endTime: sleepEnd,
                    quality: quality,
                    stages: stages
                ))
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSession] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let sessions = workouts.map { workout -> WorkoutSession in
                    WorkoutSession(
                        id: workout.uuid.uuidString,
                        type: HealthWorkoutType.from(hkType: workout.workoutActivityType),
                        startTime: workout.startDate,
                        endTime: workout.endDate,
                        durationMinutes: Int(workout.duration / 60),
                        caloriesBurned: Int(workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0),
                        avgHeartRate: nil,
                        maxHeartRate: nil
                    )
                }
                
                continuation.resume(returning: sessions)
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - User Characteristics Sync
    
    func syncUserCharacteristics(userId: String) async throws {
        var updates: [String: Any] = [:]
        
        // Date of Birth
        if let dob = try? healthStore.dateOfBirthComponents(),
           let date = Calendar.current.date(from: dob) {
            updates["date_of_birth"] = Timestamp(date: date)
        }
        
        // Biological Sex
        if let sex = try? healthStore.biologicalSex().biologicalSex {
            switch sex {
            case .male: updates["biological_sex"] = "male"
            case .female: updates["biological_sex"] = "female"
            case .other: updates["biological_sex"] = "other"
            default: break
            }
        }
        
        // Height (most recent)
        if let height = try await fetchMostRecent(.height) {
            updates["height_cm"] = height * 100 // Convert m to cm
        }
        
        // Weight (most recent)
        if let weight = try await fetchMostRecent(.bodyMass) {
            updates["weight_kg"] = weight
        }
        
        if !updates.isEmpty {
            updates["last_updated"] = Timestamp(date: Date())
            updates["data_sources_enabled"] = ["healthKit"]
            
            let docRef = db.collection("user_profiles").document(userId)
            try await docRef.setData(updates, merge: true)
        }
    }
    
    private func fetchMostRecent(_ identifier: HKQuantityTypeIdentifier) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let unit: HKUnit = identifier == .height ? .meter() : .gramUnit(with: .kilo)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Firestore Operations
    
    private func saveHealthMetrics(
        userId: String,
        dailyMetrics: [DailyHealthMetrics],
        patterns: HealthPatterns
    ) async throws {
        // Save daily metrics in batch
        try await metricsService.saveDailyMetricsBatch(dailyMetrics, userId: userId)
        
        // Save aggregate store with patterns
        let dates = dailyMetrics.map { $0.date }
        let oldestDate = dates.min() ?? Date()
        let newestDate = dates.max() ?? Date()
        
        let store = HealthMetricsStore(
            id: userId,
            userId: userId,
            dailyMetrics: [],
            avgStepsPerDay: patterns.avgStepsPerDay,
            avgCaloriesBurned: patterns.avgCaloriesBurned,
            avgExerciseMinutes: patterns.avgExerciseMinutes,
            avgSleepHours: patterns.avgSleepHours,
            avgRestingHeartRate: patterns.avgRestingHeartRate,
            peakActivityHours: patterns.peakActivityHours,
            typicalWakeTime: patterns.typicalWakeTime,
            typicalSleepTime: patterns.typicalSleepTime,
            mostActiveWeekdays: patterns.mostActiveWeekdays,
            activityTrend: patterns.activityTrend,
            lastSyncedAt: Date(),
            oldestDataDate: oldestDate,
            newestDataDate: newestDate
        )
        
        try await metricsService.saveMetricsStore(store)
    }
    
    private func appendDailyMetrics(userId: String, metrics: DailyHealthMetrics) async throws {
        try await metricsService.saveDailyMetrics(metrics, userId: userId)
    }
    
    private func updateTodayMetrics(userId: String, metrics: DailyHealthMetrics) async throws {
        try await metricsService.saveDailyMetrics(metrics, userId: userId)
    }
    
    private func recalculatePatterns(userId: String) async throws {
        try await metricsService.updateAggregates(for: userId)
    }
    
    private func pruneOldData(userId: String) async throws {
        _ = try await metricsService.maintainRollingWindow(for: userId)
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        #if DEBUG
        print("[HealthDataCollector] \(message)")
        #endif
    }
}

// MARK: - Helper Types

private struct SleepDataResult {
    let totalHours: Double?
    let startTime: Date?
    let endTime: Date?
    let quality: SleepQuality?
    let stages: SleepStageBreakdown?
    
    static let empty = SleepDataResult(
        totalHours: nil,
        startTime: nil,
        endTime: nil,
        quality: nil,
        stages: nil
    )
}

// MARK: - HealthWorkoutType Extension

extension HealthWorkoutType {
    static func from(hkType: HKWorkoutActivityType) -> HealthWorkoutType {
        switch hkType {
        case .running: return .running
        case .walking: return .walking
        case .cycling: return .cycling
        case .swimming: return .swimming
        case .traditionalStrengthTraining: return .strengthTraining
        case .functionalStrengthTraining: return .functionalTraining
        case .highIntensityIntervalTraining: return .hiit
        case .yoga: return .yoga
        case .pilates: return .pilates
        case .elliptical: return .elliptical
        case .rowing: return .rowing
        case .stairClimbing: return .stairClimbing
        default: return .other
        }
    }
}

// MARK: - Errors

enum HealthDataCollectorError: LocalizedError {
    case healthKitNotAvailable
    case authorizationDenied
    case invalidDateRange
    case syncFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device."
        case .authorizationDenied:
            return "HealthKit authorization was denied."
        case .invalidDateRange:
            return "Invalid date range for health data collection."
        case .syncFailed(let reason):
            return "Health data sync failed: \(reason)"
        }
    }
}

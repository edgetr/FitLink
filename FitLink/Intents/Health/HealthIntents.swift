import AppIntents
import SwiftUI
import HealthKit

// MARK: - Get Steps Intent

struct GetStepsIntent: AppIntent {
    static var title: LocalizedStringResource = "Step Count"
    static var description = IntentDescription("Get your step count for today")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        do {
            let steps = try await fetchTodaySteps()
            let goal = 10_000 // Could be user-configurable
            let percentage = min(100, Int((Double(steps) / Double(goal)) * 100))
            
            let dialog: String
            if steps >= goal {
                dialog = "You crushed your step goal with \(steps.formatted()) steps today!"
            } else {
                let remaining = goal - steps
                dialog = "You have \(steps.formatted()) steps today. Just \(remaining.formatted()) more to hit your goal!"
            }
            
            return .result(dialog: IntentDialog(stringLiteral: dialog)) {
                HealthMetricSnippetView(
                    title: "Steps",
                    value: steps.formatted(),
                    icon: "figure.walk",
                    color: .green,
                    progress: Double(percentage) / 100,
                    goal: "\(goal.formatted()) goal"
                )
            }
        } catch {
            return .result(
                dialog: "I couldn't get your step count. Make sure Health access is enabled in Settings."
            ) {
                HealthErrorSnippetView(metric: "Steps")
            }
        }
    }
    
    private func fetchTodaySteps() async throws -> Int {
        let healthStore = HKHealthStore()
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthIntentError.invalidType
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            
            healthStore.execute(query)
        }
    }
}

// MARK: - Get Calories Intent

struct GetCaloriesIntent: AppIntent {
    static var title: LocalizedStringResource = "Calories Burned"
    static var description = IntentDescription("Get your active calories burned today")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        do {
            let calories = try await fetchTodayActiveCalories()
            let goal = 500 // Could be user-configurable
            let percentage = min(100, Int((calories / Double(goal)) * 100))
            
            let dialog: String
            if Int(calories) >= goal {
                dialog = "Great work! You've burned \(Int(calories)) active calories today!"
            } else {
                let remaining = goal - Int(calories)
                dialog = "You've burned \(Int(calories)) active calories. \(remaining) more to reach your goal."
            }
            
            return .result(dialog: IntentDialog(stringLiteral: dialog)) {
                HealthMetricSnippetView(
                    title: "Active Calories",
                    value: "\(Int(calories))",
                    icon: "flame.fill",
                    color: .orange,
                    progress: min(1, calories / Double(goal)),
                    goal: "\(goal) kcal goal"
                )
            }
        } catch {
            return .result(
                dialog: "I couldn't get your calorie data. Make sure Health access is enabled."
            ) {
                HealthErrorSnippetView(metric: "Calories")
            }
        }
    }
    
    private func fetchTodayActiveCalories() async throws -> Double {
        let healthStore = HKHealthStore()
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthIntentError.invalidType
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: calorieType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let calories = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: calories)
            }
            
            healthStore.execute(query)
        }
    }
}

// MARK: - Get Health Summary Intent

struct GetHealthSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Health Summary"
    static var description = IntentDescription("Get an overview of today's health metrics")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        do {
            async let stepsValue = fetchTodayMetric(.stepCount, unit: .count())
            async let caloriesValue = fetchTodayMetric(.activeEnergyBurned, unit: .kilocalorie())
            async let exerciseValue = fetchTodayMetric(.appleExerciseTime, unit: .minute())
            
            let (steps, calories, exercise) = try await (stepsValue, caloriesValue, exerciseValue)
            
            return .result(
                dialog: "Today you've taken \(Int(steps).formatted()) steps, burned \(Int(calories)) active calories, and exercised for \(Int(exercise)) minutes."
            ) {
                HealthSummarySnippetView(
                    steps: Int(steps),
                    calories: Int(calories),
                    exerciseMinutes: Int(exercise)
                )
            }
        } catch {
            return .result(
                dialog: "I couldn't get your health summary. Please check Health permissions in Settings."
            ) {
                HealthErrorSnippetView(metric: "Health Data")
            }
        }
    }
    
    private func fetchTodayMetric(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double {
        let healthStore = HKHealthStore()
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            throw HealthIntentError.invalidType
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
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
}

// MARK: - Health Intent Error

enum HealthIntentError: LocalizedError {
    case invalidType
    case queryFailed
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidType:
            return "Invalid health data type"
        case .queryFailed:
            return "Failed to query health data"
        case .noData:
            return "No health data available"
        }
    }
}

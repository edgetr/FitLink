import SwiftUI
import Combine
import HealthKit

#if os(watchOS)

struct HealthSummaryWatchView: View {
    
    @EnvironmentObject var sessionManager: WatchSessionManager
    @StateObject private var healthCollector = WatchHealthCollector()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    greetingHeader
                    
                    activityRingsCard
                    
                    metricsGrid
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 16)
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await healthCollector.fetchTodayMetrics()
                }
            }
            .refreshable {
                await healthCollector.fetchTodayMetrics()
            }
        }
    }
    
    private var greetingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                if let name = sessionManager.userAuth.displayName?.components(separatedBy: " ").first {
                    Text(name)
                        .font(.headline)
                        .fontWeight(.bold)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }
    
    private var activityRingsCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: calorieProgress)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Circle()
                    .stroke(Color.green.opacity(0.3), lineWidth: 6)
                    .padding(8)
                Circle()
                    .trim(from: 0, to: exerciseProgress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(8)
                
                Circle()
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 6)
                    .padding(16)
                Circle()
                    .trim(from: 0, to: stepProgress)
                    .stroke(Color.cyan, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(16)
            }
            .frame(width: 80, height: 80)
            
            VStack(alignment: .leading, spacing: 6) {
                ringLegend(color: .red, value: "\(healthCollector.activeCalories)", label: "cal")
                ringLegend(color: .green, value: "\(healthCollector.exerciseMinutes)", label: "min")
                ringLegend(color: .cyan, value: formatSteps(healthCollector.steps), label: "steps")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.15))
        )
    }
    
    private func ringLegend(color: Color, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(value)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            metricCard(
                icon: "figure.walk",
                value: formatSteps(healthCollector.steps),
                label: "Steps",
                color: .cyan
            )
            
            metricCard(
                icon: "flame.fill",
                value: "\(healthCollector.activeCalories)",
                label: "Calories",
                color: .orange
            )
            
            metricCard(
                icon: "figure.run",
                value: "\(healthCollector.exerciseMinutes)",
                label: "Exercise",
                color: .green
            )
            
            metricCard(
                icon: "heart.fill",
                value: "--",
                label: "Heart Rate",
                color: .red
            )
        }
    }
    
    private func metricCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.15))
        )
    }
    
    private var calorieProgress: Double {
        min(1.0, Double(healthCollector.activeCalories) / 500.0)
    }
    
    private var exerciseProgress: Double {
        min(1.0, Double(healthCollector.exerciseMinutes) / 30.0)
    }
    
    private var stepProgress: Double {
        min(1.0, Double(healthCollector.steps) / 10000.0)
    }
    
    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            let k = Double(steps) / 1000.0
            return String(format: "%.1fk", k)
        }
        return "\(steps)"
    }
}

@MainActor
class WatchHealthCollector: ObservableObject {
    
    @Published var steps: Int = 0
    @Published var activeCalories: Int = 0
    @Published var exerciseMinutes: Int = 0
    @Published var lastUpdated: Date?
    
    private let healthStore = HKHealthStore()
    
    func fetchTodayMetrics() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let readTypes: Set<HKSampleType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime)
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            
            async let stepsResult = fetchTodaySum(for: .stepCount, unit: .count())
            async let caloriesResult = fetchTodaySum(for: .activeEnergyBurned, unit: .kilocalorie())
            async let exerciseResult = fetchTodaySum(for: .appleExerciseTime, unit: .minute())
            
            let (s, c, e) = await (stepsResult, caloriesResult, exerciseResult)
            
            steps = Int(s)
            activeCalories = Int(c)
            exerciseMinutes = Int(e)
            lastUpdated = Date()
        } catch {
            log("HealthKit authorization failed: \(error.localizedDescription)")
        }
    }
    
    private func fetchTodaySum(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0
        }
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    self.log("Query failed for \(identifier.rawValue): \(error.localizedDescription)")
                    continuation.resume(returning: 0)
                    return
                }
                
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func log(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [WatchHealthCollector] \(message)")
        #endif
    }
}

#endif

import SwiftUI

// MARK: - Health Metric Snippet View

struct HealthMetricSnippetView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let progress: Double
    let goal: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: min(1, progress))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
            }
            .frame(width: 64, height: 64)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                
                Text(goal)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if progress >= 1.0 {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title)
                    .foregroundStyle(.green)
            }
        }
        .padding()
    }
}

// MARK: - Health Summary Snippet View

struct HealthSummarySnippetView: View {
    let steps: Int
    let calories: Int
    let exerciseMinutes: Int
    
    private let stepsGoal = 10_000
    private let caloriesGoal = 500
    private let exerciseGoal = 30
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Today's Activity")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                // Steps
                MetricRing(
                    icon: "figure.walk",
                    value: steps,
                    goal: stepsGoal,
                    color: .green,
                    label: "Steps"
                )
                
                // Calories
                MetricRing(
                    icon: "flame.fill",
                    value: calories,
                    goal: caloriesGoal,
                    color: .orange,
                    label: "kcal"
                )
                
                // Exercise
                MetricRing(
                    icon: "figure.run",
                    value: exerciseMinutes,
                    goal: exerciseGoal,
                    color: .cyan,
                    label: "min"
                )
            }
        }
        .padding()
    }
}

// MARK: - Metric Ring

private struct MetricRing: View {
    let icon: String
    let value: Int
    let goal: Int
    let color: Color
    let label: String
    
    private var progress: Double {
        min(1, Double(value) / Double(goal))
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
            }
            .frame(width: 50, height: 50)
            
            Text("\(value)")
                .font(.caption.bold())
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Health Error Snippet View

struct HealthErrorSnippetView: View {
    let metric: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Unable to access \(metric)")
                    .font(.headline)
                
                Text("Check Health permissions in Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Previews

#Preview("Health Metric - Steps") {
    HealthMetricSnippetView(
        title: "Steps",
        value: "8,234",
        icon: "figure.walk",
        color: .green,
        progress: 0.82,
        goal: "10,000 goal"
    )
}

#Preview("Health Metric - Goal Met") {
    HealthMetricSnippetView(
        title: "Active Calories",
        value: "520",
        icon: "flame.fill",
        color: .orange,
        progress: 1.04,
        goal: "500 kcal goal"
    )
}

#Preview("Health Summary") {
    HealthSummarySnippetView(
        steps: 7500,
        calories: 380,
        exerciseMinutes: 25
    )
}

#Preview("Health Error") {
    HealthErrorSnippetView(metric: "Steps")
}

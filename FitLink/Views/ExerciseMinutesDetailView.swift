import SwiftUI

struct ExerciseMinutesDetailView: View {
    @ObservedObject var viewModel: ActivitySummaryViewModel
    @State private var selectedDate = Date()
    
    private var dateRange: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (-6...0).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today)
        }
    }
    
    private var dateDescriptor: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "today"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: selectedDate)
        }
    }
    
    var body: some View {
        MetricDetailScreen(
            title: "Exercise",
            viewModel: viewModel,
            selectedDate: $selectedDate,
            dateRange: dateRange
        ) {
            MetricValueCard(
                iconName: "figure.run",
                iconGradient: [.green, .mint],
                value: viewModel.formattedExerciseMinutes,
                subtitle: "of exercise \(dateDescriptor)"
            )
            
            HourlyBarChart(
                title: "Hourly Breakdown",
                dataPoints: viewModel.hourlyExerciseMinutes,
                gradientColors: [.green, .mint],
                highlightGradientColors: [.yellow, .green],
                valueMultiplier: 20.0,
                formatValue: { "\(Int($0))m" }
            )
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseMinutesDetailView(viewModel: ActivitySummaryViewModel())
    }
}

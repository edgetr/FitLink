import SwiftUI

struct CaloriesDetailView: View {
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
            title: "Calories",
            viewModel: viewModel,
            selectedDate: $selectedDate,
            dateRange: dateRange
        ) {
            MetricValueCard(
                iconName: "flame.fill",
                iconGradient: [.orange, .red],
                value: viewModel.formattedCalories,
                subtitle: "calories burned \(dateDescriptor)"
            )
            
            HourlyBarChart(
                title: "Hourly Breakdown",
                dataPoints: viewModel.hourlyCalories,
                gradientColors: [.orange, .red],
                highlightGradientColors: [.yellow, .orange],
                valueMultiplier: 3.0
            )
        }
    }
}

#Preview {
    NavigationStack {
        CaloriesDetailView(viewModel: ActivitySummaryViewModel())
    }
}

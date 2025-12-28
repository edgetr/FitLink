import SwiftUI

struct HeartRateDetailView: View {
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
            title: "Heart Rate",
            viewModel: viewModel,
            selectedDate: $selectedDate,
            dateRange: dateRange
        ) {
            MetricValueCard(
                iconName: "heart.fill",
                iconGradient: [.pink, .red],
                value: viewModel.formattedHeartRate,
                subtitle: "average heart rate \(dateDescriptor)"
            )
            
            HourlyBarChart(
                title: "Hourly Average",
                dataPoints: viewModel.hourlyHeartRate,
                gradientColors: [.pink, .red],
                highlightGradientColors: [.orange, .red],
                valueMultiplier: 1.0
            )
        }
    }
}

#Preview {
    NavigationStack {
        HeartRateDetailView(viewModel: ActivitySummaryViewModel())
    }
}

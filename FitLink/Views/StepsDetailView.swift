import SwiftUI

struct StepsDetailView: View {
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
            title: "Steps",
            viewModel: viewModel,
            selectedDate: $selectedDate,
            dateRange: dateRange
        ) {
            MetricValueCard(
                iconName: "figure.walk",
                iconGradient: [.blue, .cyan],
                value: viewModel.formattedSteps,
                subtitle: "steps taken \(dateDescriptor)"
            )
            
            HourlyBarChart(
                title: "Hourly Breakdown",
                dataPoints: viewModel.hourlySteps,
                gradientColors: [.blue, .cyan],
                highlightGradientColors: [.green, .cyan],
                valueMultiplier: 0.1
            )
        }
    }
}

struct MetricValueCard: View {
    let iconName: String
    let iconGradient: [Color]
    let value: String
    let subtitle: String
    var accessibilityLabel: String? = nil
    
    var body: some View {
        VStack(spacing: GlassTokens.Padding.compact) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: iconGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: GlassTokens.MetricCard.iconCircleSize, height: GlassTokens.MetricCard.iconCircleSize)
                
                Image(systemName: iconName)
                    .font(.system(size: GlassTokens.IconSize.metric))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
            
            Text(value)
                .font(.system(size: GlassTokens.MetricCard.primaryValueSize, weight: .bold))
                .monospacedDigit()
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, GlassTokens.Padding.large)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel ?? "\(value) \(subtitle)")
    }
}

#Preview {
    NavigationStack {
        StepsDetailView(viewModel: ActivitySummaryViewModel())
    }
}

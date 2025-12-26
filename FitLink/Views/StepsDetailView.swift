import SwiftUI
import Charts

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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                LiquidGlassDateStrip(
                    selectedDate: $selectedDate,
                    dateRange: dateRange
                )
                .padding(.horizontal, -GlassTokens.Layout.pageHorizontalPadding)
                
                totalValueCard
                hourlyChartSection
                Spacer()
            }
            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
            .padding(.top, 16)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Steps")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var totalValueCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "figure.walk")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            
            Text(viewModel.formattedSteps)
                .font(.system(size: 48, weight: .bold))
                .monospacedDigit()
            
            Text("steps taken today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
    }
    
    private var hourlyChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hourly Breakdown")
                .font(.headline)
            
            if viewModel.hourlySteps.isEmpty {
                Text("No data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(viewModel.hourlySteps) { dataPoint in
                                VStack(spacing: 4) {
                                    if dataPoint.value > 0 {
                                        Text("\(Int(dataPoint.value))")
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundStyle(dataPoint.isCurrentHour ? .primary : .secondary)
                                    }
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            dataPoint.isCurrentHour ?
                                            LinearGradient(colors: [.green, .cyan], startPoint: .bottom, endPoint: .top) :
                                            LinearGradient(colors: [.blue, .cyan], startPoint: .bottom, endPoint: .top)
                                        )
                                        .frame(width: 28, height: max(4, CGFloat(dataPoint.value) / 10))
                                    
                                    Text(dataPoint.hourLabel)
                                        .font(.system(size: 9))
                                        .foregroundStyle(dataPoint.isCurrentHour ? .primary : .secondary)
                                        .fontWeight(dataPoint.isCurrentHour ? .bold : .regular)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .id(dataPoint.hour)
                            }
                        }
                        .frame(height: 240)
                        .padding(.horizontal, 8)
                    }
                    .onAppear {
                        let currentHour = Calendar.current.component(.hour, from: Date())
                        withAnimation {
                            proxy.scrollTo(max(0, currentHour - 2), anchor: .leading)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        StepsDetailView(viewModel: ActivitySummaryViewModel())
    }
}

import SwiftUI

struct SleepDetailView: View {
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
            return "last night"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "night before"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: selectedDate)
        }
    }
    
    var body: some View {
        MetricDetailScreen(
            title: "Sleep",
            viewModel: viewModel,
            selectedDate: $selectedDate,
            dateRange: dateRange
        ) {
            MetricValueCard(
                iconName: "moon.fill",
                iconGradient: [.indigo, .purple],
                value: viewModel.formattedSleepHours,
                subtitle: "hours of sleep \(dateDescriptor)"
            )
            
            sleepStagesChart
            sleepStageLegend
        }
    }
    
    private var sleepStagesChart: some View {
        VStack(alignment: .leading, spacing: GlassTokens.Padding.standard) {
            Text("Sleep Stages")
                .font(.headline)
            
            if viewModel.sleepStages.isEmpty {
                Text("No sleep data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, GlassTokens.Padding.hero)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        ZStack(alignment: .topLeading) {
                            ForEach(Array(viewModel.sleepStages.enumerated()), id: \.element.id) { index, dataPoint in
                                if index < viewModel.sleepStages.count - 1 {
                                    let nextPoint = viewModel.sleepStages[index + 1]
                                    let startX = timeToX(dataPoint.timeValue, in: 600)
                                    let endX = timeToX(nextPoint.timeValue, in: 600)
                                    let width = max(6, endX - startX - 2)
                                    let yOffset = CGFloat(dataPoint.stage.sortOrder) * 28 + 4
                                    
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(dataPoint.stage.color)
                                        .frame(width: width, height: 20)
                                        .offset(x: startX, y: yOffset)
                                }
                            }
                        }
                        .frame(width: 600, height: 120)
                        .padding(.horizontal, 4)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(0..<9) { i in
                                let hour = (23 + i) % 24
                                Text(formatHour(hour))
                                    .font(.system(size: GlassTokens.FixedTypography.chartLabel))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 66.5, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, GlassTokens.Padding.small)
                    }
                }
            }
        }
        .padding(GlassTokens.Padding.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
    }
    
    private var sleepStageLegend: some View {
        VStack(alignment: .leading, spacing: GlassTokens.Padding.compact) {
            Text("Sleep Stages")
                .font(.headline)
            
            VStack(spacing: GlassTokens.Padding.small) {
                ForEach(SleepStage.allCases, id: \.self) { stage in
                    HStack(spacing: GlassTokens.Padding.compact) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(stage.color)
                            .frame(width: 24, height: 16)
                        
                        Text(stage.rawValue)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text(stageDescription(stage))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(GlassTokens.Padding.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
    }
    
    private func timeToX(_ time: Double, in width: CGFloat) -> CGFloat {
        var adjustedTime = time
        if time >= 23 {
            adjustedTime = time - 23
        } else {
            adjustedTime = time + 1
        }
        return CGFloat(adjustedTime / 8.0) * width
    }
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
    
    private func stageDescription(_ stage: SleepStage) -> String {
        switch stage {
        case .awake: return "Brief awakenings"
        case .rem: return "Dream sleep"
        case .core: return "Light sleep"
        case .deep: return "Restorative sleep"
        }
    }
}

#Preview {
    NavigationStack {
        SleepDetailView(viewModel: ActivitySummaryViewModel())
    }
}

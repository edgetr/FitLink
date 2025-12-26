import SwiftUI
import Charts

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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                LiquidGlassDateStrip(
                    selectedDate: $selectedDate,
                    dateRange: dateRange
                )
                .padding(.horizontal, -GlassTokens.Layout.pageHorizontalPadding)
                
                totalValueCard
                sleepStagesChart
                sleepStageLegend
                Spacer()
            }
            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
            .padding(.top, 16)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var totalValueCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "moon.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            
            Text(viewModel.formattedSleepHours)
                .font(.system(size: 48, weight: .bold))
                .monospacedDigit()
            
            Text("hours of sleep")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
    }
    
    private var sleepStagesChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep Stages")
                .font(.headline)
            
            if viewModel.sleepStages.isEmpty {
                Text("No sleep data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
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
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 66.5, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
    }
    
    private var sleepStageLegend: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Stages")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(SleepStage.allCases, id: \.self) { stage in
                    HStack(spacing: 12) {
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
        .padding(16)
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

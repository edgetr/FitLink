import SwiftUI

struct HourlyBarChart: View {
    let title: String
    let dataPoints: [HourlyDataPoint]
    let gradientColors: [Color]
    let highlightGradientColors: [Color]
    var valueMultiplier: CGFloat = 1.0
    var formatValue: ((Double) -> String)? = nil
    var emptyMessage: String = "No data available"
    
    private var chartAccessibilityLabel: String {
        guard !dataPoints.isEmpty else { return "\(title): \(emptyMessage)" }
        let total = dataPoints.reduce(0) { $0 + $1.value }
        let peakPoint = dataPoints.max(by: { $0.value < $1.value })
        var label = "\(title). Total: \(formattedValue(total))."
        if let peak = peakPoint, peak.value > 0 {
            label += " Peak at \(peak.hourLabel) with \(formattedValue(peak.value))."
        }
        return label
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: GlassTokens.Padding.standard) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            
            if dataPoints.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, GlassTokens.Padding.hero)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .bottom, spacing: GlassTokens.Padding.small) {
                            ForEach(dataPoints) { dataPoint in
                                VStack(spacing: 4) {
                                    if dataPoint.value > 0 {
                                        Text(formattedValue(dataPoint.value))
                                            .font(.system(size: GlassTokens.FixedTypography.chartValueLabel, weight: .medium))
                                            .foregroundStyle(dataPoint.isCurrentHour ? .primary : .secondary)
                                    }
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            dataPoint.isCurrentHour ?
                                            LinearGradient(colors: highlightGradientColors, startPoint: .bottom, endPoint: .top) :
                                            LinearGradient(colors: gradientColors, startPoint: .bottom, endPoint: .top)
                                        )
                                        .frame(
                                            width: GlassTokens.MetricCard.barWidth,
                                            height: max(GlassTokens.MetricCard.minBarHeight, CGFloat(dataPoint.value) * valueMultiplier)
                                        )
                                    
                                    Text(dataPoint.hourLabel)
                                        .font(.system(size: GlassTokens.FixedTypography.chartAxisLabel))
                                        .foregroundStyle(dataPoint.isCurrentHour ? .primary : .secondary)
                                        .fontWeight(dataPoint.isCurrentHour ? .bold : .regular)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .id(dataPoint.hour)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(dataPoint.hourLabel): \(formattedValue(dataPoint.value))")
                            }
                        }
                        .frame(height: GlassTokens.MetricCard.chartHeight)
                        .padding(.horizontal, GlassTokens.Padding.small)
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
        .padding(GlassTokens.Padding.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(chartAccessibilityLabel)
    }
    
    private func formattedValue(_ value: Double) -> String {
        if let formatter = formatValue {
            return formatter(value)
        }
        return "\(Int(value))"
    }
}

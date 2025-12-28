import SwiftUI

struct MetricDetailScreen<Content: View>: View {
    let title: String
    @ObservedObject var viewModel: ActivitySummaryViewModel
    @Binding var selectedDate: Date
    let dateRange: [Date]
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        ScrollView {
            VStack(spacing: GlassTokens.Padding.section) {
                LiquidGlassDateStrip(
                    selectedDate: $selectedDate,
                    dateRange: dateRange
                )
                .padding(.horizontal, -GlassTokens.Layout.pageHorizontalPadding)
                
                content()
                
                Spacer()
            }
            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
            .padding(.top, GlassTokens.Padding.standard)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedDate) {
            await viewModel.fetchActivityData(for: selectedDate)
        }
    }
}

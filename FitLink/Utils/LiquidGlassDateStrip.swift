import SwiftUI

struct LiquidGlassDateStrip: View {
    @Binding var selectedDate: Date
    let dateRange: [Date]
    
    @Namespace private var namespace
    
    private let calendar = Calendar.current
    
    init(selectedDate: Binding<Date>, dateRange: [Date]? = nil) {
        self._selectedDate = selectedDate
        self.dateRange = dateRange ?? Self.defaultDateRange()
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(dateRange, id: \.self) { date in
                            DateCell(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                namespace: namespace
                            )
                            .id(date)
                            .onTapGesture {
                                withAnimation(.bouncy(duration: 0.3)) {
                                    selectedDate = date
                                }
                            }
                        }
                    }
                    .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                    .padding(.vertical, 8)
                }
            }
            .onAppear {
                scrollToSelected(proxy: proxy, animated: false)
            }
            .onChange(of: selectedDate) { _, _ in
                scrollToSelected(proxy: proxy, animated: true)
            }
        }
    }
    
    private func scrollToSelected(proxy: ScrollViewProxy, animated: Bool) {
        let matchingDate = dateRange.first { calendar.isDate($0, inSameDayAs: selectedDate) }
        guard let targetDate = matchingDate else { return }
        
        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                proxy.scrollTo(targetDate, anchor: .center)
            }
        } else {
            proxy.scrollTo(targetDate, anchor: .center)
        }
    }
    
    private static func defaultDateRange() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (-3...3).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today)
        }
    }
}

private struct DateCell: View {
    let date: Date
    let isSelected: Bool
    let namespace: Namespace.ID
    
    private let calendar = Calendar.current
    
    private var dayNumber: String {
        let day = calendar.component(.day, from: date)
        return "\(day)"
    }
    
    private var weekdayAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(weekdayAbbreviation)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .primary : .secondary)
            
            Text(dayNumber)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? .primary : (isToday ? .blue : .primary))
        }
        .frame(width: 48, height: 60)
        .glassEffect(
            isSelected ? Glass.regular.tint(.blue).interactive() : .identity,
            in: Capsule()
        )
        .glassEffectID(date, in: namespace)
        .contentShape(Rectangle())
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack {
            LiquidGlassDateStrip(selectedDate: .constant(Date()))
            Spacer()
        }
    }
}

import SwiftUI

struct LiquidGlassSegmentedPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [(T, String)]
    var namespace: Namespace.ID
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            let segmentWidth = geometry.size.width / CGFloat(options.count)
            let selectedIndex = options.firstIndex(where: { $0.0 == selection }) ?? 0
            
            ZStack(alignment: .leading) {
                LiquidGlassIndicator(colorScheme: colorScheme)
                    .frame(width: segmentWidth - 8, height: geometry.size.height - 8)
                    .offset(x: CGFloat(selectedIndex) * segmentWidth + 4)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selectedIndex)
                
                HStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        Button {
                            guard selection != option.0 else { return }
                            triggerHaptic()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                selection = option.0
                            }
                        } label: {
                            Text(option.1)
                                .font(.subheadline)
                                .fontWeight(selection == option.0 ? .semibold : .medium)
                                .foregroundStyle(selection == option.0 ? .primary : .secondary)
                                .frame(width: segmentWidth, height: geometry.size.height)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(height: 44)
    }
    
    private func triggerHaptic() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}

private struct LiquidGlassIndicator: View {
    let colorScheme: ColorScheme
    
    private var blueTint: Color {
        colorScheme == .dark ? Color.blue.opacity(0.3) : Color.blue.opacity(0.18)
    }
    
    var body: some View {
        Capsule()
            .fill(.regularMaterial)
            .overlay(
                Capsule()
                    .fill(blueTint)
            )
            .overlay(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.25 : 0.8),
                                Color.white.opacity(colorScheme == .dark ? 0.08 : 0.25),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.4 : 0.95),
                                Color.white.opacity(colorScheme == .dark ? 0.15 : 0.4),
                                Color.blue.opacity(0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.blue.opacity(0.15), radius: 8, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    @Previewable @State var selection = 1
    @Previewable @Namespace var namespace
    
    VStack(spacing: 40) {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme")
                .font(.headline)
            
            LiquidGlassSegmentedPicker(
                selection: $selection,
                options: [(0, "System"), (1, "Light"), (2, "Dark")],
                namespace: namespace
            )
        }
        .padding()
        
        Text("Selected: \(selection)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding()
    .background(Color.gray.opacity(0.15))
}

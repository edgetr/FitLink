import SwiftUI

struct GlassCard<Content: View>: View {
    let tintColor: Color?
    let isInteractive: Bool
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        tint: Color? = nil,
        isInteractive: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tintColor = tint
        self.isInteractive = isInteractive
        self.content = content
    }
    
    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous)
                            .fill(tintColor?.opacity(0.1) ?? Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous)
                            .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.15), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.1), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Neutral Card")
                        .font(.headline)
                    Text("This is a glass card with neutral tint")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            GlassCard(tint: .blue) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Card")
                        .font(.headline)
                    Text("This card has a blue tint")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            GlassCard(tint: .green, isInteractive: true) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Success!")
                }
                .padding()
            }
        }
        .padding()
    }
}

import SwiftUI

struct PersonalizationBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("📋")
                .font(.caption2)
            
            Text("Using your profile")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.blue)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.1))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.blue.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PersonalizationBadge()
    }
}

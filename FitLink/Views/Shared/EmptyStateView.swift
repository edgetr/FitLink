import SwiftUI

struct EmptyStateView: View {
    let iconName: String
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: GlassTokens.Padding.standard) {
            Image(systemName: iconName)
                .font(.system(size: GlassTokens.IconSize.emptyState))
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, GlassTokens.Padding.small)
            }
        }
        .padding(GlassTokens.Padding.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        iconName: "tray",
        title: "No Data Available",
        subtitle: "Check back later for updates",
        actionTitle: "Refresh",
        action: {}
    )
}

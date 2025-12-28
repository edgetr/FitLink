import SwiftUI

struct HealthPermissionView: View {
    let onConnect: () -> Void
    let onSkip: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // MARK: - Header Icons
                HStack(spacing: 16) {
                    Text("🏃‍♂️")
                        .font(.system(size: 44))
                    Text("💪")
                        .font(.system(size: 44))
                    Text("😴")
                        .font(.system(size: 44))
                }
                
                // MARK: - Title
                VStack(spacing: 8) {
                    Text("Personalize Your Experience")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("FitLink uses your health data to create workout and meal plans that fit YOUR lifestyle.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                }
                
                // MARK: - Benefits Cards
                VStack(spacing: GlassTokens.Layout.cardSpacing) {
                    BenefitCard(
                        icon: "📊",
                        title: "Activity patterns",
                        description: "We'll learn when you're most active"
                    )
                    
                    BenefitCard(
                        icon: "😴",
                        title: "Sleep schedule",
                        description: "Plans timed to your natural rhythm"
                    )
                    
                    BenefitCard(
                        icon: "🔒",
                        title: "Private & Secure",
                        description: "Data processed locally by default"
                    )
                }
                .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                
                Spacer()
                
                // MARK: - Action Buttons
                VStack(spacing: 16) {
                    GlassTextPillButton("Connect Health Data", icon: "heart.fill", tint: .pink, isProminent: true) {
                        onConnect()
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button(action: onSkip) {
                        Text("Maybe Later")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                .padding(.bottom, GlassTokens.Layout.pageBottomInset)
            }
        }
    }
}

// MARK: - Benefit Card

private struct BenefitCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        GlassCard {
            HStack(spacing: 16) {
                Text(icon)
                    .font(.title)
                    .frame(width: 44)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(16)
        }
    }
}

#Preview {
    HealthPermissionView(
        onConnect: { print("Connect tapped") },
        onSkip: { print("Skip tapped") }
    )
}

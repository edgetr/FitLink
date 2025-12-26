import SwiftUI

struct GlassHelpButton: View {
    let action: () -> Void
    
    init(action: @escaping () -> Void) {
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "questionmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .sensoryFeedback(.selection, trigger: UUID())
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.mint.opacity(0.3), .teal.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 20) {
            HStack {
                Text("Need Help?")
                    .font(.headline)
                Spacer()
                GlassHelpButton {
                    print("Help tapped")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .padding()
            
            GlassHelpButton {
                print("Standalone help tapped")
            }
        }
    }
}

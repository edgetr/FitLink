import SwiftUI

struct GlassTextPillButton: View {
    let title: String
    let icon: String?
    let tintColor: Color?
    let isProminent: Bool
    let action: () -> Void
    
    init(
        _ title: String,
        icon: String? = nil,
        tint: Color? = nil,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.tintColor = tint
        self.isProminent = isProminent
        self.action = action
    }
    
    private var buttonLabel: some View {
        Label {
            Text(title)
        } icon: {
            if let icon = icon {
                Image(systemName: icon)
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            buttonLabel
                .font(.body.weight(.medium))
                .foregroundStyle(isProminent ? .white : (tintColor ?? .primary))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isProminent ? (tintColor ?? .blue) : Color.clear)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            Capsule()
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
            colors: [.cyan.opacity(0.3), .blue.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 16) {
            GlassTextPillButton("Get Started") {
                print("Get Started tapped")
            }
            
            GlassTextPillButton("New Plan", icon: "plus", tint: .blue) {
                print("New Plan tapped")
            }
            
            GlassTextPillButton("Complete", icon: "checkmark", tint: .green, isProminent: true) {
                print("Complete tapped")
            }
            
            HStack(spacing: 12) {
                GlassTextPillButton("Skip") {
                    print("Skip tapped")
                }
                
                GlassTextPillButton("Continue", icon: "arrow.right", tint: .blue, isProminent: true) {
                    print("Continue tapped")
                }
            }
        }
    }
}

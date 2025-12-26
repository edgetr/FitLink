import SwiftUI

struct GlassIconButton: View {
    let systemName: String
    let size: CGFloat
    let tintColor: Color?
    let action: () -> Void
    
    init(
        systemName: String,
        size: CGFloat = 44,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.size = size
        self.tintColor = tint
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(tintColor ?? .primary)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .fill(tintColor?.opacity(0.1) ?? Color.clear)
                        )
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
            colors: [.orange.opacity(0.3), .pink.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        HStack(spacing: 16) {
            GlassIconButton(systemName: "gear") {
                print("Settings tapped")
            }
            
            GlassIconButton(systemName: "person.fill", tint: .blue) {
                print("Profile tapped")
            }
            
            GlassIconButton(systemName: "plus", size: 56, tint: .green) {
                print("Add tapped")
            }
            
            GlassIconButton(systemName: "xmark", tint: .red) {
                print("Close tapped")
            }
        }
    }
}

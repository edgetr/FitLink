import SwiftUI
import UIKit

struct MemoryToastView: View {
    let memory: Memory
    let onDismiss: () -> Void
    
    var body: some View {
        GlassCard(tint: tintColor, isInteractive: true) {
            HStack(alignment: .center, spacing: 12) {
                Text("🧠")
                    .font(.title2)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Added to memory")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text(memory.toastMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Added to memory. \(memory.toastMessage)")
        .accessibilityHint("Double tap to dismiss")
        .accessibilityAction(named: "Dismiss") {
            onDismiss()
        }
    }
    
    private var tintColor: Color {
        memory.type.isPositive ? .green : .orange
    }
}

#Preview {
    VStack(spacing: 20) {
        MemoryToastView(
            memory: Memory(
                type: .preferredExercise,
                value: "Bench Press",
                source: .conversation
            ),
            onDismiss: {}
        )
        
        MemoryToastView(
            memory: Memory(
                type: .avoidedIngredient,
                value: "Peanuts",
                source: .manualEntry
            ),
            onDismiss: {}
        )
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}

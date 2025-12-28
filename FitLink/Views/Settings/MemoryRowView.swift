import SwiftUI

struct MemoryRowView: View {
    let memory: Memory
    let onDelete: () -> Void
    
    private var tintColor: Color {
        memory.type.isPositive ? .green : .orange
    }
    
    private var statusIcon: String {
        memory.type.isPositive ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
    
    var body: some View {
        GlassCard(tint: tintColor, isInteractive: false) {
            HStack(alignment: .top, spacing: GlassTokens.Layout.cardSpacing) {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(tintColor)
                    .frame(width: 24, height: 24)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(memory.value)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 4) {
                        Text(memory.source.displayName)
                        Text("•")
                        Text(formattedDate(memory.createdAt))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(GlassTokens.Layout.cardSpacing)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 20) {
        MemoryRowView(
            memory: Memory(
                type: .preferredExercise,
                value: "Bench Press",
                source: .completedExercise,
                createdAt: Date()
            ),
            onDelete: {}
        )
        
        MemoryRowView(
            memory: Memory(
                type: .avoidedExercise,
                value: "Burpees",
                source: .skippedExercise,
                createdAt: Date().addingTimeInterval(-86400)
            ),
            onDelete: {}
        )
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}

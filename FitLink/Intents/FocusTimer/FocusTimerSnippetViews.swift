import SwiftUI

// MARK: - Focus Timer Snippet View

struct FocusTimerSnippetView: View {
    let timeRemaining: Int
    let totalTime: Int
    let state: TimerDisplayState
    let habitName: String
    
    enum TimerDisplayState {
        case running, paused, onBreak, finished
        
        var icon: String {
            switch self {
            case .running: return "brain.head.profile"
            case .paused: return "pause.circle.fill"
            case .onBreak: return "cup.and.saucer.fill"
            case .finished: return "checkmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .running: return .cyan
            case .paused: return .orange
            case .onBreak: return .blue
            case .finished: return .green
            }
        }
        
        var label: String {
            switch self {
            case .running: return "Focusing"
            case .paused: return "Paused"
            case .onBreak: return "On Break"
            case .finished: return "Complete"
            }
        }
    }
    
    private var progress: Double {
        guard totalTime > 0 else { return 0 }
        return 1.0 - (Double(timeRemaining) / Double(totalTime))
    }
    
    private var formattedTime: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(state.color.opacity(0.2), lineWidth: 6)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(state.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: state.icon)
                    .font(.title2)
                    .foregroundStyle(state.color)
            }
            .frame(width: 56, height: 56)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(habitName)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(formattedTime)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                
                Text(state.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Empty Timer Snippet View

struct EmptyTimerSnippetView: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("No Active Timer")
                    .font(.headline)
                
                Text("Say \"Start focus timer\" to begin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Previews

#Preview("Running Timer") {
    FocusTimerSnippetView(
        timeRemaining: 1234,
        totalTime: 1500,
        state: .running,
        habitName: "Deep Work"
    )
}

#Preview("Paused Timer") {
    FocusTimerSnippetView(
        timeRemaining: 600,
        totalTime: 1500,
        state: .paused,
        habitName: "Reading"
    )
}

#Preview("Empty State") {
    EmptyTimerSnippetView()
}

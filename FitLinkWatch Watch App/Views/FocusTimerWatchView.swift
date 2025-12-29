import SwiftUI
import WatchKit

#if os(watchOS)

struct FocusTimerWatchView: View {
    
    @EnvironmentObject var sessionManager: WatchSessionManager
    @Environment(\.dismiss) private var dismiss
    
    let startingHabit: HabitSyncData?
    
    init(startingHabit: HabitSyncData? = nil) {
        self.startingHabit = startingHabit
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if sessionManager.timerState.isActive {
                    activeTimerView
                } else if let habit = startingHabit {
                    startConfirmView(habit: habit)
                } else {
                    selectHabitView
                }
            }
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func startConfirmView(habit: HabitSyncData) -> some View {
        VStack(spacing: 16) {
            Image(systemName: habit.icon)
                .font(.system(size: 40))
                .foregroundStyle(.cyan)
            
            Text(habit.name)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("\(habit.suggestedDurationMinutes) minutes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button {
                WKInterfaceDevice.current().play(.start)
                sessionManager.startTimer(for: habit)
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
        }
        .padding()
    }
    
    private var activeTimerView: some View {
        VStack(spacing: 8) {
            if let habitName = sessionManager.timerState.habitName {
                Text(habitName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: sessionManager.timerState.progress)
                    .stroke(
                        sessionManager.timerState.isOnBreak ? Color.blue : Color.cyan,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: sessionManager.timerState.progress)
                
                VStack(spacing: 2) {
                    Text(sessionManager.timerState.formattedTime)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    
                    Text(stateLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, height: 120)
            
            controlButtons
        }
        .padding()
    }
    
    private var stateLabel: String {
        if sessionManager.timerState.isOnBreak {
            return "Break"
        } else if sessionManager.timerState.isPaused {
            return "Paused"
        } else {
            return "Focus"
        }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 16) {
            Button {
                WKInterfaceDevice.current().play(.stop)
                sessionManager.stopTimer()
                dismiss()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title3)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            
            Button {
                WKInterfaceDevice.current().play(.click)
                if sessionManager.timerState.isPaused {
                    sessionManager.resumeTimer()
                } else {
                    sessionManager.pauseTimer()
                }
            } label: {
                Image(systemName: sessionManager.timerState.isPaused ? "play.fill" : "pause.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.cyan))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }
    
    private var selectHabitView: some View {
        VStack {
            if sessionManager.habits.filter({ !$0.isCompletedToday }).isEmpty {
                allDoneView
            } else {
                habitsList
            }
        }
    }
    
    private var allDoneView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            
            Text("All Done!")
                .font(.headline)
            
            Text("You've completed all habits for today")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var habitsList: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Select a habit to focus on")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ForEach(sessionManager.habits.filter { !$0.isCompletedToday }) { habit in
                    Button {
                        WKInterfaceDevice.current().play(.start)
                        sessionManager.startTimer(for: habit)
                    } label: {
                        HStack {
                            Image(systemName: habit.icon)
                                .font(.title3)
                                .foregroundStyle(.cyan)
                                .frame(width: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(habit.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                Text("\(habit.suggestedDurationMinutes) min")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "play.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.cyan)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.gray.opacity(0.15))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

#endif

import SwiftUI
import WatchKit

#if os(watchOS)

struct HabitsWatchView: View {
    
    @EnvironmentObject var sessionManager: WatchSessionManager
    @State private var loadingHabitId: String?
    @State private var showingFocusTimer = false
    @State private var selectedHabitForTimer: HabitSyncData?
    
    private var completedCount: Int {
        sessionManager.habits.filter { $0.isCompletedToday }.count
    }
    
    private var totalCount: Int {
        sessionManager.habits.count
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if sessionManager.habits.isEmpty {
                    emptyStateView
                } else {
                    habitsList
                }
            }
            .navigationTitle("Habits")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingFocusTimer) {
                if let habit = selectedHabitForTimer {
                    FocusTimerWatchView(startingHabit: habit)
                        .environmentObject(sessionManager)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 40))
                .foregroundStyle(.cyan)
            
            Text("No Habits")
                .font(.headline)
            
            Text("Add habits on your iPhone")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                sessionManager.requestSync()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                    Text("Refresh")
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
        }
        .padding()
    }
    
    private var habitsList: some View {
        ScrollView {
            VStack(spacing: 10) {
                progressHeader
                
                ForEach(sessionManager.habits) { habit in
                    HabitWatchRowView(
                        habit: habit,
                        isLoading: loadingHabitId == habit.id,
                        onToggle: { toggleCompletion(habit) },
                        onStartFocus: { startFocus(habit) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
        }
        .refreshable {
            sessionManager.requestSync()
        }
    }
    
    private var progressHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Progress")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("\(completedCount) of \(totalCount)")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                
                Circle()
                    .trim(from: 0, to: progressValue)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: progressValue)
                
                Text("\(Int(progressValue * 100))%")
                    .font(.system(.caption2, design: .rounded))
                    .fontWeight(.bold)
            }
            .frame(width: 44, height: 44)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.15))
        )
    }
    
    private var progressValue: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
    
    private var progressColor: Color {
        if progressValue >= 1.0 {
            return .green
        } else if progressValue >= 0.5 {
            return .cyan
        } else {
            return .orange
        }
    }
    
    private func toggleCompletion(_ habit: HabitSyncData) {
        loadingHabitId = habit.id
        WKInterfaceDevice.current().play(habit.isCompletedToday ? .failure : .success)
        sessionManager.toggleHabitCompletion(habit)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            loadingHabitId = nil
        }
    }
    
    private func startFocus(_ habit: HabitSyncData) {
        selectedHabitForTimer = habit
        showingFocusTimer = true
    }
}

struct HabitWatchRowView: View {
    let habit: HabitSyncData
    let isLoading: Bool
    let onToggle: () -> Void
    let onStartFocus: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Image(systemName: habit.icon)
                        .font(.title3)
                        .foregroundStyle(habit.isCompletedToday ? .green : .cyan)
                        .frame(width: 28)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .strikethrough(habit.isCompletedToday, color: .secondary)
                            .foregroundStyle(habit.isCompletedToday ? .secondary : .primary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                            Text("\(habit.currentStreak)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: habit.isCompletedToday ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(habit.isCompletedToday ? .green : .gray)
                            .symbolEffect(.bounce, value: habit.isCompletedToday)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            
            if !habit.isCompletedToday && habit.suggestedDurationMinutes > 0 {
                Button(action: onStartFocus) {
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(habit.isCompletedToday ? 0.08 : 0.15))
        )
    }
}

#endif

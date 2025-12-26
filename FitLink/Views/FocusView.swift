import SwiftUI

struct FocusView: View {
    @ObservedObject var viewModel: HabitTrackerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Spacer()
            
            if let habitId = viewModel.focusedHabitId,
               let habit = viewModel.habits.first(where: { $0.id == habitId }) {
                Text(habit.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
            } else {
                Text("Focus Session")
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            Text(viewModel.formatTime(viewModel.focusTimeRemainingSeconds))
                .font(.system(size: 70, weight: .thin, design: .monospaced))
                .monospacedDigit()
                .padding()
            
            if viewModel.isFocusOnBreak {
                Text("Break Time")
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .padding(.top, -10)
            }
            
            Spacer()
            
            HStack(spacing: 30) {
                Button {
                    viewModel.stopFocusSession()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.red.gradient)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                }
                
                Button {
                    viewModel.toggleFocusTimer()
                } label: {
                    Image(systemName: viewModel.isFocusTimerRunning ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(viewModel.isFocusTimerRunning ? Color.green.gradient : Color.orange.gradient)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                }
                
                Button {
                    viewModel.startFocusBreak()
                } label: {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.blue.gradient)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.bottom, 50)
            
            Spacer()
        }
        .onAppear {
            viewModel.resumeFocusTimerAndActivity()
        }
        .navigationTitle("Focus")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    FocusView(viewModel: HabitTrackerViewModel())
}

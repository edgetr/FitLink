import SwiftUI

struct HabitTrackerView: View {
    @ObservedObject var viewModel: HabitTrackerViewModel
    
    @State private var showAddHabitSheet = false
    @State private var showEditHabitSheet = false
    @State private var showDeleteAlert = false
    @State private var showInfoAlert = false
    @State private var navigateToFocus = false
    
    @State private var newHabitName = ""
    @State private var newHabitEndDate: Date?
    @State private var showEndDatePicker = false
    
    @State private var habitToEdit: Habit?
    @State private var editedHabitName = ""
    @State private var habitToDelete: Habit?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                LiquidGlassDateStrip(
                    selectedDate: $viewModel.selectedDate,
                    dateRange: viewModel.dateRange
                )
                .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                .padding(.top, 8)
                
                switch viewModel.viewState {
                case .loading:
                    loadingState
                case .error(let message):
                    errorState(message: message)
                case .loaded, .saving:
                    if viewModel.activeHabitsForSelectedDate.isEmpty {
                        emptyState
                    } else {
                        habitList
                    }
                }
            }
            
            if case .loaded = viewModel.viewState {
                addButton
            } else if case .saving = viewModel.viewState {
                addButton
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Habit Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showInfoAlert = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showAddHabitSheet) {
            addHabitSheet
        }
        .sheet(isPresented: $showEditHabitSheet) {
            editHabitSheet
        }
        .alert("Habit Info", isPresented: $showInfoAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Tap to toggle completion. Long press for more options like Timer, Edit, or Delete.")
        }
        .alert("Delete Habit?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let habit = habitToDelete {
                    viewModel.deleteHabit(withId: habit.id)
                }
            }
            Button("Cancel", role: .cancel) {
                habitToDelete = nil
            }
        } message: {
            if let habit = habitToDelete {
                Text("Are you sure you want to delete '\(habit.name)'? This cannot be undone.")
            } else {
                Text("This cannot be undone.")
            }
        }
        .navigationDestination(isPresented: $navigateToFocus) {
            FocusView(viewModel: viewModel)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.dashed")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No habits yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap the + button to add your first habit")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading habits...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text("Something went wrong")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Try Again") {
                Task {
                    await viewModel.loadHabitsAsync()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var habitList: some View {
        List {
            ForEach(viewModel.activeHabitsForSelectedDate) { habit in
                HabitRow(
                    habit: habit,
                    isCompleted: viewModel.isCompleted(habit: habit, on: viewModel.selectedDate),
                    isToday: Calendar.current.isDateInToday(viewModel.selectedDate),
                    onToggle: {
                        viewModel.toggleCompletion(habit: habit, on: viewModel.selectedDate)
                    }
                )
                .contextMenu {
                    if Calendar.current.isDateInToday(viewModel.selectedDate) {
                        Button {
                            habitToEdit = habit
                            editedHabitName = habit.name
                            showEditHabitSheet = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button {
                            viewModel.startFocusSession(for: habit)
                            navigateToFocus = true
                        } label: {
                            Label("Start Focus", systemImage: "timer")
                        }
                        
                        Button(role: .destructive) {
                            habitToDelete = habit
                            showDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let habit = viewModel.activeHabitsForSelectedDate[index]
                    habitToDelete = habit
                    showDeleteAlert = true
                }
            }
        }
        .listStyle(.plain)
    }
    
    private var addButton: some View {
        Button {
            newHabitName = ""
            newHabitEndDate = nil
            showEndDatePicker = false
            showAddHabitSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.blue.gradient)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, GlassTokens.Layout.pageHorizontalPadding)
        .padding(.bottom, 24)
    }
    
    private var addHabitSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Habit name", text: $newHabitName)
                }
                
                Section {
                    Toggle("Set End Date", isOn: $showEndDatePicker)
                    
                    if showEndDatePicker {
                        DatePicker("End Date", selection: Binding(
                            get: { newHabitEndDate ?? Date() },
                            set: { newHabitEndDate = $0 }
                        ), displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showAddHabitSheet = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if !newHabitName.isEmpty {
                            viewModel.addHabit(name: newHabitName, endDate: showEndDatePicker ? newHabitEndDate : nil)
                            showAddHabitSheet = false
                        }
                    }
                    .disabled(newHabitName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private var editHabitSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Habit name", text: $editedHabitName)
                }
            }
            .navigationTitle("Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showEditHabitSheet = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if let habit = habitToEdit, !editedHabitName.isEmpty {
                            viewModel.updateHabitName(id: habit.id, newName: editedHabitName)
                            showEditHabitSheet = false
                        }
                    }
                    .disabled(editedHabitName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct HabitRow: View {
    let habit: Habit
    let isCompleted: Bool
    let isToday: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: {
            if isToday {
                onToggle()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isCompleted ? .green : .secondary)
                
                Text(habit.name)
                    .font(.body)
                    .strikethrough(isCompleted)
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isToday ? 1 : 0.6)
    }
}

#Preview {
    NavigationStack {
        HabitTrackerView(viewModel: HabitTrackerViewModel())
    }
}

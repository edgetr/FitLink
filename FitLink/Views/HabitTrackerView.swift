import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HabitTrackerView: View {
    @ObservedObject var viewModel: HabitTrackerViewModel
    
    @State private var showAddHabitSheet = false
    @State private var showEditHabitSheet = false
    @State private var showDeleteAlert = false
    @State private var showInfoAlert = false
    
    @State private var habitToEdit: Habit?
    @State private var habitToDelete: Habit?
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                LiquidGlassDateStrip(
                    selectedDate: $viewModel.selectedDate,
                    dateRange: viewModel.dateRange
                )
                .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, GlassTokens.Padding.standard)
                
                switch viewModel.viewState {
                case .loading:
                    loadingState
                case .error(let message):
                    errorState(message: message)
                case .loaded, .saving:
                    if viewModel.activeHabitsForSelectedDate.isEmpty {
                        emptyState
                    } else {
                        habitScrollView
                    }
                }
            }
            
            if case .loaded = viewModel.viewState {
                addButton
            } else if case .saving = viewModel.viewState {
                addButton
            }
        }
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
            AddHabitView(viewModel: viewModel, isPresented: $showAddHabitSheet)
        }
        .sheet(isPresented: $showEditHabitSheet) {
            editHabitSheet
        }
        .alert("Habit Info", isPresented: $showInfoAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Tap the checkmark to toggle completion. Long press for more options like Timer, Edit, or Delete.")
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

    }
    
    private var emptyState: some View {
        VStack(spacing: GlassTokens.Padding.standard) {
            Spacer()
            
            GlassCard {
                VStack(spacing: GlassTokens.Padding.standard) {
                    Image(systemName: "checkmark.circle.dashed")
                        .font(.system(size: GlassTokens.IconSize.emptyState))
                        .foregroundStyle(.secondary)
                    
                    Text("No habits yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Tap the + button to add your first habit")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(GlassTokens.Padding.large)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
            
            Spacer()
        }
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
    
    private var habitScrollView: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: GlassTokens.Layout.cardSpacing(for: geometry.size.height)) {
                    ForEach(viewModel.activeHabitsForSelectedDate) { habit in
                        HabitRow(
                            habit: habit,
                            isCompleted: viewModel.isCompleted(habit: habit, on: viewModel.selectedDate),
                            isToday: Calendar.current.isDateInToday(viewModel.selectedDate),
                            isEnriching: viewModel.enrichingHabitIds.contains(habit.id),
                            onToggle: {
                                viewModel.toggleCompletion(habit: habit, on: viewModel.selectedDate)
                            },
                            onStartTimer: {
                                viewModel.startFocusSession(for: habit)
                            },
                            onEdit: {
                                habitToEdit = habit
                                showEditHabitSheet = true
                            }
                        )
                        .contextMenu {
                            if Calendar.current.isDateInToday(viewModel.selectedDate) {
                                Button(role: .destructive) {
                                    habitToDelete = habit
                                    showDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, GlassTokens.Layout.pageHorizontalPadding)
                .padding(.bottom, 100)
            }
        }
    }
    
    private var addButton: some View {
        Button {
            showAddHabitSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .contentShape(Circle())
                .glassEffect(.regular.interactive(), in: Circle())
                .animation(nil)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, GlassTokens.Layout.pageHorizontalPadding)
        .padding(.bottom, 24)
    }
    
    @ViewBuilder
    private var editHabitSheet: some View {
        if let habit = habitToEdit {
            HabitEditSheet(
                viewModel: viewModel,
                habit: habit,
                onDelete: {
                    habitToDelete = habit
                    showEditHabitSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showDeleteAlert = true
                    }
                },
                onDismiss: {
                    showEditHabitSheet = false
                    habitToEdit = nil
                }
            )
        }
    }
}

struct HabitRow: View {
    let habit: Habit
    let isCompleted: Bool
    let isToday: Bool
    let isEnriching: Bool
    let onToggle: () -> Void
    let onStartTimer: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: GlassTokens.Padding.standard) {
            Button(action: onEdit) {
                ZStack {
                    Circle()
                        .fill(habit.category.color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    if isEnriching {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: habit.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(habit.category.color)
                    }
                }
            }
            .buttonStyle(.plain)

            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .font(.headline)
                        .strikethrough(isCompleted)
                        .foregroundStyle(isCompleted ? .secondary : .primary)

                    HStack(spacing: 8) {
                        Text(habit.category.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(habit.category.color.opacity(0.1))
                            .foregroundStyle(habit.category.color)
                            .clipShape(Capsule())

                        HStack(spacing: 2) {
                            Image(systemName: habit.preferredTime.icon)
                                .font(.caption2)
                            Text(habit.preferredTime.displayName)
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)

                        if habit.isAIGenerated {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                                .foregroundStyle(.purple)
                        }

                        if habit.currentStreak > 0 {
                            HStack(spacing: 2) {
                                Text("🔥")
                                    .font(.caption2)
                                Text("\(habit.currentStreak)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if isToday && !isCompleted {
                Button(action: onStartTimer) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                if isToday {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        onToggle()
                    }
                }
            }) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundStyle(isCompleted ? .green : .secondary.opacity(0.5))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!isToday)
        }
        .padding(GlassTokens.Padding.compact)
        .contentShape(RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
        .glassEffect(isToday ? .regular.interactive() : .regular, in: RoundedRectangle(cornerRadius: GlassTokens.Radius.card, style: .continuous))
        .animation(nil)
    }
}

// MARK: - HabitEditSheet

struct HabitEditSheet: View {
    @ObservedObject var viewModel: HabitTrackerViewModel
    let habit: Habit
    let onDelete: () -> Void
    let onDismiss: () -> Void
    
    @State private var editedName: String = ""
    @State private var editedIcon: String = ""
    @State private var editedCategory: HabitCategory = .productivity
    @State private var editedDuration: Int = 25
    @State private var editedTime: HabitTimeOfDay = .anytime
    @State private var editedNotes: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: GlassTokens.Padding.section) {
                    IconPickerSection(selectedIcon: $editedIcon, category: editedCategory)
                    
                    nameSection
                    
                    categorySection
                    
                    DurationPickerSection(duration: $editedDuration)
                    
                    timeOfDaySection
                    
                    notesSection
                    
                    deleteSection
                }
                .padding(GlassTokens.Layout.pageHorizontalPadding)
                .padding(.bottom, 40)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveHabit() }
                        .disabled(editedName.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear { loadHabitData() }
    }
    
    @Namespace private var namespace
    
    private func loadHabitData() {
        editedName = habit.name
        editedIcon = habit.icon
        editedCategory = habit.category
        editedDuration = habit.suggestedDurationMinutes
        editedTime = habit.preferredTime
        editedNotes = habit.notes ?? ""
    }
    
    private func saveHabit() {
        viewModel.updateHabit(
            id: habit.id,
            name: editedName,
            icon: editedIcon,
            category: editedCategory,
            duration: editedDuration,
            preferredTime: editedTime,
            notes: editedNotes.isEmpty ? nil : editedNotes
        )
        onDismiss()
    }
    
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: GlassTokens.Padding.small) {
            Text("Habit Name")
                .font(.headline)
            
            TextField("Enter habit name", text: $editedName)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: GlassTokens.Padding.small) {
            Text("Category")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                ForEach(HabitCategory.allCases, id: \.self) { cat in
                    Button {
                        withAnimation {
                            editedCategory = cat
                            if editedIcon == editedCategory.defaultIcon || editedIcon == habit.category.defaultIcon {
                                editedIcon = cat.defaultIcon
                            }
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: cat.defaultIcon)
                                .font(.title3)
                                .foregroundStyle(cat.color)
                            Text(cat.displayName)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(editedCategory == cat ? cat.color.opacity(0.15) : Color(UIColor.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(editedCategory == cat ? cat.color : Color.clear, lineWidth: 1)
                        )
                        .foregroundStyle(editedCategory == cat ? cat.color : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var timeOfDaySection: some View {
        VStack(alignment: .leading, spacing: GlassTokens.Padding.small) {
            Text("Preferred Time")
                .font(.headline)
            
            LiquidGlassSegmentedPicker(
                selection: $editedTime,
                options: HabitTimeOfDay.allCases.map { ($0, $0.displayName) },
                namespace: namespace
            )
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: GlassTokens.Padding.small) {
            Text("Notes (Optional)")
                .font(.headline)
            
            TextField("Add notes...", text: $editedNotes, axis: .vertical)
                .lineLimit(3...6)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var deleteSection: some View {
        Button(role: .destructive, action: onDelete) {
            HStack {
                Image(systemName: "trash")
                Text("Delete Habit")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.top, GlassTokens.Padding.standard)
    }
}

// MARK: - IconPickerSection

struct IconPickerSection: View {
    @Binding var selectedIcon: String
    let category: HabitCategory
    
    private let iconsByCategory: [HabitCategory: [String]] = [
        .health: ["heart.fill", "drop.fill", "pills.fill", "cross.case.fill", "bed.double.fill", "lungs.fill", "stethoscope", "waveform.path.ecg"],
        .fitness: ["figure.run", "dumbbell.fill", "figure.walk", "sportscourt.fill", "bicycle", "figure.swimming", "figure.yoga", "figure.hiking"],
        .productivity: ["checklist", "doc.text.fill", "laptopcomputer", "calendar", "clock.fill", "target", "flag.fill", "list.bullet.clipboard"],
        .learning: ["book.fill", "graduationcap.fill", "brain.head.profile", "lightbulb.fill", "pencil", "text.book.closed.fill", "globe", "character.book.closed.fill"],
        .mindfulness: ["brain", "leaf.fill", "moon.stars.fill", "wind", "sparkles", "heart.circle.fill", "sun.max.fill", "cloud.fill"],
        .social: ["person.2.fill", "message.fill", "phone.fill", "video.fill", "hand.wave.fill", "figure.2.arms.open", "bubble.left.and.bubble.right.fill", "person.3.fill"],
        .creativity: ["paintbrush.fill", "music.note", "camera.fill", "guitars.fill", "theatermasks.fill", "paintpalette.fill", "pencil.and.outline", "mic.fill"],
        .finance: ["dollarsign.circle.fill", "chart.line.uptrend.xyaxis", "creditcard.fill", "banknote.fill", "wallet.pass.fill", "chart.pie.fill", "building.columns.fill", "percent"]
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: GlassTokens.Padding.small) {
            Text("Icon")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                ForEach(iconsByCategory[category] ?? [], id: \.self) { icon in
                    Button {
                        selectedIcon = icon
                    } label: {
                        Image(systemName: icon)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(selectedIcon == icon ? category.color : Color.gray.opacity(0.2))
                            )
                            .foregroundStyle(selectedIcon == icon ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - DurationPickerSection

struct DurationPickerSection: View {
    @Binding var duration: Int
    
    private let presets = [5, 10, 15, 25, 30, 45, 60, 90]
    
    var body: some View {
        VStack(alignment: .leading, spacing: GlassTokens.Padding.small) {
            HStack {
                Text("Focus Duration")
                    .font(.headline)
                Spacer()
                Text("\(duration) min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            withAnimation { duration = preset }
                        } label: {
                            Text("\(preset)m")
                                .font(.subheadline)
                                .fontWeight(duration == preset ? .semibold : .regular)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(duration == preset ? Color.blue : Color(UIColor.secondarySystemBackground))
                                )
                                .foregroundStyle(duration == preset ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Stepper("\(duration) minutes", value: $duration, in: 1...180, step: 5)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - AddHabitView

struct AddHabitView: View {
    @ObservedObject var viewModel: HabitTrackerViewModel
    @Binding var isPresented: Bool
    
    @State private var habitName = ""
    @State private var category: HabitCategory = .productivity
    @State private var duration: Int = 25
    @State private var timeOfDay: HabitTimeOfDay = .anytime
    @State private var endDate: Date?
    @State private var showEndDatePicker = false
    @State private var selectedDate = Date()
    @FocusState private var isNameFocused: Bool
    
    let durationOptions = [10, 15, 25, 30, 45, 60]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: GlassTokens.Padding.section) {
                    
                    VStack(alignment: .leading, spacing: GlassTokens.Padding.small) {
                        Text("What habit do you want to build?")
                            .font(.headline)
                            .padding(.horizontal, 4)
                        
                        TextField("e.g. Read 10 pages, Drink water", text: $habitName)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($isNameFocused)
                            .onChange(of: habitName) { _, newValue in
                                viewModel.requestSuggestion(for: newValue)
                            }
                            .onChange(of: viewModel.aiSuggestionState) { _, newState in
                                if case .ready(let suggestion) = newState {
                                    withAnimation {
                                        if let cat = HabitCategory(rawValue: suggestion.category.lowercased()) {
                                            category = cat
                                        }
                                        duration = suggestion.suggestedDurationMinutes
                                        if let time = HabitTimeOfDay(rawValue: suggestion.preferredTimeOfDay.lowercased()) {
                                            timeOfDay = time
                                        }
                                    }
                                }
                            }
                        
                        switch viewModel.aiSuggestionState {
                        case .loading:
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("AI is thinking...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, 8)
                            .transition(.opacity)
                            
                        case .ready(let suggestion):
                            GlassCard(tint: .purple) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "sparkles")
                                            .foregroundStyle(.purple)
                                        Text("AI Enhanced")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.purple)
                                        Spacer()
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .font(.caption)
                                    }
                                    
                                    HStack(alignment: .top, spacing: 12) {
                                        let suggestedCategory = HabitCategory(rawValue: suggestion.category.lowercased()) ?? .productivity
                                        Image(systemName: suggestion.icon)
                                            .font(.title2)
                                            .foregroundStyle(suggestedCategory.color)
                                            .frame(width: 40, height: 40)
                                            .background(suggestedCategory.color.opacity(0.15))
                                            .clipShape(Circle())
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            if let tip = suggestion.motivationalTip {
                                                Text(tip)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .italic()
                                            }
                                            
                                            HStack(spacing: 8) {
                                                Text(suggestion.category.capitalized)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 2)
                                                    .background(suggestedCategory.color.opacity(0.15))
                                                    .foregroundStyle(suggestedCategory.color)
                                                    .clipShape(Capsule())
                                                
                                                Label("\(suggestion.suggestedDurationMinutes)m", systemImage: "clock")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.top, 4)
                                        }
                                    }
                                }
                                .padding()
                            }
                            .transition(.scale.combined(with: .opacity))
                            
                        default:
                            EmptyView()
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: GlassTokens.Padding.section) {
                        
                        VStack(alignment: .leading, spacing: GlassTokens.Padding.small) {
                            Text("Category")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                                ForEach(HabitCategory.allCases, id: \.self) { cat in
                                    Button {
                                        withAnimation { category = cat }
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: cat.defaultIcon)
                                                .font(.title3)
                                            Text(cat.displayName)
                                                .font(.caption2)
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(category == cat ? Color.blue.opacity(0.15) : Color(UIColor.secondarySystemBackground))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(category == cat ? Color.blue : Color.clear, lineWidth: 1)
                                        )
                                        .foregroundStyle(category == cat ? .blue : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: GlassTokens.Padding.small) {
                            HStack {
                                Text("Duration")
                                    .font(.headline)
                                Text("\(duration) min")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(durationOptions, id: \.self) { min in
                                        Button {
                                            withAnimation { duration = min }
                                        } label: {
                                            Text("\(min)m")
                                                .font(.subheadline)
                                                .fontWeight(duration == min ? .semibold : .regular)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(
                                                    Capsule()
                                                        .fill(duration == min ? Color.blue : Color(UIColor.secondarySystemBackground))
                                                )
                                                .foregroundStyle(duration == min ? .white : .primary)
                                        }
                                    }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: GlassTokens.Padding.small) {
                            Text("Preferred Time")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            LiquidGlassSegmentedPicker(
                                selection: $timeOfDay,
                                options: HabitTimeOfDay.allCases.map { ($0, $0.displayName) },
                                namespace: namespace
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: GlassTokens.Padding.small) {
                            Toggle("Set Goal Date", isOn: $showEndDatePicker)
                                .font(.headline)
                                .tint(.blue)
                            
                            if showEndDatePicker {
                                DatePicker("End Date", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                .padding(GlassTokens.Layout.pageHorizontalPadding)
                .padding(.bottom, 40)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.clearSuggestion()
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveHabit()
                    }
                    .disabled(habitName.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            isNameFocused = true
        }
    }
    
    @Namespace private var namespace
    
    private func applySuggestion(_ suggestion: HabitSuggestion) {
        habitName = suggestion.title
        if let cat = HabitCategory(rawValue: suggestion.category.lowercased()) {
            category = cat
        }
        duration = suggestion.suggestedDurationMinutes
        if let time = HabitTimeOfDay(rawValue: suggestion.preferredTimeOfDay.lowercased()) {
            timeOfDay = time
        }
        
        viewModel.applyCurrentSuggestion(endDate: showEndDatePicker ? selectedDate : nil)
        isPresented = false
    }
    
    private func saveHabit() {
        if case .ready(let suggestion) = viewModel.aiSuggestionState {
            let suggestedCategory = HabitCategory(rawValue: suggestion.category.lowercased()) ?? category
            let suggestedTime = HabitTimeOfDay(rawValue: suggestion.preferredTimeOfDay.lowercased()) ?? timeOfDay
            
            viewModel.addHabit(
                name: habitName,
                icon: suggestion.icon,
                category: suggestedCategory,
                duration: suggestion.suggestedDurationMinutes,
                preferredTime: suggestedTime,
                endDate: showEndDatePicker ? selectedDate : nil,
                notes: suggestion.motivationalTip
            )
        } else {
            viewModel.addHabit(
                name: habitName,
                icon: category.defaultIcon,
                category: category,
                duration: duration,
                preferredTime: timeOfDay,
                endDate: showEndDatePicker ? selectedDate : nil,
                notes: nil
            )
        }
        viewModel.clearSuggestion()
        isPresented = false
    }
}

#Preview {
    NavigationStack {
        HabitTrackerView(viewModel: HabitTrackerViewModel())
    }
}

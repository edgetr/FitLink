import SwiftUI

struct DietPlannerView: View {
    @StateObject private var viewModel = DietPlannerViewModel()
    @EnvironmentObject var sessionManager: SessionManager
    
    @State private var isShowingPlanList = false
    @State private var selectedRecipeParams: RecipeDetailParams?
    @State private var isShowingFilledDataDetails = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                contentView
            }
            .navigationTitle("AI Diet Planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $isShowingPlanList) {
                PlanListPopupContent(viewModel: viewModel)
            }
            .sheet(item: $selectedRecipeParams) { params in
                RecipeDetailSheet(recipe: params.recipe, nutrition: params.nutrition)
            }
            .sheet(isPresented: $viewModel.isShowingShareSheet) {
                ShareSheet(items: viewModel.shareItems)
            }
            .sheet(isPresented: $isShowingFilledDataDetails) {
                if let plan = viewModel.currentDietPlan {
                    FilledDataDetailsView(details: plan.filledDataDetails)
                }
            }
            .onAppear {
                if let userId = sessionManager.currentUserID {
                    viewModel.userId = userId
                    Task {
                        await viewModel.checkPendingGenerations()
                    }
                }
            }
            .onChange(of: viewModel.currentDietPlan?.hasFilledData) { hasFilledData in
                if hasFilledData == true && viewModel.currentDietPlan?.filledDataDetails.isEmpty == false {
                    isShowingFilledDataDetails = true
                }
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.viewState {
        case .loadingPlans:
            DietPlanLoadingView(message: "Loading your plans...")
        case .fetchingClarifications:
            DietPlanLoadingView(message: "Analyzing your preferences...")
        case .conversing, .readyToGenerate:
            ChatConversationView(
                messages: viewModel.chatMessages,
                isLoading: viewModel.isProcessingMessage,
                isReadyToGenerate: viewModel.isReadyToGenerate,
                readySummary: viewModel.readySummary,
                onSendMessage: { text in
                    Task {
                        await viewModel.sendMessage(text)
                    }
                },
                onGeneratePlan: {
                    Task {
                        await viewModel.startPlanGeneration()
                    }
                },
                onMoreQuestions: {
                    Task {
                        await viewModel.requestMoreQuestions()
                    }
                }
            )
        case .generating:
            DietPlanGeneratingView(
                progress: viewModel.generationProgress,
                canCloseApp: true
            )
        case .generationFailed:
            DietPlanErrorView(viewModel: viewModel)
        case .awaitingClarifications:
            ClarifyingQuestionsView(viewModel: viewModel)
        case .showingPlan:
            if let plan = viewModel.currentDietPlan {
                DietPlanContentView(
                    viewModel: viewModel,
                    plan: plan,
                    onSelectRecipe: { recipe, nutrition in
                        selectedRecipeParams = RecipeDetailParams(recipe: recipe, nutrition: nutrition)
                    }
                )
            } else {
                DietPlanInputView(viewModel: viewModel)
            }
        case .idle:
            DietPlanInputView(viewModel: viewModel)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                isShowingPlanList = true
            } label: {
                Image(systemName: "list.bullet")
            }
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            HStack {
                if viewModel.currentDietPlan != nil {
                    Button {
                        Task {
                           _ = await viewModel.addMealsToCalendar()
                        }
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                    }
                    
                    Button {
                        viewModel.generateShareContent()
                        viewModel.isShowingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                
                if viewModel.viewState == .conversing || viewModel.viewState == .readyToGenerate {
                    Button("Cancel") {
                        viewModel.startOver()
                    }
                    .foregroundStyle(.red)
                } else {
                    GlassTextPillButton("New Plan", icon: "plus") {
                        viewModel.resetPlan()
                    }
                }
            }
        }
    }
}

private struct RecipeDetailParams: Identifiable {
    let id = UUID()
    let recipe: Recipe
    let nutrition: NutritionInfo
}

private struct DietPlanLoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

private struct DietPlanGeneratingView: View {
    let progress: Double
    let canCloseApp: Bool
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Creating your perfect meal plan...")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                
                if progress > 0 {
                    ProgressView(value: progress)
                        .tint(.green)
                        .padding(.horizontal, 40)
                    
                    Text("\(Int(progress * 100))% complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if canCloseApp {
                GlassCard(tint: .blue.opacity(0.1)) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("You can close the app")
                                .font(.headline)
                            Text("We'll send you a notification when your plan is ready!")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

private struct DietPlanErrorView: View {
    @ObservedObject var viewModel: DietPlannerViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(.top, 40)
                
                Text("Generation Failed")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Try refining your request:")
                            .font(.headline)
                        
                        Text("• Be more specific about calories (e.g., '2000 calories')")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("• Mention specific cuisines or ingredients")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("• List any allergies explicitly")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                VStack(spacing: 16) {
                    TextField("Update preferences...", text: $viewModel.preferences, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                        .padding(.horizontal)
                    
                    GlassTextPillButton("Try Again", icon: "arrow.clockwise", isProminent: true) {
                        Task {
                            await viewModel.generateDietPlan()
                        }
                    }
                    
                    Button("Start Over") {
                        viewModel.resetPlan()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
}

private struct DietPlanInputView: View {
    @ObservedObject var viewModel: DietPlannerViewModel
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.green, .teal],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white)
                            )
                            .shadow(color: .green.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        VStack(spacing: 4) {
                            Text("AI Diet Planner")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Tell me about your dietary needs")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 40)
                    
                    if !viewModel.hasSeenOnboardingTip {
                        GlassCard(tint: .green.opacity(0.1), isInteractive: true) {
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: "message.fill")
                                    .font(.title)
                                    .foregroundStyle(.green)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Let's Chat!")
                                        .font(.headline)
                                    Text("I'll ask you a few questions to understand your needs, then create a personalized 7-day meal plan just for you.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Button {
                                    withAnimation {
                                        viewModel.markOnboardingSeen()
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Try these examples:")
                            .font(.headline)
                            .padding(.horizontal, 4)
                        
                        FlowLayout(spacing: 8) {
                            SuggestionChip(text: "I want to eat healthier", viewModel: viewModel)
                            SuggestionChip(text: "High protein for muscle gain", viewModel: viewModel)
                            SuggestionChip(text: "Vegetarian, 1800 calories", viewModel: viewModel)
                            SuggestionChip(text: "Quick meals for busy schedule", viewModel: viewModel)
                            SuggestionChip(text: "Mediterranean diet", viewModel: viewModel)
                        }
                    }
                    
                    Spacer().frame(height: 100)
                }
                .padding()
            }
            .onTapGesture {
                isInputFocused = false
            }
            
            ChatInputBar(
                text: $viewModel.preferences,
                isLoading: false,
                placeholder: "Describe your ideal diet...",
                accentColor: .green,
                onSend: {
                    isInputFocused = false
                    Task {
                        await viewModel.startConversation(initialPrompt: viewModel.preferences)
                    }
                }
            )
            .focused($isInputFocused)
        }
    }
}

private struct SuggestionChip: View {
    let text: String
    @ObservedObject var viewModel: DietPlannerViewModel
    
    var body: some View {
        Button {
            viewModel.preferences = text
        } label: {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.secondary.opacity(0.3))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return rows.reduce(CGSize.zero) { size, row in
            CGSize(width: max(size.width, row.width), height: size.height + row.height + spacing)
        }
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                item.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += item.dimensions(in: .unspecified).width + spacing
            }
            y += row.height + spacing
        }
    }
    
    struct Row {
        var items: [LayoutSubview]
        var width: CGFloat
        var height: CGFloat
    }
    
    func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow: [LayoutSubview] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width + spacing > maxWidth {
                rows.append(Row(items: currentRow, width: currentWidth, height: currentHeight))
                currentRow = []
                currentWidth = 0
                currentHeight = 0
            }
            currentRow.append(subview)
            currentWidth += size.width + spacing
            currentHeight = max(currentHeight, size.height)
        }
        if !currentRow.isEmpty {
            rows.append(Row(items: currentRow, width: currentWidth, height: currentHeight))
        }
        return rows
    }
}

private struct ClarifyingQuestionsView: View {
    @ObservedObject var viewModel: DietPlannerViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Just a few details...")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("I need a bit more info to make your plan perfect.")
                    .foregroundStyle(.secondary)
                
                ForEach(viewModel.pendingClarificationQuestions) { question in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(question.text)
                            .font(.headline)
                        
                        if let hint = question.hint {
                            Text(hint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        switch question.type {
                        case .singleLine:
                            TextField("Answer...", text: binding(for: question.id))
                                .textFieldStyle(.roundedBorder)
                        case .multiLine:
                            TextField("Answer...", text: binding(for: question.id), axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3)
                        case .choice:
                            if let options = question.options {
                                Picker("Select", selection: binding(for: question.id)) {
                                    Text("Select...").tag("")
                                    ForEach(options, id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                            } else {
                                TextField("Answer...", text: binding(for: question.id))
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
                
                HStack(spacing: 16) {
                    Button("Start Over") {
                        viewModel.startOver()
                    }
                    .foregroundStyle(.red)
                    
                    Button("Skip") {
                        viewModel.skipClarifications()
                    }
                    .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    GlassTextPillButton("Create Plan", icon: "checkmark", isProminent: true) {
                        Task {
                            await viewModel.submitClarificationAnswers()
                        }
                    }
                }
                .padding(.top)
            }
            .padding()
        }
    }
    
    private func binding(for id: String) -> Binding<String> {
        Binding(
            get: { viewModel.clarificationAnswers[id] ?? "" },
            set: { viewModel.clarificationAnswers[id] = $0 }
        )
    }
}

private struct DietPlanContentView: View {
    @ObservedObject var viewModel: DietPlannerViewModel
    let plan: DietPlan
    let onSelectRecipe: (Recipe, NutritionInfo) -> Void
    
    var selectedDateBinding: Binding<Date> {
        Binding(
            get: {
                if viewModel.selectedDayIndex < plan.dailyPlans.count {
                    return plan.dailyPlans[viewModel.selectedDayIndex].actualDate ?? Date()
                }
                return Date()
            },
            set: { newDate in
                if let index = plan.dailyPlans.firstIndex(where: { Calendar.current.isDate($0.actualDate ?? Date(), inSameDayAs: newDate) }) {
                    viewModel.selectedDayIndex = index
                }
            }
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            LiquidGlassDateStrip(
                selectedDate: selectedDateBinding,
                dateRange: viewModel.getDietPlanDates(for: plan)
            )
            .padding(.top)
            .background(Color(UIColor.systemGroupedBackground))
            
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.selectedDayIndex < plan.dailyPlans.count {
                        let dailyPlan = plan.dailyPlans[viewModel.selectedDayIndex]
                        
                        GlassCard {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Daily Goals")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                    
                                    HStack(alignment: .lastTextBaseline) {
                                        Text("\(dailyPlan.totalCalories)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                        Text("kcal")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding()
                        }
                        
                        LazyVStack(spacing: 12) {
                            ForEach(dailyPlan.sortedMeals) { meal in
                                MealRowView(meal: meal, onToggle: {
                                    Task {
                                        await viewModel.toggleMealDone(mealId: meal.id)
                                    }
                                })
                                .onTapGesture {
                                    onSelectRecipe(meal.recipe, meal.nutrition)
                                }
                            }
                        }
                    }
                }
                .padding()
                .padding(.bottom, 80)
            }
        }
    }
}

private struct MealRowView: View {
    let meal: Meal
    let onToggle: () -> Void
    
    var body: some View {
        GlassCard(tint: meal.isDone ? .green.opacity(0.1) : nil, isInteractive: true) {
            HStack(spacing: 16) {
                Button(action: onToggle) {
                    Image(systemName: meal.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(meal.isDone ? .green : .secondary)
                }
                .buttonStyle(.plain)
                
                Text(meal.type.icon)
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.5))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    Text(meal.recipe.name)
                        .font(.headline)
                        .strikethrough(meal.isDone)
                        .foregroundStyle(meal.isDone ? .secondary : .primary)
                    
                    Text("\(meal.nutrition.calories) kcal • \(meal.recipe.prepTime) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .padding()
        }
    }
}

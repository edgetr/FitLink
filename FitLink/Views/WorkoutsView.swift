import SwiftUI

struct WorkoutsView: View {
    @StateObject private var viewModel = WorkoutsViewModel()
    @EnvironmentObject var sessionManager: SessionManager
    
    // UI State for viewing plans
    @State private var viewingPlanType: WorkoutPlanType = .home
    @State private var isShowingShareSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                // Main Content Switching
                contentView
                    .animation(.smooth, value: viewModel.flowState)
                    .animation(.smooth, value: viewModel.hasActivePlans)
            }
            .navigationTitle("AI Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Toolbar is handled inside WorkoutsResultsView for that state
                // But if we need global toolbar items, we can add them here
            }
            .sheet(isPresented: $isShowingShareSheet) {
                if let firstItem = viewModel.shareItems.first as? String {
                     ShareSheet(items: [firstItem])
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
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoadingPlans {
            WorkoutLoadingView(message: "Loading your workout plans...")
        } else if viewModel.isGenerating {
            WorkoutGenerationView(viewModel: viewModel, canCloseApp: true)
        } else if case .failed(let error) = viewModel.flowState {
            WorkoutErrorView(error: error, viewModel: viewModel)
        } else if viewModel.flowState == .conversing || viewModel.flowState == .readyToGenerate {
            WorkoutChatView(viewModel: viewModel)
        } else if viewModel.hasActivePlans {
            WorkoutsResultsView(viewModel: viewModel)
        } else {
            WorkoutInputView(viewModel: viewModel)
        }
    }
}

private struct WorkoutChatView: View {
    @ObservedObject var viewModel: WorkoutsViewModel
    
    var body: some View {
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
    }
}

// MARK: - Input View (Chat Interface)

private struct WorkoutInputView: View {
    @ObservedObject var viewModel: WorkoutsViewModel
    @FocusState private var isInputFocused: Bool
    
    // Local state for plan selection if VM's is nil
    @State private var selectedPlanType: PlanSelection = .both
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.primary)
                            .frame(width: 80, height: 80)
                            .glassEffect(.regular, in: Circle())
                        
                        VStack(spacing: 4) {
                            Text("AI Workout Planner")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Design your perfect routine")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 40)
                    
                    // Onboarding Tip
                    if !viewModel.hasSeenWorkoutOnboarding {
                        GlassCard(isInteractive: true) {
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.title)
                                    .foregroundStyle(.primary)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Personalized Training")
                                        .font(.headline)
                                    Text("Tell me your goals, available equipment, and schedule. I'll build a complete weekly plan for home, gym, or both.")
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
                    
                    // Plan Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Where do you train?")
                            .font(.headline)
                            .padding(.horizontal, 4)
                        
                        LiquidGlassSegmentedPicker(
                            selection: $selectedPlanType,
                            options: PlanSelection.allCases.map { ($0, $0.displayName) },
                            namespace: namespace
                        )
                        .onChange(of: selectedPlanType) { _, newValue in
                            viewModel.planSelection = newValue
                        }
                    }
                    
                    // Example Prompts
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Try these examples:")
                            .font(.headline)
                            .padding(.horizontal, 4)
                        
                        FlowLayout(spacing: 8) {
                            PromptChip(text: "3-day full body for beginners", action: fillPrompt)
                            PromptChip(text: "5-day push-pull-legs split", action: fillPrompt)
                            PromptChip(text: "Home workout, no equipment", action: fillPrompt)
                            PromptChip(text: "Upper body strength focus", action: fillPrompt)
                            PromptChip(text: "HIIT cardio & core", action: fillPrompt)
                        }
                    }
                    
                    // Spacer for bottom bar
                    Spacer().frame(height: 80)
                }
                .padding()
            }
            .onTapGesture {
                isInputFocused = false
            }
            
            // Chat Input Bar
            LiquidGlassChatBar(
                text: $viewModel.preferences,
                isLoading: viewModel.flowState.isLoading,
                onSend: {
                    viewModel.planSelection = selectedPlanType
                    isInputFocused = false
                    Task {
                        await viewModel.startConversation(initialPrompt: viewModel.preferences)
                    }
                },
                onCancel: {
                }
            )
            .focused($isInputFocused)
        }
        .onAppear {
            if let selection = viewModel.planSelection {
                selectedPlanType = selection
            } else {
                viewModel.planSelection = selectedPlanType
            }
        }
    }
    
    @Namespace private var namespace
    
    private func fillPrompt(_ text: String) {
        viewModel.preferences = text
        isInputFocused = true
    }
}

private struct LiquidGlassChatBar: View {
    @Binding var text: String
    var isLoading: Bool
    var onSend: () -> Void
    var onCancel: (() -> Void)?
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0) // Transparent but can act as separator if needed
            
            HStack(spacing: 12) {
                // Text Field
                TextField("Describe your ideal workout...", text: $text)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .focused($isFocused)
                    .disabled(isLoading)
                
                // Send/Loading Button
                Button(action: {
                    if isLoading {
                        onCancel?()
                    } else {
                        onSend()
                        isFocused = false
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(.regularMaterial)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        
                        if isLoading {
                            ProgressView()
                                .tint(.primary)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading)
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(
                .rect(
                    topLeadingRadius: 20,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 20
                )
            )
            .shadow(color: .black.opacity(0.05), radius: 5, y: -2)
        }
    }
}

private struct PromptChip: View {
    let text: String
    let action: (String) -> Void
    
    var body: some View {
        Button {
            action(text)
        } label: {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.secondary.opacity(0.2))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Generation Loading View

private struct WorkoutGenerationView: View {
    @ObservedObject var viewModel: WorkoutsViewModel
    var canCloseApp: Bool = false
    
    var body: some View {
        VStack(spacing: 32) {
            Text("Designing Your Plan")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 24) {
                if viewModel.isGeneratingHome {
                    GenerationProgressRow(
                        title: "Home Workout Plan",
                        icon: "house.fill",
                        progress: viewModel.homeProgress,
                        color: .primary
                    )
                }
                
                if viewModel.isGeneratingGym {
                    GenerationProgressRow(
                        title: "Gym Workout Plan",
                        icon: "dumbbell.fill",
                        progress: viewModel.gymProgress,
                        color: .primary
                    )
                }
            }
            .padding(.horizontal)
            
            Text("This may take up to a minute...")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if canCloseApp {
                GlassCard {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .font(.title2)
                            .foregroundStyle(.primary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("You can close the app")
                                .font(.headline)
                            Text("We'll notify you when your workout plan is ready!")
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
        .padding()
    }
}

private struct GenerationProgressRow: View {
    let title: String
    let icon: String
    let progress: Double
    let color: Color
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.headline)
                }
                
                ProgressView(value: progress, total: 1.0)
                    .tint(color)
                
                HStack {
                    Text(progressDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .bold()
                }
            }
            .padding()
        }
    }
    
    var progressDescription: String {
        if progress < 0.3 { return "Analyzing constraints..." }
        else if progress < 0.6 { return "Selecting exercises..." }
        else if progress < 0.9 { return "Balancing volume..." }
        else { return "Finalizing details..." }
    }
}

// MARK: - Generic Loading & Error Views

private struct WorkoutLoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            Text(message)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WorkoutErrorView: View {
    let error: String
    @ObservedObject var viewModel: WorkoutsViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            
            Text("Something went wrong")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(error)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Button("Try Again") {
                viewModel.resetPlans()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Helpers

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

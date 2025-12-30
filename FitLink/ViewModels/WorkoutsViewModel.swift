import SwiftUI
import Combine

@MainActor
class WorkoutsViewModel: ObservableObject {
    
    @Published var preferences: String = ""
    
    @Published var homePlan: WeeklyWorkoutPlan?
    @Published var gymPlan: WeeklyWorkoutPlan?
    @Published var homePlanDocument: WorkoutPlanDocument?
    @Published var gymPlanDocument: WorkoutPlanDocument?
    
    @Published var isGeneratingHome = false
    @Published var isGeneratingGym = false
    @Published var homeProgress: Double = 0.0
    @Published var gymProgress: Double = 0.0
    
    @Published var errorMessage: String?
    @Published var showPreviewModal = false
    @Published var hasSeenWorkoutOnboarding: Bool
    
    @Published var flowState: WizardFlowState = .idle
    @Published var planSelection: PlanSelection?
    
    @Published var selectedDayIndex: Int = 0
    @Published var isLoadingPlans = false
    
    @Published var shareItems: [Any] = []
    @Published var isShowingShareSheet = false
    
    @Published var chatMessages: [ChatMessage] = []
    @Published var isProcessingMessage: Bool = false
    @Published var currentGenerationId: String?
    @Published var readySummary: String?
    
    var isConversing: Bool { flowState == .conversing }
    var isReadyToGenerate: Bool { flowState == .readyToGenerate }
    var canSendMessage: Bool { flowState == .conversing && !isProcessingMessage }
    var messageCount: Int { chatMessages.filter { $0.role == .user }.count }
    var isAtMaxMessages: Bool { messageCount >= PendingGeneration.maxMessages }
    
    private let geminiService: GeminiAIService
    private let planGenerationService = PlanGenerationService.shared
    private let workoutPlanService = WorkoutPlanService.shared
    private let contextProvider = UserContextProvider.shared
    private var cancellables = Set<AnyCancellable>()
    private let maxRetryAttempts = 3
    
    /// Stored observer token for proper cleanup - block-based observers MUST be stored and explicitly removed
    private var notificationObserver: NSObjectProtocol?
    
    var userId: String? {
        didSet {
            if userId != nil {
                Task {
                    await loadAllPlansForUser()
                }
            }
        }
    }
    
    var isGenerating: Bool {
        isGeneratingHome || isGeneratingGym
    }
    
    var overallProgress: Double {
        if isGeneratingHome && isGeneratingGym {
            return (homeProgress + gymProgress) / 2
        } else if isGeneratingHome {
            return homeProgress
        } else if isGeneratingGym {
            return gymProgress
        }
        return 0
    }
    
    var hasActivePlans: Bool {
        homePlan != nil || gymPlan != nil
    }
    
    // MARK: - UserDefaults Keys
    private enum PersistenceKeys {
        static let preferences = "workout_planner_preferences"
        static let planSelection = "workout_planner_plan_selection"
        static let chatMessages = "workout_planner_chat_messages"
        static let generationId = "workout_planner_generation_id"
        static let readySummary = "workout_planner_ready_summary"
        static let isReady = "workout_planner_is_ready"
        static let isGenerating = "workout_planner_is_generating"
    }
    
    init() {
        self.geminiService = GeminiAIService()
        self.hasSeenWorkoutOnboarding = UserDefaults.standard.bool(forKey: "workout_planner_onboarding_seen")
        
        restoreConversationState()
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .planGenerationCompleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleGenerationCompletedNotification(notification)
            }
        }
    }
    
    private func handleGenerationCompletedNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let planTypeRaw = userInfo["planType"] as? String,
              let planType = GenerationPlanType(rawValue: planTypeRaw) else {
            return
        }
        
        guard planType == .workoutHome || planType == .workoutGym else { return }
        
        guard let resultPlanId = userInfo["resultPlanId"] as? String,
              !resultPlanId.isEmpty else {
            return
        }
        
        Task { @MainActor in
            do {
                if let doc = try await workoutPlanService.loadPlan(byId: resultPlanId) {
                    switch doc.planType {
                    case .home:
                        homePlanDocument = doc
                        homePlan = doc.plan
                    case .gym:
                        gymPlanDocument = doc
                        gymPlan = doc.plan
                    }
                    flowState = .planReady
                    clearConversationState()
                }
            } catch {
                log("Error loading completed plan: \(error)")
            }
        }
    }
    
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func loadAllPlansForUser() async {
        guard let userId = userId else { return }
        
        isLoadingPlans = true
        
        do {
            let archivedCount = try await workoutPlanService.archiveOldPlans(userId: userId)
            if archivedCount > 0 {
                log("Archived \(archivedCount) old workout plan(s)")
            }
            
            if let homeDoc = try await workoutPlanService.loadLatestPlan(for: .home, userId: userId) {
                homePlanDocument = homeDoc
                homePlan = homeDoc.plan
            }
            
            if let gymDoc = try await workoutPlanService.loadLatestPlan(for: .gym, userId: userId) {
                gymPlanDocument = gymDoc
                gymPlan = gymDoc.plan
            }
            
            autoSelectTodayIndex()
        } catch {
            log("Error loading workout plans: \(error)")
            errorMessage = "Failed to load your workout plans."
        }
        
        isLoadingPlans = false
    }
    
    func startConversation(initialPrompt: String) async {
        guard !initialPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your workout preferences."
            return
        }
        
        guard let userId = userId else {
            errorMessage = "User not authenticated."
            return
        }
        
        chatMessages = []
        readySummary = nil
        errorMessage = nil
        preferences = initialPrompt
        
        let userMessage = ChatMessage.user(initialPrompt)
        chatMessages.append(userMessage)
        
        flowState = .conversing
        isProcessingMessage = true
        
        let planTypes = planSelection?.planTypes ?? [.home, .gym]
        let generationPlanType: GenerationPlanType = planTypes.contains(.gym) ? .workoutGym : .workoutHome
        
        do {
            let generation = try await planGenerationService.createPendingGeneration(
                userId: userId,
                planType: generationPlanType,
                initialPrompt: initialPrompt
            )
            currentGenerationId = generation.id
            
            let response = try await geminiService.sendWorkoutConversation(
                conversationHistory: chatMessages,
                collectedContext: initialPrompt,
                planTypes: planTypes,
                isForced: false
            )
            
            let assistantMessage = ChatMessage.assistant(
                response.message,
                type: response.responseType
            )
            chatMessages.append(assistantMessage)
            
            try await planGenerationService.addMessage(
                generationId: generation.id,
                message: assistantMessage,
                updatedContext: initialPrompt
            )
            
            if response.responseType == .ready {
                readySummary = response.summary
                flowState = .readyToGenerate
            }
            
            saveConversationState()
            
        } catch {
            log("Error starting conversation: \(error)")
            errorMessage = "Failed to start conversation. Please try again."
            flowState = .idle
        }
        
        isProcessingMessage = false
    }
    
    func sendMessage(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let generationId = currentGenerationId else {
            errorMessage = "No active conversation."
            return
        }
        
        let userMessage = ChatMessage.user(text)
        chatMessages.append(userMessage)
        
        isProcessingMessage = true
        
        let updatedContext = GeminiAIService.accumulateContext(
            existingContext: preferences,
            newUserMessage: text
        )
        preferences = updatedContext
        
        let isForced = messageCount >= PendingGeneration.maxMessages
        let planTypes = planSelection?.planTypes ?? [.home, .gym]
        
        do {
            try await planGenerationService.addMessage(
                generationId: generationId,
                message: userMessage,
                updatedContext: updatedContext
            )
            
            let response = try await geminiService.sendWorkoutConversation(
                conversationHistory: chatMessages,
                collectedContext: updatedContext,
                planTypes: planTypes,
                isForced: isForced
            )
            
            let assistantMessage = ChatMessage.assistant(
                response.message,
                type: response.responseType
            )
            chatMessages.append(assistantMessage)
            
            try await planGenerationService.addMessage(
                generationId: generationId,
                message: assistantMessage,
                updatedContext: updatedContext
            )
            
            if response.responseType == .ready {
                readySummary = response.summary
                flowState = .readyToGenerate
            }
            
            saveConversationState()
            
        } catch {
            log("Error sending message: \(error)")
            errorMessage = "Failed to send message."
            chatMessages.removeLast()
        }
        
        isProcessingMessage = false
    }
    
    func requestMoreQuestions() async {
        guard let generationId = currentGenerationId else { return }
        
        let userMessage = ChatMessage.user("I'd like to share more details about my fitness goals.")
        chatMessages.append(userMessage)
        
        flowState = .conversing
        isProcessingMessage = true
        
        let planTypes = planSelection?.planTypes ?? [.home, .gym]
        
        do {
            try await planGenerationService.addMessage(
                generationId: generationId,
                message: userMessage,
                updatedContext: preferences
            )
            
            let response = try await geminiService.sendWorkoutConversation(
                conversationHistory: chatMessages,
                collectedContext: preferences,
                planTypes: planTypes,
                isForced: false
            )
            
            let assistantMessage = ChatMessage.assistant(
                response.message,
                type: response.responseType
            )
            chatMessages.append(assistantMessage)
            
            try await planGenerationService.addMessage(
                generationId: generationId,
                message: assistantMessage,
                updatedContext: preferences
            )
            
            if response.responseType == .ready {
                readySummary = response.summary
                flowState = .readyToGenerate
            }
            
            saveConversationState()
            
        } catch {
            log("Error requesting more questions: \(error)")
            errorMessage = "Failed to continue conversation."
        }
        
        isProcessingMessage = false
    }
    
    func startPlanGeneration() async {
        guard let userId = userId else {
            errorMessage = "User not authenticated."
            return
        }
        
        guard let generationId = currentGenerationId else {
            await startGeneration()
            return
        }
        
        flowState = .generatingPlan
        errorMessage = nil
        
        do {
            try await planGenerationService.startGeneration(generationId)
            
            let planTypes = planSelection?.planTypes ?? [.home, .gym]
            await startGeneration(for: planTypes)
            
            if homePlan != nil || gymPlan != nil {
                let resultId = homePlanDocument?.id ?? gymPlanDocument?.id ?? ""
                try await planGenerationService.markCompleted(
                    generationId: generationId,
                    resultPlanId: resultId
                )
                
                let planType: GenerationPlanType = planTypes.contains(.gym) ? .workoutGym : .workoutHome
                try? await NotificationService.shared.schedulePlanCompleteNotification(
                    planType: planType,
                    planName: "Workout Plan"
                )
                
                try await planGenerationService.markNotificationSent(generationId)
            }
            
            clearConversationState()
            
        } catch {
            log("Error during generation: \(error)")
            
            if let generationId = currentGenerationId {
                try? await planGenerationService.markFailed(
                    generationId: generationId,
                    error: error.localizedDescription
                )
            }
        }
    }
    
    func checkPendingGenerations() async {
        guard let userId = userId else { return }
        
        do {
            let generatingList = try await planGenerationService.loadGeneratingPhase(userId: userId)
            
            for generation in generatingList {
                if generation.planType == .workoutHome || generation.planType == .workoutGym {
                    currentGenerationId = generation.id
                    chatMessages = generation.conversationHistory
                    preferences = generation.collectedContext
                    flowState = .generatingPlan
                    
                    await startPlanGeneration()
                    return
                }
            }
            
            let completedList = try await planGenerationService.loadCompletedUnnotified(userId: userId)
            
            for generation in completedList {
                if generation.planType == .workoutHome || generation.planType == .workoutGym {
                    if let planId = generation.resultPlanId,
                       let doc = try await workoutPlanService.loadPlan(byId: planId) {
                        switch doc.planType {
                        case .home:
                            homePlanDocument = doc
                            homePlan = doc.plan
                        case .gym:
                            gymPlanDocument = doc
                            gymPlan = doc.plan
                        }
                        flowState = .planReady
                        
                        try await planGenerationService.markNotificationSent(generation.id)
                        return
                    }
                }
            }
            
        } catch {
            log("Error checking pending generations: \(error)")
        }
    }
    
    func startGeneration() async {
        let planTypes = planSelection?.planTypes ?? [.home, .gym]
        await startGeneration(for: planTypes)
    }
    
    func startGeneration(for planTypes: [WorkoutPlanType]) async {
        guard let userId = userId else {
            errorMessage = "User not authenticated."
            return
        }
        
        guard !preferences.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your workout preferences."
            return
        }
        
        flowState = .generatingPlan
        errorMessage = nil
        
        await withTaskGroup(of: Void.self) { group in
            if planTypes.contains(.home) {
                group.addTask { await self.generateHomePlan(userId: userId) }
            }
            if planTypes.contains(.gym) {
                group.addTask { await self.generateGymPlan(userId: userId) }
            }
        }
        
        if homePlan != nil || gymPlan != nil {
            flowState = .planReady
        } else if errorMessage != nil {
            flowState = .failed(errorMessage ?? "Unknown error")
        } else {
            flowState = .idle
        }
    }
    
    private func generateHomePlan(userId: String) async {
        isGeneratingHome = true
        homeProgress = 0.0
        
        do {
            homeProgress = 0.1
            
            // Fetch user context for personalization
            let userContext = try? await contextProvider.getContext(for: userId)
            let contextString = userContext?.formatForPrompt() ?? ""
            
            homeProgress = 0.2
            log("Generating home plan with user context (completeness: \(Int((userContext?.profile?.profileCompleteness ?? 0) * 100))%)")
            
            // Build prompt with context
            var fullPreferences = preferences
            if !contextString.isEmpty {
                fullPreferences = "USER CONTEXT:\n\(contextString)\n\nUSER REQUEST:\n\(preferences)"
            }
            
            let prompt = WorkoutPromptBuilder.buildHomePlanPrompt(
                preferences: fullPreferences,
                additionalContext: [:]
            )
            
            let complexity = RequestComplexity.analyze(preferences: preferences)
            let thinkingLevel: ThinkingLevel = complexity == .complexPlan ? .high : .medium
            
            log("Home plan using thinking: \(thinkingLevel.rawValue)")
            
            homeProgress = 0.3
            let response = try await geminiService.sendPrompt(
                prompt,
                systemPrompt: WorkoutPromptBuilder.systemPrompt,
                model: .flash,
                thinkingLevel: thinkingLevel,
                maxTokens: 16000,
                temperature: 1.0
            )
            
            homeProgress = 0.6
            let jsonString = GeminiAIService.extractJSON(from: response)
            
            guard let data = jsonString.data(using: .utf8) else {
                throw WorkoutGenerationError.parsingFailed
            }
            
            homeProgress = 0.8
            let plan = try JSONDecoder().decode(WeeklyWorkoutPlan.self, from: data)
            
            let planWithDates = assignDatesToWorkoutDays(plan)
            
            let doc = WorkoutPlanDocument(
                userId: userId,
                planType: .home,
                preferences: preferences,
                plan: planWithDates
            )
            
            try await workoutPlanService.saveSinglePlan(doc)
            
            // Record in plan history for learning
            await recordPlanGeneration(
                userId: userId,
                planId: doc.id,
                planType: .workoutHome,
                preferences: preferences,
                totalItems: plan.days.filter { !$0.isRestDay }.flatMap { $0.exercises }.count
            )
            
            homeProgress = 1.0
            homePlan = planWithDates
            homePlanDocument = doc
            
            log("Home plan generated successfully with personalization")
        } catch {
            log("Home plan generation failed: \(error)")
            if errorMessage == nil {
                errorMessage = mapError(error)
            }
        }
        
        isGeneratingHome = false
    }
    
    private func generateGymPlan(userId: String) async {
        isGeneratingGym = true
        gymProgress = 0.0
        
        do {
            gymProgress = 0.1
            
            let userContext = try? await contextProvider.getContext(for: userId)
            let contextString = userContext?.formatForPrompt() ?? ""
            
            gymProgress = 0.2
            log("Generating gym plan with user context (completeness: \(Int((userContext?.profile?.profileCompleteness ?? 0) * 100))%)")
            
            var fullPreferences = preferences
            if !contextString.isEmpty {
                fullPreferences = "USER CONTEXT:\n\(contextString)\n\nUSER REQUEST:\n\(preferences)"
            }
            
            let prompt = WorkoutPromptBuilder.buildGymPlanPrompt(
                preferences: fullPreferences,
                additionalContext: [:]
            )
            
            let complexity = RequestComplexity.analyze(preferences: preferences)
            let thinkingLevel: ThinkingLevel = complexity == .complexPlan ? .high : .medium
            
            log("Gym plan using thinking: \(thinkingLevel.rawValue)")
            
            gymProgress = 0.3
            let response = try await geminiService.sendPrompt(
                prompt,
                systemPrompt: WorkoutPromptBuilder.systemPrompt,
                model: .flash,
                thinkingLevel: thinkingLevel,
                maxTokens: 16000,
                temperature: 1.0
            )
            
            gymProgress = 0.6
            let jsonString = GeminiAIService.extractJSON(from: response)
            
            guard let data = jsonString.data(using: .utf8) else {
                throw WorkoutGenerationError.parsingFailed
            }
            
            gymProgress = 0.8
            let plan = try JSONDecoder().decode(WeeklyWorkoutPlan.self, from: data)
            
            let planWithDates = assignDatesToWorkoutDays(plan)
            
            let doc = WorkoutPlanDocument(
                userId: userId,
                planType: .gym,
                preferences: preferences,
                plan: planWithDates
            )
            
            try await workoutPlanService.saveSinglePlan(doc)
            
            await recordPlanGeneration(
                userId: userId,
                planId: doc.id,
                planType: .workoutGym,
                preferences: preferences,
                totalItems: plan.days.filter { !$0.isRestDay }.flatMap { $0.exercises }.count
            )
            
            gymProgress = 1.0
            gymPlan = planWithDates
            gymPlanDocument = doc
            
            log("Gym plan generated successfully with personalization")
        } catch {
            log("Gym plan generation failed: \(error)")
            if errorMessage == nil {
                errorMessage = mapError(error)
            }
        }
        
        isGeneratingGym = false
    }
    
    private func assignDatesToWorkoutDays(_ plan: WeeklyWorkoutPlan) -> WeeklyWorkoutPlan {
        var updatedPlan = plan
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var updatedDays: [WorkoutDay] = []
        for (index, day) in plan.days.enumerated() {
            var updatedDay = day
            if let date = calendar.date(byAdding: .day, value: index, to: today) {
                updatedDay.date = dateFormatter.string(from: date)
            }
            updatedDays.append(updatedDay)
        }
        
        updatedPlan.days = updatedDays
        return updatedPlan
    }
    
    func resetPlans() {
        homePlan = nil
        gymPlan = nil
        homePlanDocument = nil
        gymPlanDocument = nil
        preferences = ""
        chatMessages = []
        currentGenerationId = nil
        readySummary = nil
        flowState = .idle
        errorMessage = nil
        homeProgress = 0.0
        gymProgress = 0.0
        selectedDayIndex = 0
        
        clearConversationState()
    }
    
    func deletePlan(_ planType: WorkoutPlanType) async {
        do {
            switch planType {
            case .home:
                if let doc = homePlanDocument {
                    try await workoutPlanService.deletePlan(doc)
                    homePlan = nil
                    homePlanDocument = nil
                }
            case .gym:
                if let doc = gymPlanDocument {
                    try await workoutPlanService.deletePlan(doc)
                    gymPlan = nil
                    gymPlanDocument = nil
                }
            }
        } catch {
            log("Error deleting plan: \(error)")
            errorMessage = "Failed to delete the plan."
        }
    }
    
    func getTodaysDayIndex(for plan: WeeklyWorkoutPlan) -> Int? {
        let today = Calendar.current.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        return plan.days.firstIndex { day in
            if let dayDate = dateFormatter.date(from: day.date) {
                return Calendar.current.isDate(dayDate, inSameDayAs: today)
            }
            return false
        }
    }
    
    private func autoSelectTodayIndex() {
        if let plan = homePlan ?? gymPlan,
           let todayIndex = getTodaysDayIndex(for: plan) {
            selectedDayIndex = todayIndex
        } else {
            selectedDayIndex = 0
        }
    }
    
    func generateShareContent(for planType: WorkoutPlanType) {
        let plan: WeeklyWorkoutPlan?
        switch planType {
        case .home: plan = homePlan
        case .gym: plan = gymPlan
        }
        
        guard let plan = plan else {
            shareItems = []
            return
        }
        
        let shareText = plan.formattedForSharing()
        shareItems = [shareText]
    }
    
    func markOnboardingSeen() {
        hasSeenWorkoutOnboarding = true
        UserDefaults.standard.set(true, forKey: "workout_planner_onboarding_seen")
    }
    
    func startOver() {
        preferences = ""
        chatMessages = []
        currentGenerationId = nil
        readySummary = nil
        flowState = .idle
        clearConversationState()
    }
    
    private func saveConversationState() {
        let messages = chatMessages
        let generationId = currentGenerationId
        let prefs = preferences
        let summary = readySummary
        let isReady = flowState == .readyToGenerate
        let isGenerating = flowState == .generatingPlan
        let selection = planSelection
        
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(messages) {
                UserDefaults.standard.set(data, forKey: PersistenceKeys.chatMessages)
            }
            UserDefaults.standard.set(generationId, forKey: PersistenceKeys.generationId)
            UserDefaults.standard.set(prefs, forKey: PersistenceKeys.preferences)
            UserDefaults.standard.set(summary, forKey: PersistenceKeys.readySummary)
            UserDefaults.standard.set(isReady, forKey: PersistenceKeys.isReady)
            UserDefaults.standard.set(isGenerating, forKey: PersistenceKeys.isGenerating)
            
            if let selection = selection {
                UserDefaults.standard.set(selection.rawValue, forKey: PersistenceKeys.planSelection)
            }
        }
    }
    
    private func restoreConversationState() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let data = UserDefaults.standard.data(forKey: PersistenceKeys.chatMessages),
                  let messages = try? JSONDecoder().decode([ChatMessage].self, from: data),
                  !messages.isEmpty else {
                return
            }
            
            let generationId = UserDefaults.standard.string(forKey: PersistenceKeys.generationId)
            let preferences = UserDefaults.standard.string(forKey: PersistenceKeys.preferences) ?? ""
            let readySummary = UserDefaults.standard.string(forKey: PersistenceKeys.readySummary)
            let selectionRaw = UserDefaults.standard.string(forKey: PersistenceKeys.planSelection)
            let isGenerating = UserDefaults.standard.bool(forKey: PersistenceKeys.isGenerating)
            let isReady = UserDefaults.standard.bool(forKey: PersistenceKeys.isReady)
            
            await MainActor.run {
                guard let self = self else { return }
                
                self.chatMessages = messages
                self.currentGenerationId = generationId
                self.preferences = preferences
                self.readySummary = readySummary
                
                if let selectionRaw = selectionRaw,
                   let selection = PlanSelection(rawValue: selectionRaw) {
                    self.planSelection = selection
                }
                
                if isGenerating {
                    self.flowState = .generatingPlan
                } else if isReady {
                    self.flowState = .readyToGenerate
                } else {
                    self.flowState = .conversing
                }
            }
        }
    }
    
    private func clearConversationState() {
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.chatMessages)
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.generationId)
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.preferences)
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.readySummary)
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.isReady)
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.isGenerating)
        
        chatMessages = []
        currentGenerationId = nil
        readySummary = nil
    }
    
    private func mapError(_ error: Error) -> String {
        let appError = ErrorHandler.shared.handle(error, context: "WorkoutPlanGeneration")
        return appError.userMessage
    }
    
    private func recordPlanGeneration(
        userId: String,
        planId: String,
        planType: PlanHistoryType,
        preferences: String,
        totalItems: Int
    ) async {
        let entry = PlanHistoryEntry(
            planId: planId,
            planType: planType,
            preferences: preferences,
            completionRate: 0,
            completedItems: 0,
            totalItems: totalItems
        )
        
        do {
            try await PlanHistoryService.shared.addEntry(entry, userId: userId)
            log("Recorded plan generation in history")
        } catch {
            log("Failed to record plan in history: \(error)")
        }
    }
    
    private func log(_ message: String) {
        appLog(message, category: .workout)
    }
}

enum WorkoutGenerationError: LocalizedError {
    case parsingFailed
    case networkError
    case insufficientData
    case userNotAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .parsingFailed:
            return "Failed to understand AI response. Please try again."
        case .networkError:
            return "Network error. Please check your connection."
        case .insufficientData:
            return "Could not generate a complete workout plan."
        case .userNotAuthenticated:
            return "Please sign in to generate workout plans."
        }
    }
}

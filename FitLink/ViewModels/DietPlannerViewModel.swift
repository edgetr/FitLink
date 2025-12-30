import SwiftUI
import Combine
import EventKit
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

enum DietPlannerViewState: Equatable {
    case idle
    case loadingPlans
    case conversing
    case readyToGenerate
    case generating
    case generationFailed
    case showingPlan
    case fetchingClarifications
    case awaitingClarifications
}

@MainActor
class DietPlannerViewModel: ObservableObject {
    
    // MARK: - Primary View State (Single source of truth)
    @Published var viewState: DietPlannerViewState = .idle
    
    @Published var currentDietPlan: DietPlan?
    @Published var allDietPlans: [DietPlan] = []
    @Published var selectedDayIndex: Int = 0
    @Published var generationProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var isOnline: Bool? = true
    @Published var preferences: String = ""
    
    @Published var pendingClarificationQuestions: [ClarifyingQuestion] = []
    @Published var clarificationAnswers: [String: String] = [:]
    @Published var hasSeenOnboardingTip: Bool
    
    // MARK: - Chat Conversation Properties
    @Published var chatMessages: [ChatMessage] = []
    @Published var isProcessingMessage: Bool = false
    @Published var currentGenerationId: String?
    @Published var readySummary: String?
    
    // MARK: - Computed Properties
    var isGenerating: Bool { viewState == .generating }
    var isLoadingPlans: Bool { viewState == .loadingPlans }
    var hasGenerationFailed: Bool { viewState == .generationFailed }
    var isAwaitingClarifications: Bool { viewState == .awaitingClarifications }
    var isFetchingClarifications: Bool { viewState == .fetchingClarifications }
    var isConversing: Bool { viewState == .conversing }
    var isReadyToGenerate: Bool { viewState == .readyToGenerate }
    var canSendMessage: Bool { viewState == .conversing && !isProcessingMessage }
    var messageCount: Int { chatMessages.filter { $0.role == .user }.count }
    var isAtMaxMessages: Bool { messageCount >= PendingGeneration.maxMessages }
    
    @Published var shareItems: [Any] = []
    @Published var isShowingShareSheet = false
    
    private let geminiService: GeminiAIService
    private let dietPlanService = DietPlanService.shared
    private let planGenerationService = PlanGenerationService.shared
    private let contextProvider = UserContextProvider.shared
    private let eventStore = EKEventStore()
    private var cancellables = Set<AnyCancellable>()
    private let maxRetryAttempts = 3
    private let partialSuccessThreshold = 0.7
    
    /// Stored observer token for proper cleanup - block-based observers MUST be stored and explicitly removed
    private var notificationObserver: NSObjectProtocol?
    
    var userId: String? {
        didSet {
            if userId != nil {
                Task {
                    await loadAllDietPlansForUser()
                }
            }
        }
    }
    
    var activeDietPlans: [DietPlan] {
        allDietPlans.filter { !$0.isArchived }
    }
    
    var archivedDietPlans: [DietPlan] {
        allDietPlans.filter { $0.isArchived }
    }
    
    var currentWeekRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? today
        return (weekStart, weekEnd)
    }
    
    var currentWeekDates: [Date] {
        let calendar = Calendar.current
        let (start, _) = currentWeekRange
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    
    init() {
        self.geminiService = GeminiAIService()
        self.hasSeenOnboardingTip = UserDefaults.standard.bool(forKey: "diet_planner_onboarding_seen")
        
        restoreConversationState()
        restoreQuestionState()
        restoreLastSelectedPlanId()
        
        setupNotificationObservers()
        
        Task {
            await requestNotificationPermission()
        }
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
              let planType = GenerationPlanType(rawValue: planTypeRaw),
              planType == .diet else {
            return
        }
        
        guard let resultPlanId = userInfo["resultPlanId"] as? String,
              !resultPlanId.isEmpty else {
            return
        }
        
        Task { @MainActor in
            do {
                if let plan = try await dietPlanService.loadPlan(byId: resultPlanId) {
                    currentDietPlan = plan
                    if !allDietPlans.contains(where: { $0.id == plan.id }) {
                        allDietPlans.insert(plan, at: 0)
                    }
                    viewState = .showingPlan
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
    
    func getDietPlanDates(for plan: DietPlan) -> [Date] {
        let calendar = Calendar.current
        return (0..<plan.totalDays).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: plan.weekStartDate)
        }
    }
    
    func askClarifyingQuestionsIfNeeded() async {
        guard !preferences.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your dietary preferences."
            return
        }
        
        viewState = .fetchingClarifications
        errorMessage = nil
        
        do {
            let prompt = DietPlannerSystemPrompt.buildClarifyingQuestionsPrompt(userInput: preferences)
            let systemPrompt = "You determine if more info is needed for meal planning. Respond with valid JSON only."
            
            let response = try await geminiService.sendPrompt(
                prompt,
                systemPrompt: systemPrompt,
                model: .flash,
                thinkingLevel: .minimal,
                maxTokens: 2000,
                temperature: 0.5
            )
            let jsonString = GeminiAIService.extractJSON(from: response)
            
            guard let data = jsonString.data(using: .utf8) else {
                throw GeminiAIService.APIError.parseError("Invalid response encoding")
            }
            
            let clarificationResponse = try JSONDecoder().decode(ClarificationResponse.self, from: data)
            
            if clarificationResponse.needsClarification, let questions = clarificationResponse.questions {
                pendingClarificationQuestions = questions
                viewState = .awaitingClarifications
                saveQuestionState()
            } else {
                await generateDietPlan()
            }
        } catch {
            log("Error fetching clarifications: \(error)")
            await generateDietPlan()
        }
    }
    
    func submitClarificationAnswers() async {
        viewState = .generating
        
        var enhancedPreferences = preferences
        for question in pendingClarificationQuestions {
            if let answer = clarificationAnswers[question.id], !answer.isEmpty {
                enhancedPreferences += "\n\(question.text): \(answer)"
            }
        }
        
        preferences = enhancedPreferences
        pendingClarificationQuestions = []
        clarificationAnswers = [:]
        clearQuestionState()
        
        await generateDietPlanInternal()
    }
    
    func skipClarifications() {
        viewState = .generating
        pendingClarificationQuestions = []
        clarificationAnswers = [:]
        clearQuestionState()
        
        Task {
            await generateDietPlanInternal()
        }
    }
    
    // MARK: - Chat Conversation Flow
    
    func startConversation(initialPrompt: String) async {
        guard !initialPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your dietary preferences."
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
        
        viewState = .conversing
        isProcessingMessage = true
        
        do {
            let generation = try await planGenerationService.createPendingGeneration(
                userId: userId,
                planType: .diet,
                initialPrompt: initialPrompt
            )
            currentGenerationId = generation.id
            
            let response = try await geminiService.sendDietConversation(
                conversationHistory: chatMessages,
                collectedContext: initialPrompt,
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
                viewState = .readyToGenerate
            }
            
            saveConversationState()
            
        } catch {
            log("Error starting conversation: \(error)")
            errorMessage = "Failed to start conversation. Please try again."
            viewState = .idle
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
        
        do {
            try await planGenerationService.addMessage(
                generationId: generationId,
                message: userMessage,
                updatedContext: updatedContext
            )
            
            let response = try await geminiService.sendDietConversation(
                conversationHistory: chatMessages,
                collectedContext: updatedContext,
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
                viewState = .readyToGenerate
            }
            
            saveConversationState()
            
        } catch {
            log("Error sending message: \(error)")
            errorMessage = "Failed to send message. Please try again."
            chatMessages.removeLast()
        }
        
        isProcessingMessage = false
    }
    
    func requestMoreQuestions() async {
        guard let generationId = currentGenerationId else { return }
        
        let userMessage = ChatMessage.user("I'd like to provide more details about my preferences.")
        chatMessages.append(userMessage)
        
        viewState = .conversing
        isProcessingMessage = true
        
        do {
            try await planGenerationService.addMessage(
                generationId: generationId,
                message: userMessage,
                updatedContext: preferences
            )
            
            let response = try await geminiService.sendDietConversation(
                conversationHistory: chatMessages,
                collectedContext: preferences,
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
                viewState = .readyToGenerate
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
            await generateDietPlan()
            return
        }
        
        viewState = .generating
        errorMessage = nil
        generationProgress = 0.0
        
        do {
            try await planGenerationService.startGeneration(generationId)
            
            await performDietPlanGeneration(userId: userId)
            
            if let plan = currentDietPlan {
                try await planGenerationService.markCompleted(
                    generationId: generationId,
                    resultPlanId: plan.id
                )
                
                try? await NotificationService.shared.schedulePlanCompleteNotification(
                    planType: .diet,
                    planName: "Meal Plan"
                )
                
                try await planGenerationService.markNotificationSent(generationId)
            }
            
            clearConversationState()
            
        } catch {
            log("Error during plan generation: \(error)")
            
            if let generationId = currentGenerationId {
                try? await planGenerationService.markFailed(
                    generationId: generationId,
                    error: error.localizedDescription
                )
            }
        }
    }
    
    func startOver() {
        preferences = ""
        pendingClarificationQuestions = []
        clarificationAnswers = [:]
        chatMessages = []
        currentGenerationId = nil
        readySummary = nil
        viewState = .idle
        clearQuestionState()
        clearConversationState()
    }
    
    func generateDietPlan() async {
        guard let userId = userId else {
            errorMessage = "User not authenticated."
            return
        }
        
        guard !preferences.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your dietary preferences."
            return
        }
        
        viewState = .generating
        await performDietPlanGeneration(userId: userId)
    }
    
    private func generateDietPlanInternal() async {
        guard let userId = userId else {
            errorMessage = "User not authenticated."
            viewState = .generationFailed
            return
        }

        guard !preferences.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your dietary preferences."
            viewState = .generationFailed
            return
        }

        await performDietPlanGeneration(userId: userId)
    }
    
    private func performDietPlanGeneration(userId: String) async {
        errorMessage = nil
        generationProgress = 0.0
        
        do {
            generationProgress = 0.1
            let pendingPlan = try await dietPlanService.createPendingPlan(userId: userId, preferences: preferences)
            currentDietPlan = pendingPlan
            
            generationProgress = 0.15
            
            let userContext = try? await contextProvider.getContext(for: userId)
            let contextString = userContext?.formatForPrompt() ?? ""
            
            log("Generating diet plan with context (completeness: \(Int((userContext?.profile?.profileCompleteness ?? 0) * 100))%)")
            
            generationProgress = 0.2
            try await dietPlanService.updateGenerationStatus(planId: pendingPlan.id, status: .generating, progress: 0.2)
            
            generationProgress = 0.3
            
            var fullPreferences = preferences
            if !contextString.isEmpty {
                fullPreferences = "USER CONTEXT:\n\(contextString)\n\nUSER REQUEST:\n\(preferences)"
            }
            
            let userPrompt = DietPlannerSystemPrompt.buildUserPrompt(preferences: fullPreferences)
            
            let complexity = RequestComplexity.analyze(preferences: preferences)
            let (model, thinkingLevel) = GeminiAIService.recommendedModel(for: complexity)
            
            log("Using model: \(model.rawValue), thinking: \(thinkingLevel.rawValue) for complexity: \(complexity)")
            
            let response = try await geminiService.sendPrompt(
                userPrompt,
                systemPrompt: DietPlannerSystemPrompt.systemPrompt,
                model: model,
                thinkingLevel: thinkingLevel,
                maxTokens: 16000,
                temperature: 1.0
            )
            
            generationProgress = 0.7
            let jsonString = GeminiAIService.extractJSON(from: response)
            
            generationProgress = 0.75
            
            let generationResult = try await processAndValidateResponse(
                jsonString: jsonString,
                pendingPlan: pendingPlan,
                userId: userId
            )
            
            if generationResult.success {
                generationProgress = 1.0
                currentDietPlan = pendingPlan
                
                if !allDietPlans.contains(where: { $0.id == pendingPlan.id }) {
                    allDietPlans.insert(pendingPlan, at: 0)
                }
                
                saveLastSelectedPlanId(pendingPlan.id)
                autoSelectTodayIndex()
                viewState = .showingPlan
            } else {
                pendingPlan.generationStatus = .failed
                try await dietPlanService.updatePlan(pendingPlan)
                throw DietPlanGenerationError.insufficientData(generationResult.missingFields)
            }
        } catch {
            log("Diet plan generation failed: \(error)")
            viewState = .generationFailed
            errorMessage = mapError(error)
        }
    }
    
    func loadAllDietPlansForUser() async {
        guard let userId = userId else { return }
        
        viewState = .loadingPlans
        
        do {
            let archivedCount = try await dietPlanService.archiveOldPlans(userId: userId)
            if archivedCount > 0 {
                log("Archived \(archivedCount) old plan(s)")
            }
            
            allDietPlans = try await dietPlanService.loadAllPlansForUser(userId: userId)
            
            if let lastPlanId = UserDefaults.standard.string(forKey: "diet_planner_last_plan_id"),
               let lastPlan = allDietPlans.first(where: { $0.id == lastPlanId }) {
                currentDietPlan = lastPlan
            } else if let activePlan = activeDietPlans.first {
                currentDietPlan = activePlan
            }
            
            autoSelectTodayIndex()
            
            if currentDietPlan != nil {
                viewState = .showingPlan
            } else {
                viewState = .idle
            }
        } catch {
            log("Error loading diet plans: \(error)")
            errorMessage = "Failed to load your meal plans."
            viewState = .idle
        }
    }
    
    func selectPlan(_ plan: DietPlan) {
        currentDietPlan = plan
        saveLastSelectedPlanId(plan.id)
        autoSelectTodayIndex()
    }
    
    func resetPlan() {
        currentDietPlan = nil
        preferences = ""
        pendingClarificationQuestions = []
        clarificationAnswers = [:]
        chatMessages = []
        currentGenerationId = nil
        readySummary = nil
        viewState = .idle
        errorMessage = nil
        generationProgress = 0.0
        selectedDayIndex = 0
        
        clearConversationState()
        UserDefaults.standard.removeObject(forKey: "diet_planner_last_plan_id")
    }
    
    func archivePlan(_ plan: DietPlan) async {
        do {
            try await dietPlanService.archivePlan(plan)
            if let index = allDietPlans.firstIndex(where: { $0.id == plan.id }) {
                allDietPlans[index].isArchived = true
                allDietPlans[index].archivedAt = Date()
            }
            if currentDietPlan?.id == plan.id {
                currentDietPlan = activeDietPlans.first
            }
        } catch {
            log("Error archiving plan: \(error)")
            errorMessage = "Failed to archive the plan."
        }
    }
    
    func deletePlan(_ plan: DietPlan) async {
        do {
            try await dietPlanService.deletePlan(plan)
            allDietPlans.removeAll { $0.id == plan.id }
            if currentDietPlan?.id == plan.id {
                currentDietPlan = activeDietPlans.first
            }
        } catch {
            log("Error deleting plan: \(error)")
            errorMessage = "Failed to delete the plan."
        }
    }
    
    func toggleMealDone(mealId: UUID) async {
        guard let plan = currentDietPlan else { return }
        guard selectedDayIndex < plan.dailyPlans.count else { return }
        
        var dailyPlan = plan.dailyPlans[selectedDayIndex]
        guard let mealIndex = dailyPlan.meals.firstIndex(where: { $0.id == mealId }) else { return }
        
        let newIsDone = !dailyPlan.meals[mealIndex].isDone
        let dayNumber = dailyPlan.day
        
        dailyPlan.meals[mealIndex].isDone = newIsDone
        plan.dailyPlans[selectedDayIndex] = dailyPlan
        
        do {
            try await dietPlanService.markMealDone(
                planId: plan.id,
                dayNumber: dayNumber,
                mealId: mealId,
                isDone: newIsDone
            )
        } catch {
            log("Error toggling meal done: \(error)")
            dailyPlan.meals[mealIndex].isDone = !newIsDone
            plan.dailyPlans[selectedDayIndex] = dailyPlan
        }
    }
    
    func getTodaysDayIndex() -> Int? {
        guard let plan = currentDietPlan else { return nil }
        
        let today = Calendar.current.startOfDay(for: Date())
        let planDates = getDietPlanDates(for: plan)
        
        return planDates.firstIndex { Calendar.current.isDate($0, inSameDayAs: today) }
    }
    
    func requestCalendarAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                return try await eventStore.requestFullAccessToEvents()
            } else {
                return try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }
        } catch {
            log("Calendar access error: \(error)")
            return false
        }
    }
    
    func addMealsToCalendar() async -> Int {
        guard let plan = currentDietPlan else { return 0 }
        
        let hasAccess = await requestCalendarAccess()
        guard hasAccess else {
            errorMessage = "Calendar access denied. Please enable in Settings."
            return 0
        }
        
        var addedCount = 0
        let calendar = Calendar.current
        
        for dailyPlan in plan.dailyPlans {
            guard let date = dailyPlan.actualDate else { continue }
            
            for meal in dailyPlan.sortedMeals {
                let event = EKEvent(eventStore: eventStore)
                event.title = "\(meal.type.icon) \(meal.recipe.name)"
                event.notes = """
                Calories: \(meal.nutrition.calories)
                Prep time: \(meal.recipe.formattedPrepTime)
                
                \(meal.recipe.explanation)
                """
                
                let mealHour: Int
                switch meal.type {
                case .breakfast: mealHour = 8
                case .lunch: mealHour = 12
                case .snack: mealHour = 15
                case .dinner: mealHour = 19
                }
                
                if let startDate = calendar.date(bySettingHour: mealHour, minute: 0, second: 0, of: date) {
                    event.startDate = startDate
                    event.endDate = calendar.date(byAdding: .hour, value: 1, to: startDate)
                    event.calendar = eventStore.defaultCalendarForNewEvents
                    
                    do {
                        try eventStore.save(event, span: .thisEvent)
                        addedCount += 1
                    } catch {
                        log("Failed to save calendar event: \(error)")
                    }
                }
            }
        }
        
        return addedCount
    }
    
    func generateShareContent() {
        guard let plan = currentDietPlan else {
            shareItems = []
            return
        }
        
        let shareText = plan.formattedForSharing()
        shareItems = [shareText]
    }
    
    func markOnboardingSeen() {
        hasSeenOnboardingTip = true
        UserDefaults.standard.set(true, forKey: "diet_planner_onboarding_seen")
    }
    
    private func autoSelectTodayIndex() {
        if let todayIndex = getTodaysDayIndex() {
            selectedDayIndex = todayIndex
        } else {
            selectedDayIndex = 0
        }
    }
    
    private func saveQuestionState() {
        if let data = try? JSONEncoder().encode(pendingClarificationQuestions) {
            UserDefaults.standard.set(data, forKey: "diet_planner_pending_questions")
        }
        UserDefaults.standard.set(clarificationAnswers, forKey: "diet_planner_answers")
        UserDefaults.standard.set(preferences, forKey: "diet_planner_preferences")
    }
    
    private func restoreQuestionState() {
        if let data = UserDefaults.standard.data(forKey: "diet_planner_pending_questions"),
           let questions = try? JSONDecoder().decode([ClarifyingQuestion].self, from: data) {
            pendingClarificationQuestions = questions
            if !questions.isEmpty {
                viewState = .awaitingClarifications
            }
        }
        
        if let answers = UserDefaults.standard.dictionary(forKey: "diet_planner_answers") as? [String: String] {
            clarificationAnswers = answers
        }
        
        if let savedPreferences = UserDefaults.standard.string(forKey: "diet_planner_preferences") {
            preferences = savedPreferences
        }
    }
    
    private func clearQuestionState() {
        UserDefaults.standard.removeObject(forKey: "diet_planner_pending_questions")
        UserDefaults.standard.removeObject(forKey: "diet_planner_answers")
        UserDefaults.standard.removeObject(forKey: "diet_planner_preferences")
    }
    
    // MARK: - Conversation State Persistence
    
    private func saveConversationState() {
        let messages = chatMessages
        let generationId = currentGenerationId
        let prefs = preferences
        let summary = readySummary
        let isReady = viewState == .readyToGenerate
        let isGenerating = viewState == .generating
        
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(messages) {
                UserDefaults.standard.set(data, forKey: "diet_planner_chat_messages")
            }
            UserDefaults.standard.set(generationId, forKey: "diet_planner_generation_id")
            UserDefaults.standard.set(prefs, forKey: "diet_planner_preferences")
            UserDefaults.standard.set(summary, forKey: "diet_planner_ready_summary")
            UserDefaults.standard.set(isReady, forKey: "diet_planner_is_ready")
            UserDefaults.standard.set(isGenerating, forKey: "diet_planner_is_generating")
        }
    }
    
    private func restoreConversationState() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let data = UserDefaults.standard.data(forKey: "diet_planner_chat_messages"),
                  let messages = try? JSONDecoder().decode([ChatMessage].self, from: data),
                  !messages.isEmpty else {
                return
            }
            
            let generationId = UserDefaults.standard.string(forKey: "diet_planner_generation_id")
            let preferences = UserDefaults.standard.string(forKey: "diet_planner_preferences") ?? ""
            let readySummary = UserDefaults.standard.string(forKey: "diet_planner_ready_summary")
            let isGenerating = UserDefaults.standard.bool(forKey: "diet_planner_is_generating")
            let isReady = UserDefaults.standard.bool(forKey: "diet_planner_is_ready")
            
            await MainActor.run {
                guard let self = self else { return }
                
                self.chatMessages = messages
                self.currentGenerationId = generationId
                self.preferences = preferences
                self.readySummary = readySummary
                
                if isGenerating {
                    self.viewState = .generating
                } else if isReady {
                    self.viewState = .readyToGenerate
                } else {
                    self.viewState = .conversing
                }
            }
        }
    }
    
    private func clearConversationState() {
        UserDefaults.standard.removeObject(forKey: "diet_planner_chat_messages")
        UserDefaults.standard.removeObject(forKey: "diet_planner_generation_id")
        UserDefaults.standard.removeObject(forKey: "diet_planner_preferences")
        UserDefaults.standard.removeObject(forKey: "diet_planner_ready_summary")
        UserDefaults.standard.removeObject(forKey: "diet_planner_is_ready")
        UserDefaults.standard.removeObject(forKey: "diet_planner_is_generating")
        
        chatMessages = []
        currentGenerationId = nil
        readySummary = nil
    }
    
    func checkPendingGenerations() async {
        guard let userId = userId else { return }
        
        do {
            let generatingList = try await planGenerationService.loadGeneratingPhase(userId: userId)
            
            for generation in generatingList where generation.planType == .diet {
                currentGenerationId = generation.id
                chatMessages = generation.conversationHistory
                preferences = generation.collectedContext
                viewState = .generating
                
                await startPlanGeneration()
                return
            }
            
            let completedList = try await planGenerationService.loadCompletedUnnotified(userId: userId)
            
            for generation in completedList where generation.planType == .diet {
                if let planId = generation.resultPlanId,
                   let plan = try await dietPlanService.loadPlan(byId: planId) {
                    currentDietPlan = plan
                    if !allDietPlans.contains(where: { $0.id == plan.id }) {
                        allDietPlans.insert(plan, at: 0)
                    }
                    viewState = .showingPlan
                    
                    try await planGenerationService.markNotificationSent(generation.id)
                    return
                }
            }
            
        } catch {
            log("Error checking pending generations: \(error)")
        }
    }
    
    func handleUserIdSet() {
        Task {
            await loadAllDietPlansForUser()
            await checkPendingGenerations()
        }
    }
    
    private func saveLastSelectedPlanId(_ planId: String) {
        UserDefaults.standard.set(planId, forKey: "diet_planner_last_plan_id")
    }
    
    private func restoreLastSelectedPlanId() {
    }
    
    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            log("Notification permission: \(granted ? "granted" : "denied")")
        } catch {
            log("Notification permission error: \(error)")
        }
    }
    
    private struct GenerationResult {
        let success: Bool
        let missingFields: [String]
        let isPartialSuccess: Bool
    }
    
    private func processAndValidateResponse(
        jsonString: String,
        pendingPlan: DietPlan,
        userId: String
    ) async throws -> GenerationResult {
        generationProgress = 0.80
        
        let partialResult = DietPlanPartialSuccessHandler.handlePartialResponse(
            jsonString,
            userId: userId,
            preferences: preferences
        )
        
        if partialResult.success, let handledPlan = partialResult.plan {
            generationProgress = 0.85
            
            pendingPlan.dailyPlans = handledPlan.dailyPlans
            pendingPlan.summary = handledPlan.summary
            pendingPlan.totalDays = handledPlan.totalDays
            pendingPlan.hasFilledData = handledPlan.hasFilledData
            pendingPlan.filledDataDetails = handledPlan.filledDataDetails
            pendingPlan.generationStatus = handledPlan.generationStatus
            pendingPlan.generationProgress = 1.0
            
            let formalValidation = DietPlanResponseValidator.validate(pendingPlan)
            
            if formalValidation.isValid {
                appLog("Diet plan validated successfully", level: .info, category: .diet)
            } else if !formalValidation.errors.filter({ $0.severity == .critical }).isEmpty {
                let criticalErrors = formalValidation.errors.filter { $0.severity == .critical }
                let errorMessages = criticalErrors.map { $0.message }
                appLog("Critical validation errors: \(errorMessages)", level: .error, category: .diet)
                return GenerationResult(success: false, missingFields: errorMessages, isPartialSuccess: false)
            } else {
                let warningMessages = formalValidation.warnings.map { $0.message }
                appLog("Validation warnings (proceeding): \(warningMessages)", level: .warning, category: .diet)
            }
            
            generationProgress = 0.90
            try await dietPlanService.updatePlan(pendingPlan)
            
            await recordPlanGeneration(
                userId: userId,
                planId: pendingPlan.id,
                preferences: preferences,
                totalItems: pendingPlan.dailyPlans.flatMap { $0.meals }.count
            )
            
            generationProgress = 0.95
            
            let isPartial = !partialResult.filledFields.isEmpty
            if isPartial {
                appLog("Plan generated with partial success: \(partialResult.filledFields.count) fields filled", level: .info, category: .diet)
            }
            
            return GenerationResult(success: true, missingFields: partialResult.filledFields, isPartialSuccess: isPartial)
        }
        
        appLog("Partial handler rejected response: \(partialResult.message)", level: .error, category: .diet)
        return GenerationResult(success: false, missingFields: [partialResult.message], isPartialSuccess: false)
    }
    
    private func validateDietPlanResponse(_ response: AIGeneratedDietPlanResponse) -> ValidationResult {
        var missingFields: [String] = []
        var totalExpectedItems = 0
        var presentItems = 0
        
        if response.dailyPlans.isEmpty {
            missingFields.append("No daily plans generated")
        }
        
        for (index, dailyPlan) in response.dailyPlans.enumerated() {
            let dayLabel = "Day \(index + 1)"
            totalExpectedItems += 4
            
            let hasBreakfast = dailyPlan.meals.contains { $0.type == .breakfast }
            let hasLunch = dailyPlan.meals.contains { $0.type == .lunch }
            let hasDinner = dailyPlan.meals.contains { $0.type == .dinner }
            let hasSnack = dailyPlan.meals.contains { $0.type == .snack }
            
            if hasBreakfast { presentItems += 1 } else { missingFields.append("\(dayLabel): Missing breakfast") }
            if hasLunch { presentItems += 1 } else { missingFields.append("\(dayLabel): Missing lunch") }
            if hasDinner { presentItems += 1 } else { missingFields.append("\(dayLabel): Missing dinner") }
            if hasSnack { presentItems += 1 }
            
            for meal in dailyPlan.meals {
                if meal.recipe.name.isEmpty {
                    missingFields.append("\(dayLabel) \(meal.type.displayName): Missing recipe name")
                }
                if meal.recipe.ingredients.isEmpty {
                    missingFields.append("\(dayLabel) \(meal.type.displayName): Missing ingredients")
                }
                if meal.recipe.instructions.isEmpty {
                    missingFields.append("\(dayLabel) \(meal.type.displayName): Missing instructions")
                }
            }
        }
        
        let completeness = totalExpectedItems > 0 ? Double(presentItems) / Double(totalExpectedItems) : 0
        let isValid = missingFields.isEmpty && response.dailyPlans.count >= 7
        
        return ValidationResult(isValid: isValid, completeness: completeness, missingFields: missingFields)
    }
    
    private func populateDietPlan(_ plan: DietPlan, from response: AIGeneratedDietPlanResponse) {
        let calendar = Calendar.current
        
        var dailyPlans: [DailyPlan] = []
        for (index, aiDailyPlan) in response.dailyPlans.enumerated() {
            let actualDate = calendar.date(byAdding: .day, value: index, to: plan.weekStartDate)
            
            let meals = aiDailyPlan.meals.map { aiMeal in
                Meal(
                    type: aiMeal.type,
                    recipe: Recipe(
                        name: aiMeal.recipe.name,
                        imageUrl: aiMeal.recipe.imageUrl,
                        prepTime: aiMeal.recipe.prepTime,
                        servings: aiMeal.recipe.servings,
                        difficulty: aiMeal.recipe.difficulty,
                        ingredients: aiMeal.recipe.ingredients.map { Ingredient(name: $0.name, amount: $0.amount, category: $0.category) },
                        instructions: aiMeal.recipe.instructions,
                        explanation: aiMeal.recipe.explanation,
                        tags: aiMeal.recipe.tags,
                        cookingTips: aiMeal.recipe.cookingTips,
                        commonMistakes: aiMeal.recipe.commonMistakes,
                        visualCues: aiMeal.recipe.visualCues
                    ),
                    nutrition: NutritionInfo(
                        calories: aiMeal.nutrition.calories,
                        protein: aiMeal.nutrition.protein,
                        carbs: aiMeal.nutrition.carbs,
                        fat: aiMeal.nutrition.fat,
                        fiber: aiMeal.nutrition.fiber,
                        sugar: aiMeal.nutrition.sugar,
                        sodium: aiMeal.nutrition.sodium
                    ),
                    isDone: false
                )
            }
            
            let dailyPlan = DailyPlan(
                day: index + 1,
                date: aiDailyPlan.date,
                actualDate: actualDate,
                totalCalories: aiDailyPlan.totalCalories,
                meals: meals
            )
            dailyPlans.append(dailyPlan)
        }
        
        plan.dailyPlans = dailyPlans
        plan.summary = NutritionSummary(
            avgCaloriesPerDay: response.summary.avgCaloriesPerDay,
            avgProteinPerDay: response.summary.avgProteinPerDay,
            avgCarbsPerDay: response.summary.avgCarbsPerDay,
            avgFatPerDay: response.summary.avgFatPerDay,
            dietaryRestrictions: response.summary.dietaryRestrictions
        )
    }
    
    private func handlePartialSuccess(plan: DietPlan, missingFields: [String]) {
        plan.hasFilledData = true
        plan.filledDataDetails = missingFields.prefix(5).map { $0 }
        log("Partial success with \(missingFields.count) missing fields")
    }
    
    private func recordPlanGeneration(
        userId: String,
        planId: String,
        preferences: String,
        totalItems: Int
    ) async {
        let entry = PlanHistoryEntry(
            planId: planId,
            planType: .diet,
            preferences: preferences,
            completionRate: 0,
            completedItems: 0,
            totalItems: totalItems
        )
        
        do {
            try await PlanHistoryService.shared.addEntry(entry, userId: userId)
            log("Recorded diet plan generation in history")
        } catch {
            log("Failed to record plan in history: \(error)")
        }
    }
    
    private func mapError(_ error: Error) -> String {
        let appError = ErrorHandler.shared.handle(error, context: "DietPlanGeneration")
        return appError.userMessage
    }
    
    private func log(_ message: String) {
        appLog(message, category: .diet)
    }
}

struct ClarifyingQuestion: Identifiable, Codable, Hashable {
    let id: String
    let text: String
    let type: QuestionType
    let options: [String]?
    let hint: String?
    
    enum QuestionType: String, Codable {
        case singleLine = "single_line"
        case multiLine = "multi_line"
        case choice
    }
}

private struct ClarificationResponse: Decodable {
    let needsClarification: Bool
    let questions: [ClarifyingQuestion]?
    
    enum CodingKeys: String, CodingKey {
        case needsClarification = "needs_clarification"
        case questions
    }
}

private struct AIGeneratedDietPlanResponse: Decodable {
    let dailyPlans: [AIDailyPlan]
    let summary: AISummary
    
    enum CodingKeys: String, CodingKey {
        case dailyPlans = "daily_plans"
        case summary
    }
    
    struct AIDailyPlan: Decodable {
        let day: Int
        let date: String
        let totalCalories: Int
        let meals: [AIMeal]
        
        enum CodingKeys: String, CodingKey {
            case day, date
            case totalCalories = "total_calories"
            case meals
        }
    }
    
    struct AIMeal: Decodable {
        let type: MealType
        let recipe: AIRecipe
        let nutrition: AINutrition
    }
    
    struct AIRecipe: Decodable {
        let name: String
        let imageUrl: String?
        let prepTime: Int
        let servings: Int
        let difficulty: DifficultyLevel
        let ingredients: [AIIngredient]
        let instructions: [String]
        let explanation: String
        let tags: [String]
        let cookingTips: [String]
        let commonMistakes: [String]
        let visualCues: [String]
        
        enum CodingKeys: String, CodingKey {
            case name
            case imageUrl = "image_url"
            case prepTime = "prep_time"
            case servings, difficulty, ingredients, instructions, explanation, tags
            case cookingTips = "cooking_tips"
            case commonMistakes = "common_mistakes"
            case visualCues = "visual_cues"
        }
    }
    
    struct AIIngredient: Decodable {
        let name: String
        let amount: String
        let category: IngredientCategory
    }
    
    struct AINutrition: Decodable {
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
        let fiber: Int
        let sugar: Int
        let sodium: Int
    }
    
    struct AISummary: Decodable {
        let avgCaloriesPerDay: Int
        let avgProteinPerDay: Int
        let avgCarbsPerDay: Int
        let avgFatPerDay: Int
        let dietaryRestrictions: [String]
        
        enum CodingKeys: String, CodingKey {
            case avgCaloriesPerDay = "avg_calories_per_day"
            case avgProteinPerDay = "avg_protein_per_day"
            case avgCarbsPerDay = "avg_carbs_per_day"
            case avgFatPerDay = "avg_fat_per_day"
            case dietaryRestrictions = "dietary_restrictions"
        }
    }
}

private struct ValidationResult {
    let isValid: Bool
    let completeness: Double
    let missingFields: [String]
}

enum DietPlanGenerationError: LocalizedError {
    case insufficientData([String])
    case parsingFailed
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .insufficientData(let fields):
            return "Could not generate complete meal plan. Missing: \(fields.prefix(3).joined(separator: ", "))"
        case .parsingFailed:
            return "Failed to understand AI response. Please try again."
        case .networkError:
            return "Network error. Please check your connection."
        }
    }
}

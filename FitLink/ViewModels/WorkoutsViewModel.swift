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
    
    @Published var questionQueue: [FollowUpQuestion] = []
    @Published var currentQuestionIndex: Int = 0
    @Published var wizardAnswers: [String: AnswerValue] = [:]
    @Published var flowState: WizardFlowState = .idle
    @Published var isWizardVisible = false
    @Published var planSelection: PlanSelection?
    
    @Published var selectedDayIndex: Int = 0
    @Published var isLoadingPlans = false
    
    @Published var shareItems: [Any] = []
    @Published var isShowingShareSheet = false
    
    private let geminiService: GeminiAIService
    private let workoutPlanService = WorkoutPlanService.shared
    private var cancellables = Set<AnyCancellable>()
    private let maxRetryAttempts = 3
    
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
    
    var currentQuestion: FollowUpQuestion? {
        guard currentQuestionIndex < questionQueue.count else { return nil }
        return questionQueue[currentQuestionIndex]
    }
    
    // MARK: - UserDefaults Keys
    private enum PersistenceKeys {
        static let preferences = "workout_planner_preferences"
        static let questionQueue = "workout_planner_question_queue"
        static let currentQuestionIndex = "workout_planner_current_question_index"
        static let wizardAnswers = "workout_planner_wizard_answers"
        static let flowState = "workout_planner_flow_state"
        static let planSelection = "workout_planner_plan_selection"
        static let isWizardVisible = "workout_planner_is_wizard_visible"
    }
    
    init() {
        self.geminiService = GeminiAIService()
        self.hasSeenWorkoutOnboarding = UserDefaults.standard.bool(forKey: "workout_planner_onboarding_seen")
        
        restoreWizardState()
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
    
    func startWizard(fromPrompt prompt: String) async {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your workout preferences."
            return
        }
        
        preferences = prompt
        flowState = .fetchingQuestions
        isWizardVisible = true
        questionQueue = []
        currentQuestionIndex = 0
        wizardAnswers = [:]
        
        saveWizardState()
        
        do {
            let planTypes = planSelection?.planTypes ?? [.home, .gym]
            let clarifyingPrompt = WorkoutPromptBuilder.buildClarifyingQuestionsPrompt(
                userInput: prompt,
                planTypes: planTypes
            )
            
            let response = try await geminiService.askClarifyingQuestions(clarifyingPrompt)
            let jsonString = GeminiAIService.extractJSON(from: response)
            
            guard let data = jsonString.data(using: .utf8) else {
                throw WorkoutGenerationError.parsingFailed
            }
            
            let clarificationResponse = try JSONDecoder().decode(ClarificationResponse.self, from: data)
            
            if clarificationResponse.needsClarification, let questions = clarificationResponse.questions {
                questionQueue = questions
                flowState = .askingFollowUps
                saveWizardState()
            } else {
                clearWizardState()
                await startGeneration()
            }
        } catch {
            log("Error fetching clarifications: \(error)")
            clearWizardState()
            await startGeneration()
        }
    }
    
    func nextQuestion(withAnswer answer: AnswerValue) {
        guard let question = currentQuestion else { return }
        
        wizardAnswers[question.text] = answer
        
        if currentQuestionIndex < questionQueue.count - 1 {
            currentQuestionIndex += 1
        } else {
            finishWizard()
        }
        saveWizardState()
    }
    
    func skipCurrent() {
        if currentQuestionIndex < questionQueue.count - 1 {
            currentQuestionIndex += 1
        } else {
            finishWizard()
        }
        saveWizardState()
    }
    
    func finishWizard() {
        clearWizardState()
        Task {
            await startGeneration()
        }
    }
    
    func cancelWizard() {
        isWizardVisible = false
        flowState = .idle
        questionQueue = []
        currentQuestionIndex = 0
        wizardAnswers = [:]
        clearWizardState()
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
            isWizardVisible = false
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
            let prompt = WorkoutPromptBuilder.buildHomePlanPrompt(
                preferences: preferences,
                additionalContext: wizardAnswers
            )
            
            homeProgress = 0.3
            let response = try await geminiService.sendPrompt(
                prompt,
                systemPrompt: WorkoutPromptBuilder.systemPrompt
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
            
            homeProgress = 1.0
            homePlan = planWithDates
            homePlanDocument = doc
            
            log("Home plan generated successfully")
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
            let prompt = WorkoutPromptBuilder.buildGymPlanPrompt(
                preferences: preferences,
                additionalContext: wizardAnswers
            )
            
            gymProgress = 0.3
            let response = try await geminiService.sendPrompt(
                prompt,
                systemPrompt: WorkoutPromptBuilder.systemPrompt
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
            
            gymProgress = 1.0
            gymPlan = planWithDates
            gymPlanDocument = doc
            
            log("Gym plan generated successfully")
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
        questionQueue = []
        currentQuestionIndex = 0
        wizardAnswers = [:]
        flowState = .idle
        errorMessage = nil
        homeProgress = 0.0
        gymProgress = 0.0
        selectedDayIndex = 0
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
        questionQueue = []
        currentQuestionIndex = 0
        wizardAnswers = [:]
        flowState = .idle
        isWizardVisible = false
        clearWizardState()
    }
    
    private func saveWizardState() {
        UserDefaults.standard.set(preferences, forKey: PersistenceKeys.preferences)
        UserDefaults.standard.set(currentQuestionIndex, forKey: PersistenceKeys.currentQuestionIndex)
        UserDefaults.standard.set(isWizardVisible, forKey: PersistenceKeys.isWizardVisible)
        
        if let data = try? JSONEncoder().encode(questionQueue) {
            UserDefaults.standard.set(data, forKey: PersistenceKeys.questionQueue)
        }
        
        if let data = try? JSONEncoder().encode(wizardAnswers) {
            UserDefaults.standard.set(data, forKey: PersistenceKeys.wizardAnswers)
        }
        
        if let selection = planSelection {
            UserDefaults.standard.set(selection.rawValue, forKey: PersistenceKeys.planSelection)
        }
        
        let flowStateString: String
        switch flowState {
        case .idle: flowStateString = "idle"
        case .fetchingQuestions: flowStateString = "fetchingQuestions"
        case .askingFollowUps: flowStateString = "askingFollowUps"
        case .generatingPlan: flowStateString = "generatingPlan"
        case .planReady: flowStateString = "planReady"
        case .failed(let error): flowStateString = "failed:\(error)"
        }
        UserDefaults.standard.set(flowStateString, forKey: PersistenceKeys.flowState)
    }
    
    private func restoreWizardState() {
        if let savedPreferences = UserDefaults.standard.string(forKey: PersistenceKeys.preferences) {
            preferences = savedPreferences
        }
        
        currentQuestionIndex = UserDefaults.standard.integer(forKey: PersistenceKeys.currentQuestionIndex)
        isWizardVisible = UserDefaults.standard.bool(forKey: PersistenceKeys.isWizardVisible)
        
        if let data = UserDefaults.standard.data(forKey: PersistenceKeys.questionQueue),
           let questions = try? JSONDecoder().decode([FollowUpQuestion].self, from: data) {
            questionQueue = questions
        }
        
        if let data = UserDefaults.standard.data(forKey: PersistenceKeys.wizardAnswers),
           let answers = try? JSONDecoder().decode([String: AnswerValue].self, from: data) {
            wizardAnswers = answers
        }
        
        if let selectionRaw = UserDefaults.standard.string(forKey: PersistenceKeys.planSelection),
           let selection = PlanSelection(rawValue: selectionRaw) {
            planSelection = selection
        }
        
        if let flowStateString = UserDefaults.standard.string(forKey: PersistenceKeys.flowState) {
            if flowStateString == "askingFollowUps" && !questionQueue.isEmpty {
                flowState = .askingFollowUps
            } else {
                flowState = .idle
            }
        }
    }
    
    private func clearWizardState() {
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.preferences)
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.questionQueue)
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.currentQuestionIndex)
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.wizardAnswers)
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.flowState)
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.planSelection)
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.isWizardVisible)
    }
    
    private func mapError(_ error: Error) -> String {
        if let apiError = error as? GeminiAIService.APIError {
            return apiError.errorDescription ?? "An error occurred."
        }
        if let genError = error as? WorkoutGenerationError {
            return genError.errorDescription ?? "Failed to generate workout plan."
        }
        return "An unexpected error occurred. Please try again."
    }
    
    private func log(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [WorkoutsVM] \(message)")
        #endif
    }
}

private struct ClarificationResponse: Decodable {
    let needsClarification: Bool
    let questions: [FollowUpQuestion]?
    
    enum CodingKeys: String, CodingKey {
        case needsClarification = "needs_clarification"
        case questions
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

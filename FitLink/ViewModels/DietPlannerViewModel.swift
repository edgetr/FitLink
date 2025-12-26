import SwiftUI
import Combine
import EventKit
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

@MainActor
class DietPlannerViewModel: ObservableObject {
    
    @Published var currentDietPlan: DietPlan?
    @Published var allDietPlans: [DietPlan] = []
    @Published var selectedDayIndex: Int = 0
    @Published var isGenerating = false
    @Published var isLoadingPlans = false
    @Published var generationProgress: Double = 0.0
    @Published var hasGenerationFailed = false
    @Published var errorMessage: String?
    @Published var isOnline: Bool? = true
    @Published var preferences: String = ""
    
    @Published var pendingClarificationQuestions: [ClarifyingQuestion] = []
    @Published var clarificationAnswers: [String: String] = [:]
    @Published var isAwaitingClarifications = false
    @Published var isFetchingClarifications = false
    @Published var hasSeenOnboardingTip: Bool
    
    @Published var shareItems: [Any] = []
    @Published var isShowingShareSheet = false
    
    private let geminiService: GeminiAIService
    private let dietPlanService = DietPlanService.shared
    private let eventStore = EKEventStore()
    private var cancellables = Set<AnyCancellable>()
    private let maxRetryAttempts = 3
    private let partialSuccessThreshold = 0.7
    
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
        
        restoreQuestionState()
        restoreLastSelectedPlanId()
        
        Task {
            await requestNotificationPermission()
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
        
        isFetchingClarifications = true
        hasGenerationFailed = false
        errorMessage = nil
        
        do {
            let prompt = DietPlannerSystemPrompt.buildClarifyingQuestionsPrompt(userInput: preferences)
            let response = try await geminiService.askClarifyingQuestions(prompt)
            let jsonString = GeminiAIService.extractJSON(from: response)
            
            guard let data = jsonString.data(using: .utf8) else {
                throw GeminiAIService.APIError.parseError("Invalid response encoding")
            }
            
            let clarificationResponse = try JSONDecoder().decode(ClarificationResponse.self, from: data)
            
            if clarificationResponse.needsClarification, let questions = clarificationResponse.questions {
                pendingClarificationQuestions = questions
                isAwaitingClarifications = true
                saveQuestionState()
            } else {
                await generateDietPlan()
            }
        } catch {
            log("Error fetching clarifications: \(error)")
            await generateDietPlan()
        }
        
        isFetchingClarifications = false
    }
    
    func submitClarificationAnswers() async {
        isAwaitingClarifications = false
        
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
        
        await generateDietPlan()
    }
    
    func skipClarifications() {
        isAwaitingClarifications = false
        pendingClarificationQuestions = []
        clarificationAnswers = [:]
        clearQuestionState()
        
        Task {
            await generateDietPlan()
        }
    }
    
    func startOver() {
        preferences = ""
        pendingClarificationQuestions = []
        clarificationAnswers = [:]
        isAwaitingClarifications = false
        clearQuestionState()
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
        
        isGenerating = true
        hasGenerationFailed = false
        errorMessage = nil
        generationProgress = 0.0
        
        do {
            generationProgress = 0.1
            let pendingPlan = try await dietPlanService.createPendingPlan(userId: userId, preferences: preferences)
            currentDietPlan = pendingPlan
            
            generationProgress = 0.2
            try await dietPlanService.updateGenerationStatus(planId: pendingPlan.id, status: .generating, progress: 0.2)
            
            generationProgress = 0.3
            let userPrompt = DietPlannerSystemPrompt.buildUserPrompt(preferences: preferences)
            let response = try await geminiService.sendPrompt(userPrompt, systemPrompt: DietPlannerSystemPrompt.systemPrompt)
            
            generationProgress = 0.7
            let jsonString = GeminiAIService.extractJSON(from: response)
            
            guard let data = jsonString.data(using: .utf8) else {
                throw GeminiAIService.APIError.parseError("Invalid response encoding")
            }
            
            let aiResponse = try JSONDecoder().decode(AIGeneratedDietPlanResponse.self, from: data)
            
            generationProgress = 0.85
            let validationResult = validateDietPlanResponse(aiResponse)
            
            if validationResult.isValid || validationResult.completeness >= partialSuccessThreshold {
                populateDietPlan(pendingPlan, from: aiResponse)
                
                if !validationResult.isValid {
                    handlePartialSuccess(plan: pendingPlan, missingFields: validationResult.missingFields)
                }
                
                pendingPlan.generationStatus = validationResult.isValid ? .completed : .partialSuccess
                pendingPlan.generationProgress = 1.0
                
                generationProgress = 0.95
                try await dietPlanService.updatePlan(pendingPlan)
                
                generationProgress = 1.0
                currentDietPlan = pendingPlan
                
                if !allDietPlans.contains(where: { $0.id == pendingPlan.id }) {
                    allDietPlans.insert(pendingPlan, at: 0)
                }
                
                saveLastSelectedPlanId(pendingPlan.id)
                autoSelectTodayIndex()
            } else {
                pendingPlan.generationStatus = .failed
                try await dietPlanService.updatePlan(pendingPlan)
                throw DietPlanGenerationError.insufficientData(validationResult.missingFields)
            }
        } catch {
            log("Diet plan generation failed: \(error)")
            hasGenerationFailed = true
            errorMessage = mapError(error)
        }
        
        isGenerating = false
    }
    
    func loadAllDietPlansForUser() async {
        guard let userId = userId else { return }
        
        isLoadingPlans = true
        
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
        } catch {
            log("Error loading diet plans: \(error)")
            errorMessage = "Failed to load your meal plans."
        }
        
        isLoadingPlans = false
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
        isAwaitingClarifications = false
        hasGenerationFailed = false
        errorMessage = nil
        generationProgress = 0.0
        selectedDayIndex = 0
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
        
        dailyPlan.meals[mealIndex].isDone = newIsDone
        plan.dailyPlans[selectedDayIndex] = dailyPlan
        
        do {
            try await dietPlanService.markMealDone(
                planId: plan.id,
                dailyPlanIndex: selectedDayIndex,
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
            isAwaitingClarifications = !questions.isEmpty
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
    
    private func mapError(_ error: Error) -> String {
        if let apiError = error as? GeminiAIService.APIError {
            return apiError.errorDescription ?? "An error occurred."
        }
        if let genError = error as? DietPlanGenerationError {
            return genError.errorDescription ?? "Failed to generate meal plan."
        }
        return "An unexpected error occurred. Please try again."
    }
    
    private func log(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [DietPlannerVM] \(message)")
        #endif
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

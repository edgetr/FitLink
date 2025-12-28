import Foundation
import FirebaseFirestore
import Combine

// MARK: - Generation Status

enum GenerationStatus: String, Codable, CaseIterable {
    case pending
    case generating
    case completed
    case failed
    case partialSuccess
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .generating: return "Generating"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .partialSuccess: return "Partial Success"
        }
    }
    
    var isActive: Bool {
        self == .pending || self == .generating
    }
}

// MARK: - Difficulty Level

enum DifficultyLevel: String, Codable, CaseIterable {
    case easy
    case medium
    case hard
    
    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
    
    var icon: String {
        switch self {
        case .easy: return "leaf.fill"
        case .medium: return "flame.fill"
        case .hard: return "bolt.fill"
        }
    }
}

// MARK: - Ingredient Category

enum IngredientCategory: String, Codable, CaseIterable {
    case protein
    case vegetable
    case fruit
    case grain
    case dairy
    case fat
    case spice
    case condiment
    case liquid
    case other
    
    var displayName: String {
        switch self {
        case .protein: return "Protein"
        case .vegetable: return "Vegetable"
        case .fruit: return "Fruit"
        case .grain: return "Grain"
        case .dairy: return "Dairy"
        case .fat: return "Fat/Oil"
        case .spice: return "Spice"
        case .condiment: return "Condiment"
        case .liquid: return "Liquid"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .protein: return "🥩"
        case .vegetable: return "🥬"
        case .fruit: return "🍎"
        case .grain: return "🌾"
        case .dairy: return "🥛"
        case .fat: return "🫒"
        case .spice: return "🧂"
        case .condiment: return "🍯"
        case .liquid: return "💧"
        case .other: return "📦"
        }
    }
}

// MARK: - Meal Type

enum MealType: String, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack
    
    var icon: String {
        switch self {
        case .breakfast: return "🌅"
        case .lunch: return "☀️"
        case .dinner: return "🌙"
        case .snack: return "🍎"
        }
    }
    
    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .breakfast: return 0
        case .lunch: return 1
        case .snack: return 2
        case .dinner: return 3
        }
    }
}

// MARK: - Ingredient

struct Ingredient: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var amount: String
    var category: IngredientCategory
    
    init(id: UUID = UUID(), name: String, amount: String, category: IngredientCategory = .other) {
        self.id = id
        self.name = name
        self.amount = amount
        self.category = category
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case amount
        case category
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.amount = try container.decode(String.self, forKey: .amount)
        self.category = (try? container.decode(IngredientCategory.self, forKey: .category)) ?? .other
    }
}

// MARK: - Nutrition Info

struct NutritionInfo: Codable, Hashable {
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var fiber: Int
    var sugar: Int
    var sodium: Int
    
    init(calories: Int = 0, protein: Int = 0, carbs: Int = 0, fat: Int = 0, fiber: Int = 0, sugar: Int = 0, sodium: Int = 0) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.sodium = sodium
    }
    
    var totalMacros: Int {
        protein + carbs + fat
    }
    
    var proteinPercentage: Double {
        guard totalMacros > 0 else { return 0 }
        return Double(protein) / Double(totalMacros) * 100
    }
    
    var carbsPercentage: Double {
        guard totalMacros > 0 else { return 0 }
        return Double(carbs) / Double(totalMacros) * 100
    }
    
    var fatPercentage: Double {
        guard totalMacros > 0 else { return 0 }
        return Double(fat) / Double(totalMacros) * 100
    }
    
    var formattedSummary: String {
        "\(calories) cal • P: \(protein)g • C: \(carbs)g • F: \(fat)g"
    }
    
    static var empty: NutritionInfo {
        NutritionInfo()
    }
}

// MARK: - Nutrition Summary

struct NutritionSummary: Codable, Hashable {
    var avgCaloriesPerDay: Int
    var avgProteinPerDay: Int
    var avgCarbsPerDay: Int
    var avgFatPerDay: Int
    var dietaryRestrictions: [String]
    
    init(avgCaloriesPerDay: Int = 0, avgProteinPerDay: Int = 0, avgCarbsPerDay: Int = 0, avgFatPerDay: Int = 0, dietaryRestrictions: [String] = []) {
        self.avgCaloriesPerDay = avgCaloriesPerDay
        self.avgProteinPerDay = avgProteinPerDay
        self.avgCarbsPerDay = avgCarbsPerDay
        self.avgFatPerDay = avgFatPerDay
        self.dietaryRestrictions = dietaryRestrictions
    }
    
    var macroBreakdown: String {
        let totalMacros = avgProteinPerDay + avgCarbsPerDay + avgFatPerDay
        guard totalMacros > 0 else { return "N/A" }
        
        let proteinPct = Int(Double(avgProteinPerDay) / Double(totalMacros) * 100)
        let carbsPct = Int(Double(avgCarbsPerDay) / Double(totalMacros) * 100)
        let fatPct = Int(Double(avgFatPerDay) / Double(totalMacros) * 100)
        
        return "P: \(proteinPct)% • C: \(carbsPct)% • F: \(fatPct)%"
    }
    
    enum CodingKeys: String, CodingKey {
        case avgCaloriesPerDay = "avg_calories_per_day"
        case avgProteinPerDay = "avg_protein_per_day"
        case avgCarbsPerDay = "avg_carbs_per_day"
        case avgFatPerDay = "avg_fat_per_day"
        case dietaryRestrictions = "dietary_restrictions"
    }
    
    static var empty: NutritionSummary {
        NutritionSummary()
    }
}

// MARK: - Recipe

struct Recipe: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var imageUrl: String?
    var prepTime: Int
    var servings: Int
    var difficulty: DifficultyLevel
    var ingredients: [Ingredient]
    var instructions: [String]
    var explanation: String
    var tags: [String]
    var cookingTips: [String]
    var commonMistakes: [String]
    var visualCues: [String]
    
    init(
        id: UUID = UUID(),
        name: String,
        imageUrl: String? = nil,
        prepTime: Int = 30,
        servings: Int = 1,
        difficulty: DifficultyLevel = .medium,
        ingredients: [Ingredient] = [],
        instructions: [String] = [],
        explanation: String = "",
        tags: [String] = [],
        cookingTips: [String] = [],
        commonMistakes: [String] = [],
        visualCues: [String] = []
    ) {
        self.id = id
        self.name = name
        self.imageUrl = imageUrl
        self.prepTime = prepTime
        self.servings = servings
        self.difficulty = difficulty
        self.ingredients = ingredients
        self.instructions = instructions
        self.explanation = explanation
        self.tags = tags
        self.cookingTips = cookingTips
        self.commonMistakes = commonMistakes
        self.visualCues = visualCues
    }
    
    var formattedPrepTime: String {
        if prepTime >= 60 {
            let hours = prepTime / 60
            let minutes = prepTime % 60
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(prepTime) min"
    }
    
    func formattedForSharing() -> String {
        var text = "📖 \(name)\n"
        text += "⏱ \(formattedPrepTime) • 🍽 \(servings) serving(s)\n"
        text += "Difficulty: \(difficulty.displayName)\n\n"
        
        text += "📝 Ingredients:\n"
        for ingredient in ingredients {
            text += "• \(ingredient.amount) \(ingredient.name)\n"
        }
        
        text += "\n👨‍🍳 Instructions:\n"
        for (index, instruction) in instructions.enumerated() {
            text += "\(index + 1). \(instruction)\n"
        }
        
        if !cookingTips.isEmpty {
            text += "\n💡 Tips:\n"
            for tip in cookingTips {
                text += "• \(tip)\n"
            }
        }
        
        return text
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case imageUrl = "image_url"
        case prepTime = "prep_time"
        case servings
        case difficulty
        case ingredients
        case instructions
        case explanation
        case tags
        case cookingTips = "cooking_tips"
        case commonMistakes = "common_mistakes"
        case visualCues = "visual_cues"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.imageUrl = try? container.decode(String.self, forKey: .imageUrl)
        self.prepTime = (try? container.decode(Int.self, forKey: .prepTime)) ?? 30
        self.servings = (try? container.decode(Int.self, forKey: .servings)) ?? 1
        self.difficulty = (try? container.decode(DifficultyLevel.self, forKey: .difficulty)) ?? .medium
        self.ingredients = (try? container.decode([Ingredient].self, forKey: .ingredients)) ?? []
        self.instructions = (try? container.decode([String].self, forKey: .instructions)) ?? []
        self.explanation = (try? container.decode(String.self, forKey: .explanation)) ?? ""
        self.tags = (try? container.decode([String].self, forKey: .tags)) ?? []
        self.cookingTips = (try? container.decode([String].self, forKey: .cookingTips)) ?? []
        self.commonMistakes = (try? container.decode([String].self, forKey: .commonMistakes)) ?? []
        self.visualCues = (try? container.decode([String].self, forKey: .visualCues)) ?? []
    }
}

// MARK: - Meal

struct Meal: Identifiable, Codable, Hashable {
    var id: UUID
    var type: MealType
    var recipe: Recipe
    var nutrition: NutritionInfo
    var isDone: Bool
    
    init(
        id: UUID = UUID(),
        type: MealType,
        recipe: Recipe,
        nutrition: NutritionInfo = .empty,
        isDone: Bool = false
    ) {
        self.id = id
        self.type = type
        self.recipe = recipe
        self.nutrition = nutrition
        self.isDone = isDone
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case recipe
        case nutrition
        case isDone = "is_done"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.type = try container.decode(MealType.self, forKey: .type)
        self.recipe = try container.decode(Recipe.self, forKey: .recipe)
        self.nutrition = (try? container.decode(NutritionInfo.self, forKey: .nutrition)) ?? .empty
        self.isDone = (try? container.decode(Bool.self, forKey: .isDone)) ?? false
    }
}

// MARK: - Daily Plan

struct DailyPlan: Identifiable, Codable, Hashable {
    var id: UUID
    var day: Int
    var date: String
    var actualDate: Date?
    var totalCalories: Int
    var meals: [Meal]
    
    init(
        id: UUID = UUID(),
        day: Int,
        date: String = "",
        actualDate: Date? = nil,
        totalCalories: Int = 0,
        meals: [Meal] = []
    ) {
        self.id = id
        self.day = day
        self.date = date
        self.actualDate = actualDate
        self.totalCalories = totalCalories
        self.meals = meals
    }
    
    var formattedDate: String {
        guard let actualDate = actualDate else {
            return date
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: actualDate)
    }
    
    var formattedShortDate: String {
        guard let actualDate = actualDate else {
            return date
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: actualDate)
    }
    
    var dayOfWeek: String {
        guard let actualDate = actualDate else {
            return "Day \(day)"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: actualDate)
    }
    
    var sortedMeals: [Meal] {
        meals.sorted { $0.type.sortOrder < $1.type.sortOrder }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case day
        case date
        case actualDate = "actual_date"
        case totalCalories = "total_calories"
        case meals
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.day = try container.decode(Int.self, forKey: .day)
        self.date = (try? container.decode(String.self, forKey: .date)) ?? ""
        self.actualDate = try? container.decode(Date.self, forKey: .actualDate)
        self.totalCalories = (try? container.decode(Int.self, forKey: .totalCalories)) ?? 0
        self.meals = (try? container.decode([Meal].self, forKey: .meals)) ?? []
    }
}

// MARK: - Diet Plan

class DietPlan: ObservableObject, Identifiable, Codable {
    var id: String
    var userId: String
    var planId: String
    var preferences: String
    var totalDays: Int
    @Published var dailyPlans: [DailyPlan]
    var summary: NutritionSummary
    var createdAt: Date
    var lastUpdated: Date
    var weekStartDate: Date
    var weekEndDate: Date
    var isArchived: Bool
    var archivedAt: Date?
    @Published var generationStatus: GenerationStatus
    @Published var generationProgress: Double
    var generationRequestId: String?
    var hasFilledData: Bool
    var filledDataDetails: [String]
    var isShared: Bool
    var sharedWith: [String]
    var shareId: String?
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        planId: String = UUID().uuidString,
        preferences: String = "",
        totalDays: Int = 7,
        dailyPlans: [DailyPlan] = [],
        summary: NutritionSummary = .empty,
        createdAt: Date = Date(),
        lastUpdated: Date = Date(),
        weekStartDate: Date = Date(),
        weekEndDate: Date = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date(),
        isArchived: Bool = false,
        archivedAt: Date? = nil,
        generationStatus: GenerationStatus = .pending,
        generationProgress: Double = 0.0,
        generationRequestId: String? = nil,
        hasFilledData: Bool = false,
        filledDataDetails: [String] = [],
        isShared: Bool = false,
        sharedWith: [String] = [],
        shareId: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.planId = planId
        self.preferences = preferences
        self.totalDays = totalDays
        self.dailyPlans = dailyPlans
        self.summary = summary
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
        self.weekStartDate = weekStartDate
        self.weekEndDate = weekEndDate
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.generationStatus = generationStatus
        self.generationProgress = generationProgress
        self.generationRequestId = generationRequestId
        self.hasFilledData = hasFilledData
        self.filledDataDetails = filledDataDetails
        self.isShared = isShared
        self.sharedWith = sharedWith
        self.shareId = shareId
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case planId = "plan_id"
        case preferences
        case totalDays = "total_days"
        case dailyPlans = "daily_plans"
        case summary
        case createdAt = "created_at"
        case lastUpdated = "last_updated"
        case weekStartDate = "week_start_date"
        case weekEndDate = "week_end_date"
        case isArchived = "is_archived"
        case archivedAt = "archived_at"
        case generationStatus = "generation_status"
        case generationProgress = "generation_progress"
        case generationRequestId = "generation_request_id"
        case hasFilledData = "has_filled_data"
        case filledDataDetails = "filled_data_details"
        case isShared = "is_shared"
        case sharedWith = "shared_with"
        case shareId = "share_id"
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        planId = try container.decode(String.self, forKey: .planId)
        preferences = try container.decode(String.self, forKey: .preferences)
        totalDays = try container.decode(Int.self, forKey: .totalDays)
        dailyPlans = try container.decode([DailyPlan].self, forKey: .dailyPlans)
        summary = try container.decode(NutritionSummary.self, forKey: .summary)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        weekStartDate = try container.decode(Date.self, forKey: .weekStartDate)
        weekEndDate = try container.decode(Date.self, forKey: .weekEndDate)
        isArchived = try container.decode(Bool.self, forKey: .isArchived)
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
        generationStatus = try container.decode(GenerationStatus.self, forKey: .generationStatus)
        generationProgress = try container.decode(Double.self, forKey: .generationProgress)
        generationRequestId = try container.decodeIfPresent(String.self, forKey: .generationRequestId)
        hasFilledData = try container.decode(Bool.self, forKey: .hasFilledData)
        filledDataDetails = try container.decode([String].self, forKey: .filledDataDetails)
        isShared = try container.decode(Bool.self, forKey: .isShared)
        sharedWith = try container.decode([String].self, forKey: .sharedWith)
        shareId = try container.decodeIfPresent(String.self, forKey: .shareId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(planId, forKey: .planId)
        try container.encode(preferences, forKey: .preferences)
        try container.encode(totalDays, forKey: .totalDays)
        try container.encode(dailyPlans, forKey: .dailyPlans)
        try container.encode(summary, forKey: .summary)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastUpdated, forKey: .lastUpdated)
        try container.encode(weekStartDate, forKey: .weekStartDate)
        try container.encode(weekEndDate, forKey: .weekEndDate)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encodeIfPresent(archivedAt, forKey: .archivedAt)
        try container.encode(generationStatus, forKey: .generationStatus)
        try container.encode(generationProgress, forKey: .generationProgress)
        try container.encodeIfPresent(generationRequestId, forKey: .generationRequestId)
        try container.encode(hasFilledData, forKey: .hasFilledData)
        try container.encode(filledDataDetails, forKey: .filledDataDetails)
        try container.encode(isShared, forKey: .isShared)
        try container.encode(sharedWith, forKey: .sharedWith)
        try container.encodeIfPresent(shareId, forKey: .shareId)
    }
    
    // MARK: - Computed Properties
    
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: createdAt)
    }
    
    var formattedWeekRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startStr = formatter.string(from: weekStartDate)
        let endStr = formatter.string(from: weekEndDate)
        return "\(startStr) - \(endStr)"
    }
    
    var isCurrentWeek: Bool {
        let now = Date()
        return now >= weekStartDate && now <= weekEndDate
    }
    
    var shouldArchive: Bool {
        let now = Date()
        return now > weekEndDate && !isArchived
    }
    
    // MARK: - Methods
    
    func formattedForSharing() -> String {
        var text = "🍽 FitLink Diet Plan\n"
        text += "📅 \(formattedWeekRange)\n"
        text += "📊 \(summary.avgCaloriesPerDay) cal/day average\n\n"
        
        for dailyPlan in dailyPlans {
            text += "━━━━━━━━━━━━━━━━━━━━\n"
            text += "📆 \(dailyPlan.formattedDate)\n"
            text += "Total: \(dailyPlan.totalCalories) calories\n\n"
            
            for meal in dailyPlan.sortedMeals {
                text += "\(meal.type.icon) \(meal.type.displayName): \(meal.recipe.name)\n"
                text += "   \(meal.nutrition.calories) cal\n"
            }
            text += "\n"
        }
        
        return text
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "user_id": userId,
            "plan_id": planId,
            "preferences": preferences,
            "total_days": totalDays,
            "created_at": Timestamp(date: createdAt),
            "last_updated": Timestamp(date: lastUpdated),
            "week_start_date": Timestamp(date: weekStartDate),
            "week_end_date": Timestamp(date: weekEndDate),
            "is_archived": isArchived,
            "generation_status": generationStatus.rawValue,
            "generation_progress": generationProgress,
            "has_filled_data": hasFilledData,
            "filled_data_details": filledDataDetails,
            "is_shared": isShared,
            "shared_with": sharedWith
        ]
        
        if let archivedAt = archivedAt {
            dict["archived_at"] = Timestamp(date: archivedAt)
        }
        
        if let generationRequestId = generationRequestId {
            dict["generation_request_id"] = generationRequestId
        }
        
        if let shareId = shareId {
            dict["share_id"] = shareId
        }
        
        var dailyPlansMap: [String: Any] = [:]
        for dailyPlan in dailyPlans {
            dailyPlansMap["day_\(dailyPlan.day)"] = dailyPlan.toFirestoreMap()
        }
        dict["daily_plans"] = dailyPlansMap
        
        dict["summary"] = summary.toFirestoreMap()
        
        return dict
    }
    
    static func fromDictionary(_ data: [String: Any], id: String) -> DietPlan? {
        guard let userId = data["user_id"] as? String else { return nil }
        
        let plan = DietPlan(
            id: id,
            userId: userId,
            planId: data["plan_id"] as? String ?? id,
            preferences: data["preferences"] as? String ?? "",
            totalDays: data["total_days"] as? Int ?? 7
        )
        
        if let createdAt = (data["created_at"] as? Timestamp)?.dateValue() {
            plan.createdAt = createdAt
        }
        if let lastUpdated = (data["last_updated"] as? Timestamp)?.dateValue() {
            plan.lastUpdated = lastUpdated
        }
        if let weekStartDate = (data["week_start_date"] as? Timestamp)?.dateValue() {
            plan.weekStartDate = weekStartDate
        }
        if let weekEndDate = (data["week_end_date"] as? Timestamp)?.dateValue() {
            plan.weekEndDate = weekEndDate
        }
        if let archivedAt = (data["archived_at"] as? Timestamp)?.dateValue() {
            plan.archivedAt = archivedAt
        }
        
        plan.isArchived = data["is_archived"] as? Bool ?? false
        plan.generationProgress = data["generation_progress"] as? Double ?? 0.0
        plan.generationRequestId = data["generation_request_id"] as? String
        plan.hasFilledData = data["has_filled_data"] as? Bool ?? false
        plan.filledDataDetails = data["filled_data_details"] as? [String] ?? []
        plan.isShared = data["is_shared"] as? Bool ?? false
        plan.sharedWith = data["shared_with"] as? [String] ?? []
        plan.shareId = data["share_id"] as? String
        
        if let statusRaw = data["generation_status"] as? String,
           let status = GenerationStatus(rawValue: statusRaw) {
            plan.generationStatus = status
        }
        
        if let dailyPlansMap = data["daily_plans"] as? [String: [String: Any]] {
            plan.dailyPlans = dailyPlansMap.values
                .compactMap { DailyPlan.fromFirestoreMap($0) }
                .sorted { $0.day < $1.day }
        } else if let dailyPlansJSON = data["daily_plans_json"] as? String,
           let dailyPlansData = dailyPlansJSON.data(using: .utf8),
           let dailyPlans = try? JSONDecoder().decode([DailyPlan].self, from: dailyPlansData) {
            plan.dailyPlans = dailyPlans
        }
        
        if let summaryMap = data["summary"] as? [String: Any] {
            plan.summary = NutritionSummary.fromFirestoreMap(summaryMap)
        } else if let summaryJSON = data["summary_json"] as? String,
           let summaryData = summaryJSON.data(using: .utf8),
           let summary = try? JSONDecoder().decode(NutritionSummary.self, from: summaryData) {
            plan.summary = summary
        }
        
        return plan
    }
    
    // MARK: - Sample Data
    
    static var sample: DietPlan {
        let sampleRecipe = Recipe(
            name: "Overnight Oats with Berries",
            prepTime: 10,
            servings: 1,
            difficulty: .easy,
            ingredients: [
                Ingredient(name: "Rolled Oats", amount: "1/2 cup", category: .grain),
                Ingredient(name: "Almond Milk", amount: "1/2 cup", category: .dairy),
                Ingredient(name: "Greek Yogurt", amount: "1/4 cup", category: .dairy),
                Ingredient(name: "Mixed Berries", amount: "1/2 cup", category: .fruit),
                Ingredient(name: "Honey", amount: "1 tbsp", category: .condiment)
            ],
            instructions: [
                "Combine oats, almond milk, and yogurt in a jar",
                "Stir well and refrigerate overnight",
                "Top with berries and honey before serving"
            ],
            explanation: "A nutritious, fiber-rich breakfast that requires no morning cooking.",
            tags: ["quick", "high-fiber", "meal-prep"],
            cookingTips: ["Use ripe berries for natural sweetness"],
            commonMistakes: ["Using too little liquid makes oats too thick"],
            visualCues: ["Oats should be creamy, not dry"]
        )
        
        let sampleMeal = Meal(
            type: .breakfast,
            recipe: sampleRecipe,
            nutrition: NutritionInfo(calories: 350, protein: 12, carbs: 55, fat: 8, fiber: 6, sugar: 18, sodium: 120)
        )
        
        let sampleDailyPlan = DailyPlan(
            day: 1,
            date: "2024-12-24",
            actualDate: Date(),
            totalCalories: 2000,
            meals: [sampleMeal]
        )
        
        return DietPlan(
            userId: "sample-user",
            dailyPlans: [sampleDailyPlan],
            summary: NutritionSummary(
                avgCaloriesPerDay: 2000,
                avgProteinPerDay: 100,
                avgCarbsPerDay: 250,
                avgFatPerDay: 70,
                dietaryRestrictions: []
            ),
            generationStatus: .completed
        )
    }
}

// MARK: - Firestore Persistence Extensions

extension Ingredient {
    func toFirestoreMap() -> [String: Any] {
        return [
            "id": id.uuidString,
            "name": name,
            "amount": amount,
            "category": category.rawValue
        ]
    }
    
    static func fromFirestoreMap(_ data: [String: Any]) -> Ingredient? {
        guard let name = data["name"] as? String,
              let amount = data["amount"] as? String else { return nil }
        
        let id = (data["id"] as? String).flatMap { UUID(uuidString: $0) } ?? UUID()
        let category = (data["category"] as? String).flatMap { IngredientCategory(rawValue: $0) } ?? .other
        
        return Ingredient(id: id, name: name, amount: amount, category: category)
    }
}

extension NutritionInfo {
    func toFirestoreMap() -> [String: Any] {
        return [
            "calories": calories,
            "protein": protein,
            "carbs": carbs,
            "fat": fat,
            "fiber": fiber,
            "sugar": sugar,
            "sodium": sodium
        ]
    }
    
    static func fromFirestoreMap(_ data: [String: Any]) -> NutritionInfo {
        return NutritionInfo(
            calories: data["calories"] as? Int ?? 0,
            protein: data["protein"] as? Int ?? 0,
            carbs: data["carbs"] as? Int ?? 0,
            fat: data["fat"] as? Int ?? 0,
            fiber: data["fiber"] as? Int ?? 0,
            sugar: data["sugar"] as? Int ?? 0,
            sodium: data["sodium"] as? Int ?? 0
        )
    }
}

extension NutritionSummary {
    func toFirestoreMap() -> [String: Any] {
        return [
            "avg_calories_per_day": avgCaloriesPerDay,
            "avg_protein_per_day": avgProteinPerDay,
            "avg_carbs_per_day": avgCarbsPerDay,
            "avg_fat_per_day": avgFatPerDay,
            "dietary_restrictions": dietaryRestrictions
        ]
    }
    
    static func fromFirestoreMap(_ data: [String: Any]) -> NutritionSummary {
        return NutritionSummary(
            avgCaloriesPerDay: data["avg_calories_per_day"] as? Int ?? 0,
            avgProteinPerDay: data["avg_protein_per_day"] as? Int ?? 0,
            avgCarbsPerDay: data["avg_carbs_per_day"] as? Int ?? 0,
            avgFatPerDay: data["avg_fat_per_day"] as? Int ?? 0,
            dietaryRestrictions: data["dietary_restrictions"] as? [String] ?? []
        )
    }
}

extension Recipe {
    func toFirestoreMap() -> [String: Any] {
        var map: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "prep_time": prepTime,
            "servings": servings,
            "difficulty": difficulty.rawValue,
            "ingredients": ingredients.map { $0.toFirestoreMap() },
            "instructions": instructions,
            "explanation": explanation,
            "tags": tags,
            "cooking_tips": cookingTips,
            "common_mistakes": commonMistakes,
            "visual_cues": visualCues
        ]
        if let imageUrl = imageUrl {
            map["image_url"] = imageUrl
        }
        return map
    }
    
    static func fromFirestoreMap(_ data: [String: Any]) -> Recipe? {
        guard let name = data["name"] as? String else { return nil }
        
        let id = (data["id"] as? String).flatMap { UUID(uuidString: $0) } ?? UUID()
        let ingredientsData = data["ingredients"] as? [[String: Any]] ?? []
        let ingredients = ingredientsData.compactMap { Ingredient.fromFirestoreMap($0) }
        let difficulty = (data["difficulty"] as? String).flatMap { DifficultyLevel(rawValue: $0) } ?? .medium
        
        return Recipe(
            id: id,
            name: name,
            imageUrl: data["image_url"] as? String,
            prepTime: data["prep_time"] as? Int ?? 30,
            servings: data["servings"] as? Int ?? 1,
            difficulty: difficulty,
            ingredients: ingredients,
            instructions: data["instructions"] as? [String] ?? [],
            explanation: data["explanation"] as? String ?? "",
            tags: data["tags"] as? [String] ?? [],
            cookingTips: data["cooking_tips"] as? [String] ?? [],
            commonMistakes: data["common_mistakes"] as? [String] ?? [],
            visualCues: data["visual_cues"] as? [String] ?? []
        )
    }
}

extension Meal {
    func toFirestoreMap() -> [String: Any] {
        return [
            "id": id.uuidString,
            "type": type.rawValue,
            "recipe": recipe.toFirestoreMap(),
            "nutrition": nutrition.toFirestoreMap(),
            "is_done": isDone
        ]
    }
    
    static func fromFirestoreMap(_ data: [String: Any]) -> Meal? {
        guard let typeRaw = data["type"] as? String,
              let type = MealType(rawValue: typeRaw),
              let recipeData = data["recipe"] as? [String: Any],
              let recipe = Recipe.fromFirestoreMap(recipeData) else { return nil }
        
        let id = (data["id"] as? String).flatMap { UUID(uuidString: $0) } ?? UUID()
        let nutritionData = data["nutrition"] as? [String: Any] ?? [:]
        let nutrition = NutritionInfo.fromFirestoreMap(nutritionData)
        let isDone = data["is_done"] as? Bool ?? false
        
        return Meal(id: id, type: type, recipe: recipe, nutrition: nutrition, isDone: isDone)
    }
}

extension DailyPlan {
    func toFirestoreMap() -> [String: Any] {
        var map: [String: Any] = [
            "id": id.uuidString,
            "day": day,
            "date": date,
            "total_calories": totalCalories
        ]
        
        // Store meals as a map keyed by meal ID for atomic updates
        var mealsMap: [String: Any] = [:]
        for meal in meals {
            mealsMap[meal.id.uuidString] = meal.toFirestoreMap()
        }
        map["meals"] = mealsMap
        
        if let actualDate = actualDate {
            map["actual_date"] = Timestamp(date: actualDate)
        }
        
        return map
    }
    
    static func fromFirestoreMap(_ data: [String: Any]) -> DailyPlan? {
        guard let day = data["day"] as? Int else { return nil }
        
        let id = (data["id"] as? String).flatMap { UUID(uuidString: $0) } ?? UUID()
        
        // Support both map format (new) and array format (legacy)
        var meals: [Meal] = []
        if let mealsMap = data["meals"] as? [String: [String: Any]] {
            // New map format - meals keyed by ID
            meals = mealsMap.values.compactMap { Meal.fromFirestoreMap($0) }
        } else if let mealsArray = data["meals"] as? [[String: Any]] {
            // Legacy array format
            meals = mealsArray.compactMap { Meal.fromFirestoreMap($0) }
        }
        
        var actualDate: Date?
        if let timestamp = data["actual_date"] as? Timestamp {
            actualDate = timestamp.dateValue()
        }
        
        return DailyPlan(
            id: id,
            day: day,
            date: data["date"] as? String ?? "",
            actualDate: actualDate,
            totalCalories: data["total_calories"] as? Int ?? 0,
            meals: meals.sorted { $0.type.sortOrder < $1.type.sortOrder }
        )
    }
}

// MARK: - Additional Diet Info

struct AdditionalDietInfo: Codable {
    var calorieGoal: Int?
    var mealPrepTime: String?
    var budget: String?
    var cookingSkill: String?
    var allergies: [String]
    var dislikedFoods: [String]
    
    init(
        calorieGoal: Int? = nil,
        mealPrepTime: String? = nil,
        budget: String? = nil,
        cookingSkill: String? = nil,
        allergies: [String] = [],
        dislikedFoods: [String] = []
    ) {
        self.calorieGoal = calorieGoal
        self.mealPrepTime = mealPrepTime
        self.budget = budget
        self.cookingSkill = cookingSkill
        self.allergies = allergies
        self.dislikedFoods = dislikedFoods
    }
    
    enum CodingKeys: String, CodingKey {
        case calorieGoal = "calorie_goal"
        case mealPrepTime = "meal_prep_time"
        case budget
        case cookingSkill = "cooking_skill"
        case allergies
        case dislikedFoods = "disliked_foods"
    }
}

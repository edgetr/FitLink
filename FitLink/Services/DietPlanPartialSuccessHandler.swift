//
//  DietPlanPartialSuccessHandler.swift
//  FitLink
//
//  Created on 25.12.2025.
//

import Foundation

struct DietPlanPartialSuccessHandler {
    
    struct HandlerResult {
        let success: Bool
        let plan: DietPlan?
        let filledFields: [String]
        let message: String
    }
    
    static let acceptableCompletenessThreshold = 0.70
    
    static let defaultCaloriesPerMeal: [MealType: Int] = [
        .breakfast: 400,
        .lunch: 600,
        .dinner: 700,
        .snack: 200
    ]
    
    static let defaultMacroRatios = (protein: 0.25, carbs: 0.45, fat: 0.30)
    
    static func handlePartialResponse(_ jsonString: String, userId: String, preferences: String) -> HandlerResult {
        let analysis = ResponseStructureAnalyzer.analyzeDietPlanResponse(jsonString)
        
        if analysis.completenessPercentage < acceptableCompletenessThreshold * 100 {
            return HandlerResult(
                success: false,
                plan: nil,
                filledFields: [],
                message: "Response too incomplete (\(Int(analysis.completenessPercentage))% complete). Please try again."
            )
        }
        
        guard let rawData = analysis.rawData else {
            return HandlerResult(
                success: false,
                plan: nil,
                filledFields: [],
                message: "Unable to parse response data"
            )
        }
        
        var filledFields = [String]()
        
        let plan = buildPlanWithDefaults(
            from: rawData,
            userId: userId,
            preferences: preferences,
            filledFields: &filledFields
        )
        
        plan.hasFilledData = !filledFields.isEmpty
        plan.filledDataDetails = filledFields
        plan.generationStatus = filledFields.isEmpty ? .completed : .partialSuccess
        
        return HandlerResult(
            success: true,
            plan: plan,
            filledFields: filledFields,
            message: filledFields.isEmpty
                ? "Plan generated successfully"
                : "Plan generated with \(filledFields.count) fields filled with defaults"
        )
    }
    
    private static func buildPlanWithDefaults(
        from data: [String: Any],
        userId: String,
        preferences: String,
        filledFields: inout [String]
    ) -> DietPlan {
        let plan = DietPlan(userId: userId, preferences: preferences)
        
        if let dailyPlansData = data["daily_plans"] as? [[String: Any]] {
            plan.dailyPlans = dailyPlansData.enumerated().map { index, dayData in
                buildDailyPlanWithDefaults(from: dayData, dayIndex: index, filledFields: &filledFields)
            }
        } else {
            filledFields.append("daily_plans (created 7 default days)")
            plan.dailyPlans = (1...7).map { day in
                createDefaultDailyPlan(day: day)
            }
        }
        
        plan.totalDays = plan.dailyPlans.count
        
        if let summaryData = data["summary"] as? [String: Any] {
            plan.summary = buildSummaryWithDefaults(from: summaryData, dailyPlans: plan.dailyPlans, filledFields: &filledFields)
        } else {
            filledFields.append("summary (calculated from meals)")
            plan.summary = calculateSummary(from: plan.dailyPlans)
        }
        
        return plan
    }
    
    private static func buildDailyPlanWithDefaults(
        from data: [String: Any],
        dayIndex: Int,
        filledFields: inout [String]
    ) -> DailyPlan {
        let day = (data["day"] as? Int) ?? (dayIndex + 1)
        let dateString = data["date"] as? String ?? ""
        
        var meals: [Meal]
        if let mealsData = data["meals"] as? [[String: Any]] {
            meals = mealsData.map { mealData in
                buildMealWithDefaults(from: mealData, dayIndex: dayIndex, filledFields: &filledFields)
            }
        } else {
            filledFields.append("Day \(day) meals (created defaults)")
            meals = createDefaultMeals()
        }
        
        var totalCalories = data["total_calories"] as? Int ?? 0
        if totalCalories == 0 {
            totalCalories = meals.reduce(0) { $0 + $1.nutrition.calories }
            if totalCalories == 0 {
                totalCalories = 2000
                filledFields.append("Day \(day) totalCalories (default 2000)")
            }
        }
        
        let actualDate = Calendar.current.date(byAdding: .day, value: dayIndex, to: Date())
        
        return DailyPlan(
            day: day,
            date: dateString,
            actualDate: actualDate,
            totalCalories: totalCalories,
            meals: meals
        )
    }
    
    private static func buildMealWithDefaults(
        from data: [String: Any],
        dayIndex: Int,
        filledFields: inout [String]
    ) -> Meal {
        let typeString = (data["type"] as? String) ?? "lunch"
        let type = MealType(rawValue: typeString.lowercased()) ?? .lunch
        
        let recipe: Recipe
        if let recipeData = data["recipe"] as? [String: Any] {
            recipe = buildRecipeWithDefaults(from: recipeData, mealType: type, filledFields: &filledFields)
        } else {
            filledFields.append("\(type.displayName) recipe (placeholder)")
            recipe = createPlaceholderRecipe(for: type)
        }
        
        let nutrition: NutritionInfo
        if let nutritionData = data["nutrition"] as? [String: Any] {
            nutrition = buildNutritionWithDefaults(from: nutritionData, mealType: type, filledFields: &filledFields)
        } else {
            filledFields.append("\(type.displayName) nutrition (estimated)")
            nutrition = createDefaultNutrition(for: type)
        }
        
        let isDone = data["is_done"] as? Bool ?? false
        
        return Meal(type: type, recipe: recipe, nutrition: nutrition, isDone: isDone)
    }
    
    private static func buildRecipeWithDefaults(
        from data: [String: Any],
        mealType: MealType,
        filledFields: inout [String]
    ) -> Recipe {
        var name = data["name"] as? String ?? ""
        if name.isEmpty {
            name = "Untitled \(mealType.displayName)"
            filledFields.append("\(mealType.displayName) recipe name")
        }
        
        var ingredients: [Ingredient]
        if let ingredientsData = data["ingredients"] as? [[String: Any]] {
            ingredients = ingredientsData.map { ingData in
                Ingredient(
                    name: ingData["name"] as? String ?? "Unknown ingredient",
                    amount: ingData["amount"] as? String ?? "As needed",
                    category: .other
                )
            }
        } else {
            ingredients = [Ingredient(name: "Ingredients not specified", amount: "As needed", category: .other)]
            filledFields.append("\(mealType.displayName) ingredients")
        }
        
        var instructions: [String]
        if let instructionsData = data["instructions"] as? [String], !instructionsData.isEmpty {
            instructions = instructionsData
        } else {
            instructions = ["Follow standard preparation for this dish."]
            filledFields.append("\(mealType.displayName) instructions")
        }
        
        let prepTime = data["prep_time"] as? Int ?? 30
        let servings = data["servings"] as? Int ?? 1
        let difficultyStr = data["difficulty"] as? String ?? "medium"
        let difficulty = DifficultyLevel(rawValue: difficultyStr.lowercased()) ?? .medium
        
        return Recipe(
            name: name,
            imageUrl: data["image_url"] as? String,
            prepTime: prepTime,
            servings: servings,
            difficulty: difficulty,
            ingredients: ingredients,
            instructions: instructions,
            explanation: data["explanation"] as? String ?? "",
            tags: data["tags"] as? [String] ?? [],
            cookingTips: data["cooking_tips"] as? [String] ?? [],
            commonMistakes: data["common_mistakes"] as? [String] ?? [],
            visualCues: data["visual_cues"] as? [String] ?? []
        )
    }
    
    private static func buildNutritionWithDefaults(
        from data: [String: Any],
        mealType: MealType,
        filledFields: inout [String]
    ) -> NutritionInfo {
        let defaultCals = defaultCaloriesPerMeal[mealType] ?? 500
        
        var calories = data["calories"] as? Int ?? 0
        if calories == 0 {
            calories = defaultCals
            filledFields.append("\(mealType.displayName) calories")
        }
        
        var protein = data["protein"] as? Int ?? 0
        var carbs = data["carbs"] as? Int ?? 0
        var fat = data["fat"] as? Int ?? 0
        
        if protein == 0 && carbs == 0 && fat == 0 {
            protein = Int(Double(calories) * defaultMacroRatios.protein / 4)
            carbs = Int(Double(calories) * defaultMacroRatios.carbs / 4)
            fat = Int(Double(calories) * defaultMacroRatios.fat / 9)
            filledFields.append("\(mealType.displayName) macros")
        }
        
        return NutritionInfo(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: data["fiber"] as? Int ?? 5,
            sugar: data["sugar"] as? Int ?? 10,
            sodium: data["sodium"] as? Int ?? 500
        )
    }
    
    private static func buildSummaryWithDefaults(
        from data: [String: Any],
        dailyPlans: [DailyPlan],
        filledFields: inout [String]
    ) -> NutritionSummary {
        var avgCalories = data["avg_calories_per_day"] as? Int ?? 0
        var avgProtein = data["avg_protein_per_day"] as? Int ?? 0
        var avgCarbs = data["avg_carbs_per_day"] as? Int ?? 0
        var avgFat = data["avg_fat_per_day"] as? Int ?? 0
        
        if avgCalories == 0 && !dailyPlans.isEmpty {
            avgCalories = dailyPlans.reduce(0) { $0 + $1.totalCalories } / dailyPlans.count
            filledFields.append("summary.avgCaloriesPerDay")
        }
        
        if avgProtein == 0 || avgCarbs == 0 || avgFat == 0 {
            let calculated = calculateSummary(from: dailyPlans)
            avgProtein = avgProtein > 0 ? avgProtein : calculated.avgProteinPerDay
            avgCarbs = avgCarbs > 0 ? avgCarbs : calculated.avgCarbsPerDay
            avgFat = avgFat > 0 ? avgFat : calculated.avgFatPerDay
            filledFields.append("summary macros")
        }
        
        return NutritionSummary(
            avgCaloriesPerDay: avgCalories,
            avgProteinPerDay: avgProtein,
            avgCarbsPerDay: avgCarbs,
            avgFatPerDay: avgFat,
            dietaryRestrictions: data["dietary_restrictions"] as? [String] ?? []
        )
    }
    
    private static func calculateSummary(from dailyPlans: [DailyPlan]) -> NutritionSummary {
        guard !dailyPlans.isEmpty else {
            return .empty
        }
        
        var totalCalories = 0
        var totalProtein = 0
        var totalCarbs = 0
        var totalFat = 0
        
        for day in dailyPlans {
            totalCalories += day.totalCalories
            for meal in day.meals {
                totalProtein += meal.nutrition.protein
                totalCarbs += meal.nutrition.carbs
                totalFat += meal.nutrition.fat
            }
        }
        
        let count = dailyPlans.count
        
        return NutritionSummary(
            avgCaloriesPerDay: totalCalories / count,
            avgProteinPerDay: totalProtein / count,
            avgCarbsPerDay: totalCarbs / count,
            avgFatPerDay: totalFat / count
        )
    }
    
    private static func createDefaultDailyPlan(day: Int) -> DailyPlan {
        let actualDate = Calendar.current.date(byAdding: .day, value: day - 1, to: Date())
        
        return DailyPlan(
            day: day,
            date: "",
            actualDate: actualDate,
            totalCalories: 2000,
            meals: createDefaultMeals()
        )
    }
    
    private static func createDefaultMeals() -> [Meal] {
        return [
            Meal(type: .breakfast, recipe: createPlaceholderRecipe(for: .breakfast), nutrition: createDefaultNutrition(for: .breakfast)),
            Meal(type: .lunch, recipe: createPlaceholderRecipe(for: .lunch), nutrition: createDefaultNutrition(for: .lunch)),
            Meal(type: .dinner, recipe: createPlaceholderRecipe(for: .dinner), nutrition: createDefaultNutrition(for: .dinner)),
            Meal(type: .snack, recipe: createPlaceholderRecipe(for: .snack), nutrition: createDefaultNutrition(for: .snack))
        ]
    }
    
    private static func createPlaceholderRecipe(for mealType: MealType) -> Recipe {
        Recipe(
            name: "Suggested \(mealType.displayName)",
            prepTime: 20,
            servings: 1,
            difficulty: .easy,
            ingredients: [Ingredient(name: "Various ingredients", amount: "As needed", category: .other)],
            instructions: ["Prepare according to your preferences."],
            explanation: "This is a placeholder. Please customize based on your preferences."
        )
    }
    
    private static func createDefaultNutrition(for mealType: MealType) -> NutritionInfo {
        let calories = defaultCaloriesPerMeal[mealType] ?? 500
        return NutritionInfo(
            calories: calories,
            protein: Int(Double(calories) * defaultMacroRatios.protein / 4),
            carbs: Int(Double(calories) * defaultMacroRatios.carbs / 4),
            fat: Int(Double(calories) * defaultMacroRatios.fat / 9),
            fiber: 5,
            sugar: 10,
            sodium: 500
        )
    }
}

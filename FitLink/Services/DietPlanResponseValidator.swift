//
//  DietPlanResponseValidator.swift
//  FitLink
//
//  Created on 25.12.2025.
//

import Foundation

struct DietPlanResponseValidator {
    
    struct ValidationResult {
        let isValid: Bool
        let errors: [ValidationError]
        let warnings: [ValidationWarning]
        let validatedPlan: DietPlan?
        
        var hasErrors: Bool { !errors.isEmpty }
        var hasWarnings: Bool { !warnings.isEmpty }
    }
    
    struct ValidationError: Identifiable {
        let id = UUID()
        let field: String
        let message: String
        let severity: Severity
        
        enum Severity {
            case critical
            case error
        }
    }
    
    struct ValidationWarning: Identifiable {
        let id = UUID()
        let field: String
        let message: String
    }
    
    static func validate(_ plan: DietPlan) -> ValidationResult {
        var errors = [ValidationError]()
        var warnings = [ValidationWarning]()
        
        if plan.dailyPlans.isEmpty {
            errors.append(ValidationError(
                field: "dailyPlans",
                message: "Diet plan has no daily plans",
                severity: .critical
            ))
        }
        
        if plan.totalDays <= 0 {
            errors.append(ValidationError(
                field: "totalDays",
                message: "Total days must be greater than 0",
                severity: .error
            ))
        }
        
        if plan.totalDays != plan.dailyPlans.count {
            warnings.append(ValidationWarning(
                field: "totalDays",
                message: "Total days (\(plan.totalDays)) doesn't match daily plans count (\(plan.dailyPlans.count))"
            ))
        }
        
        for (index, dailyPlan) in plan.dailyPlans.enumerated() {
            let dayErrors = validateDailyPlan(dailyPlan, dayIndex: index)
            errors.append(contentsOf: dayErrors.errors)
            warnings.append(contentsOf: dayErrors.warnings)
        }
        
        let summaryValidation = validateNutritionSummary(plan.summary)
        errors.append(contentsOf: summaryValidation.errors)
        warnings.append(contentsOf: summaryValidation.warnings)
        
        let isValid = errors.filter { $0.severity == .critical }.isEmpty
        
        return ValidationResult(
            isValid: isValid,
            errors: errors,
            warnings: warnings,
            validatedPlan: isValid ? plan : nil
        )
    }
    
    private static func validateDailyPlan(_ dailyPlan: DailyPlan, dayIndex: Int) -> (errors: [ValidationError], warnings: [ValidationWarning]) {
        var errors = [ValidationError]()
        var warnings = [ValidationWarning]()
        let prefix = "Day \(dayIndex + 1)"
        
        if dailyPlan.meals.isEmpty {
            errors.append(ValidationError(
                field: "\(prefix).meals",
                message: "\(prefix) has no meals",
                severity: .error
            ))
        }
        
        if dailyPlan.totalCalories <= 0 {
            warnings.append(ValidationWarning(
                field: "\(prefix).totalCalories",
                message: "\(prefix) has zero or negative calories"
            ))
        }
        
        let calculatedCalories = dailyPlan.meals.reduce(0) { $0 + $1.nutrition.calories }
        let caloriesDifference = abs(dailyPlan.totalCalories - calculatedCalories)
        if caloriesDifference > 100 {
            warnings.append(ValidationWarning(
                field: "\(prefix).totalCalories",
                message: "\(prefix) total calories (\(dailyPlan.totalCalories)) differs from sum of meals (\(calculatedCalories))"
            ))
        }
        
        if dailyPlan.totalCalories < 800 {
            warnings.append(ValidationWarning(
                field: "\(prefix).totalCalories",
                message: "\(prefix) has unusually low calories (\(dailyPlan.totalCalories))"
            ))
        } else if dailyPlan.totalCalories > 5000 {
            warnings.append(ValidationWarning(
                field: "\(prefix).totalCalories",
                message: "\(prefix) has unusually high calories (\(dailyPlan.totalCalories))"
            ))
        }
        
        for (mealIndex, meal) in dailyPlan.meals.enumerated() {
            let mealValidation = validateMeal(meal, mealIndex: mealIndex, dayPrefix: prefix)
            errors.append(contentsOf: mealValidation.errors)
            warnings.append(contentsOf: mealValidation.warnings)
        }
        
        return (errors, warnings)
    }
    
    private static func validateMeal(_ meal: Meal, mealIndex: Int, dayPrefix: String) -> (errors: [ValidationError], warnings: [ValidationWarning]) {
        var errors = [ValidationError]()
        var warnings = [ValidationWarning]()
        let prefix = "\(dayPrefix).\(meal.type.displayName)"
        
        if meal.recipe.name.isEmpty {
            errors.append(ValidationError(
                field: "\(prefix).recipe.name",
                message: "\(prefix) recipe has no name",
                severity: .error
            ))
        }
        
        if meal.recipe.ingredients.isEmpty {
            errors.append(ValidationError(
                field: "\(prefix).recipe.ingredients",
                message: "\(prefix) recipe has no ingredients",
                severity: .error
            ))
        }
        
        if meal.recipe.instructions.isEmpty {
            warnings.append(ValidationWarning(
                field: "\(prefix).recipe.instructions",
                message: "\(prefix) recipe has no instructions"
            ))
        }
        
        let nutritionValidation = validateNutritionInfo(meal.nutrition, prefix: prefix)
        errors.append(contentsOf: nutritionValidation.errors)
        warnings.append(contentsOf: nutritionValidation.warnings)
        
        return (errors, warnings)
    }
    
    private static func validateNutritionInfo(_ nutrition: NutritionInfo, prefix: String) -> (errors: [ValidationError], warnings: [ValidationWarning]) {
        var errors = [ValidationError]()
        var warnings = [ValidationWarning]()
        
        if nutrition.calories <= 0 {
            warnings.append(ValidationWarning(
                field: "\(prefix).nutrition.calories",
                message: "\(prefix) has zero or negative calories"
            ))
        }
        
        if nutrition.calories > 2000 {
            warnings.append(ValidationWarning(
                field: "\(prefix).nutrition.calories",
                message: "\(prefix) has unusually high calories for a single meal (\(nutrition.calories))"
            ))
        }
        
        if nutrition.protein < 0 || nutrition.carbs < 0 || nutrition.fat < 0 {
            errors.append(ValidationError(
                field: "\(prefix).nutrition",
                message: "\(prefix) has negative macro values",
                severity: .error
            ))
        }
        
        let macroCalories = (nutrition.protein * 4) + (nutrition.carbs * 4) + (nutrition.fat * 9)
        let calorieDifference = abs(nutrition.calories - macroCalories)
        if calorieDifference > nutrition.calories / 4 && nutrition.calories > 0 {
            warnings.append(ValidationWarning(
                field: "\(prefix).nutrition",
                message: "\(prefix) macro calories (\(macroCalories)) significantly differ from stated calories (\(nutrition.calories))"
            ))
        }
        
        return (errors, warnings)
    }
    
    private static func validateNutritionSummary(_ summary: NutritionSummary) -> (errors: [ValidationError], warnings: [ValidationWarning]) {
        var errors = [ValidationError]()
        var warnings = [ValidationWarning]()
        
        if summary.avgCaloriesPerDay <= 0 {
            warnings.append(ValidationWarning(
                field: "summary.avgCaloriesPerDay",
                message: "Average calories per day is zero or negative"
            ))
        }
        
        if summary.avgCaloriesPerDay < 1000 {
            warnings.append(ValidationWarning(
                field: "summary.avgCaloriesPerDay",
                message: "Average calories (\(summary.avgCaloriesPerDay)) is unusually low"
            ))
        } else if summary.avgCaloriesPerDay > 4000 {
            warnings.append(ValidationWarning(
                field: "summary.avgCaloriesPerDay",
                message: "Average calories (\(summary.avgCaloriesPerDay)) is unusually high"
            ))
        }
        
        return (errors, warnings)
    }
    
    static func validateJSON(_ jsonString: String) -> ValidationResult {
        let analysis = ResponseStructureAnalyzer.analyzeDietPlanResponse(jsonString)
        
        if !analysis.isComplete && analysis.recoveryStrategy == .abort {
            return ValidationResult(
                isValid: false,
                errors: [ValidationError(
                    field: "json",
                    message: "Response is too incomplete to use: \(analysis.missingFields.joined(separator: ", "))",
                    severity: .critical
                )],
                warnings: [],
                validatedPlan: nil
            )
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            return ValidationResult(
                isValid: false,
                errors: [ValidationError(
                    field: "json",
                    message: "Invalid JSON encoding",
                    severity: .critical
                )],
                warnings: [],
                validatedPlan: nil
            )
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            struct DietPlanDTO: Decodable {
                let dailyPlans: [DailyPlan]?
                let summary: NutritionSummary?
                let totalDays: Int?
                
                enum CodingKeys: String, CodingKey {
                    case dailyPlans = "daily_plans"
                    case summary
                    case totalDays = "total_days"
                }
            }
            
            let dto = try decoder.decode(DietPlanDTO.self, from: data)
            
            let plan = DietPlan(
                userId: "",
                totalDays: dto.totalDays ?? dto.dailyPlans?.count ?? 7,
                dailyPlans: dto.dailyPlans ?? [],
                summary: dto.summary ?? .empty
            )
            
            return validate(plan)
        } catch {
            return ValidationResult(
                isValid: false,
                errors: [ValidationError(
                    field: "json",
                    message: "Failed to decode: \(error.localizedDescription)",
                    severity: .critical
                )],
                warnings: [],
                validatedPlan: nil
            )
        }
    }
}

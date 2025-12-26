//
//  ResponseStructureAnalyzer.swift
//  FitLink
//
//  Created on 25.12.2025.
//

import Foundation

struct ResponseStructureAnalyzer {
    
    struct AnalysisResult {
        let isComplete: Bool
        let completenessPercentage: Double
        let missingFields: [String]
        let presentFields: [String]
        let recoveryStrategy: RecoveryStrategy
        let rawData: [String: Any]?
    }
    
    enum RecoveryStrategy {
        case none
        case fillDefaults
        case retry
        case partialUse
        case abort
        
        var description: String {
            switch self {
            case .none: return "Response is complete"
            case .fillDefaults: return "Fill missing fields with defaults"
            case .retry: return "Retry with modified prompt"
            case .partialUse: return "Use available data with warnings"
            case .abort: return "Cannot recover - response unusable"
            }
        }
    }
    
    private static let requiredDietPlanFields = [
        "daily_plans",
        "summary"
    ]
    
    private static let requiredDailyPlanFields = [
        "day",
        "meals",
        "total_calories"
    ]
    
    private static let requiredMealFields = [
        "type",
        "recipe",
        "nutrition"
    ]
    
    private static let requiredRecipeFields = [
        "name",
        "ingredients",
        "instructions"
    ]
    
    private static let requiredNutritionFields = [
        "calories",
        "protein",
        "carbs",
        "fat"
    ]
    
    static func analyzeDietPlanResponse(_ jsonString: String) -> AnalysisResult {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return AnalysisResult(
                isComplete: false,
                completenessPercentage: 0,
                missingFields: ["Unable to parse JSON"],
                presentFields: [],
                recoveryStrategy: .abort,
                rawData: nil
            )
        }
        
        var presentFields = [String]()
        var missingFields = [String]()
        var totalFields = 0
        var presentCount = 0
        
        for field in requiredDietPlanFields {
            totalFields += 1
            if json[field] != nil {
                presentFields.append(field)
                presentCount += 1
            } else {
                missingFields.append(field)
            }
        }
        
        if let dailyPlans = json["daily_plans"] as? [[String: Any]] {
            for (index, dayPlan) in dailyPlans.enumerated() {
                let prefix = "daily_plans[\(index)]"
                
                for field in requiredDailyPlanFields {
                    totalFields += 1
                    if dayPlan[field] != nil {
                        presentFields.append("\(prefix).\(field)")
                        presentCount += 1
                    } else {
                        missingFields.append("\(prefix).\(field)")
                    }
                }
                
                if let meals = dayPlan["meals"] as? [[String: Any]] {
                    for (mealIndex, meal) in meals.enumerated() {
                        let mealPrefix = "\(prefix).meals[\(mealIndex)]"
                        
                        for field in requiredMealFields {
                            totalFields += 1
                            if meal[field] != nil {
                                presentFields.append("\(mealPrefix).\(field)")
                                presentCount += 1
                            } else {
                                missingFields.append("\(mealPrefix).\(field)")
                            }
                        }
                        
                        if let recipe = meal["recipe"] as? [String: Any] {
                            let recipePrefix = "\(mealPrefix).recipe"
                            for field in requiredRecipeFields {
                                totalFields += 1
                                if recipe[field] != nil {
                                    presentFields.append("\(recipePrefix).\(field)")
                                    presentCount += 1
                                } else {
                                    missingFields.append("\(recipePrefix).\(field)")
                                }
                            }
                        }
                        
                        if let nutrition = meal["nutrition"] as? [String: Any] {
                            let nutritionPrefix = "\(mealPrefix).nutrition"
                            for field in requiredNutritionFields {
                                totalFields += 1
                                if nutrition[field] != nil {
                                    presentFields.append("\(nutritionPrefix).\(field)")
                                    presentCount += 1
                                } else {
                                    missingFields.append("\(nutritionPrefix).\(field)")
                                }
                            }
                        }
                    }
                }
            }
        }
        
        let completenessPercentage = totalFields > 0 ? Double(presentCount) / Double(totalFields) * 100 : 0
        let strategy = determineRecoveryStrategy(completenessPercentage: completenessPercentage, missingFields: missingFields)
        
        return AnalysisResult(
            isComplete: missingFields.isEmpty,
            completenessPercentage: completenessPercentage,
            missingFields: missingFields,
            presentFields: presentFields,
            recoveryStrategy: strategy,
            rawData: json
        )
    }
    
    static func analyzeWorkoutPlanResponse(_ jsonString: String) -> AnalysisResult {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return AnalysisResult(
                isComplete: false,
                completenessPercentage: 0,
                missingFields: ["Unable to parse JSON"],
                presentFields: [],
                recoveryStrategy: .abort,
                rawData: nil
            )
        }
        
        let requiredFields = ["title", "days", "total_days"]
        var presentFields = [String]()
        var missingFields = [String]()
        
        for field in requiredFields {
            if json[field] != nil {
                presentFields.append(field)
            } else {
                missingFields.append(field)
            }
        }
        
        let totalFields = requiredFields.count
        let completenessPercentage = Double(presentFields.count) / Double(totalFields) * 100
        let strategy = determineRecoveryStrategy(completenessPercentage: completenessPercentage, missingFields: missingFields)
        
        return AnalysisResult(
            isComplete: missingFields.isEmpty,
            completenessPercentage: completenessPercentage,
            missingFields: missingFields,
            presentFields: presentFields,
            recoveryStrategy: strategy,
            rawData: json
        )
    }
    
    private static func determineRecoveryStrategy(completenessPercentage: Double, missingFields: [String]) -> RecoveryStrategy {
        if completenessPercentage >= 100 {
            return .none
        } else if completenessPercentage >= 80 {
            return .fillDefaults
        } else if completenessPercentage >= 50 {
            return .partialUse
        } else if completenessPercentage >= 20 {
            return .retry
        } else {
            return .abort
        }
    }
    
    static func extractPartialData<T: Decodable>(from jsonString: String, as type: T.Type) -> T? {
        let cleaned = extractJSON(from: jsonString)
        guard let data = cleaned.data(using: .utf8) else { return nil }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            return try decoder.decode(type, from: data)
        } catch {
            #if DEBUG
            print("[ResponseStructureAnalyzer] Failed to decode: \(error)")
            #endif
            return nil
        }
    }
    
    private static func extractJSON(from response: String) -> String {
        var content = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if content.hasPrefix("```json") {
            content = String(content.dropFirst(7))
        } else if content.hasPrefix("```") {
            content = String(content.dropFirst(3))
        }
        
        if content.hasSuffix("```") {
            content = String(content.dropLast(3))
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

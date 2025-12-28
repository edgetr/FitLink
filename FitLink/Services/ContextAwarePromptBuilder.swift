import Foundation

struct ContextAwarePromptBuilder {
    
    static func buildPrompt(
        userRequest: String,
        userContext: LLMUserContext,
        additionalInstructions: String? = nil
    ) -> String {
        var prompt = ""
        
        prompt += userContext.formatForPrompt()
        
        if let instructions = additionalInstructions {
            prompt += "\n\(instructions)\n"
        }
        
        prompt += "\n## User Request\n"
        prompt += userRequest
        
        return prompt
    }
    
    static func workoutPlanInstructions(from context: LLMUserContext) -> String {
        var instructions: [String] = []
        
        instructions.append("PERSONALIZATION REQUIREMENTS:")
        
        if let profile = context.profile {
            if let level = profile.fitnessLevel {
                instructions.append("- Calibrate difficulty for \(level) fitness level")
            }
            
            if !profile.injuriesOrLimitations.isEmpty {
                instructions.append("- AVOID exercises that stress: \(profile.injuriesOrLimitations.joined(separator: ", "))")
            }
            
            if !profile.availableEquipment.isEmpty {
                instructions.append("- Only use equipment: \(profile.availableEquipment.joined(separator: ", "))")
            }
            
            if let duration = profile.preferredWorkoutDuration {
                instructions.append("- Keep workouts within: \(duration)")
            }
            
            if let days = profile.workoutDaysPerWeek {
                instructions.append("- Plan for \(days) workout days per week")
            }
        }
        
        if let metrics = context.healthMetrics {
            if metrics.avgExerciseMinutes < 15 {
                instructions.append("- User is relatively sedentary - start with lower intensity")
            } else if metrics.avgExerciseMinutes > 45 {
                instructions.append("- User is already active - can handle higher intensity")
            }
            
            if metrics.avgSleepHours < 6 {
                instructions.append("- User gets limited sleep - avoid extremely intense morning workouts")
            }
            
            if !metrics.peakActivityHours.isEmpty {
                let hours = metrics.peakActivityHours.map { formatHour($0) }.joined(separator: ", ")
                instructions.append("- User is most active around: \(hours) - schedule challenging workouts accordingly")
            }
        }
        
        if let history = context.planHistory {
            if !history.avoidedExerciseTypes.isEmpty {
                instructions.append("- User often skips: \(history.avoidedExerciseTypes.joined(separator: ", ")) - minimize or provide alternatives")
            }
            
            if !history.preferredExerciseTypes.isEmpty {
                instructions.append("- User enjoys: \(history.preferredExerciseTypes.joined(separator: ", ")) - include these when appropriate")
            }
        }
        
        return instructions.joined(separator: "\n")
    }
    
    static func dietPlanInstructions(from context: LLMUserContext) -> String {
        var instructions: [String] = []
        
        instructions.append("PERSONALIZATION REQUIREMENTS:")
        
        if let profile = context.profile {
            if !profile.allergies.isEmpty {
                instructions.append("- CRITICAL - MUST AVOID (allergies): \(profile.allergies.joined(separator: ", "))")
            }
            
            if !profile.dietaryRestrictions.isEmpty {
                instructions.append("- Follow dietary restrictions: \(profile.dietaryRestrictions.joined(separator: ", "))")
            }
            
            if !profile.dislikedFoods.isEmpty {
                instructions.append("- Avoid if possible: \(profile.dislikedFoods.joined(separator: ", "))")
            }
            
            if !profile.preferredCuisines.isEmpty {
                instructions.append("- Prefer cuisines: \(profile.preferredCuisines.joined(separator: ", "))")
            }
            
            if let skill = profile.cookingSkillLevel {
                instructions.append("- Recipe complexity for \(skill) cook")
            }
            
            if let prepTime = profile.mealPrepTimePreference {
                instructions.append("- Meal prep time: \(prepTime)")
            }
            
            if let size = profile.householdSize, size > 1 {
                instructions.append("- Adjust portions for \(size) people")
            }
            
            if let calories = profile.dailyCalorieTarget {
                instructions.append("- Target \(calories) calories per day")
            }
        }
        
        if let metrics = context.healthMetrics {
            if let wake = metrics.typicalWakeTime, let sleep = metrics.typicalSleepTime {
                instructions.append("- User wakes at \(wake.formatted), sleeps at \(sleep.formatted) - time meals accordingly")
            }
            
            if metrics.avgExerciseMinutes > 45 {
                instructions.append("- User is very active - ensure adequate protein and carbs for recovery")
            }
        }
        
        if let history = context.planHistory {
            if !history.avoidedMealIngredients.isEmpty {
                instructions.append("- User tends to skip meals with: \(history.avoidedMealIngredients.joined(separator: ", "))")
            }
            
            if !history.preferredMealTypes.isEmpty {
                instructions.append("- User enjoys: \(history.preferredMealTypes.joined(separator: ", ")) - include similar options")
            }
        }
        
        return instructions.joined(separator: "\n")
    }
    
    private static func formatHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h)\(ampm)"
    }
}

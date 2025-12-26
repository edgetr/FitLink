import Foundation

struct WorkoutPromptBuilder {
    
    // MARK: - System Prompt
    
    static let systemPrompt = """
    You are an expert personal trainer and fitness coach with extensive experience creating workout programs.
    Your role is to create personalized, safe, and effective workout plans based on user preferences and goals.
    
    IMPORTANT GUIDELINES:
    1. Always prioritize safety - include proper warm-up and cool-down recommendations
    2. Consider the user's fitness level when prescribing exercises
    3. Ensure progressive overload principles are applied
    4. Include rest days for recovery
    5. Provide clear exercise instructions and rep ranges
    6. Consider available equipment when suggesting exercises
    7. Balance muscle groups to prevent imbalances
    8. Include alternatives for exercises when appropriate
    
    ALWAYS respond with valid JSON only. No markdown, no explanatory text outside the JSON structure.
    """
    
    // MARK: - Home Plan Prompt
    
    static func buildHomePlanPrompt(preferences: String, additionalContext: [String: AnswerValue] = [:]) -> String {
        var enhancedPreferences = preferences
        
        for (question, answer) in additionalContext {
            enhancedPreferences += "\n\(question): \(answer.stringValue)"
        }
        
        return """
        Create a 7-day home workout plan based on these preferences:
        
        USER PREFERENCES:
        \(enhancedPreferences)
        
        CONSTRAINTS FOR HOME WORKOUTS:
        - Use minimal or no equipment (bodyweight exercises preferred)
        - If equipment is mentioned, only use: resistance bands, dumbbells, pull-up bar, yoga mat
        - Each workout should be completable in 30-60 minutes
        - Include exercises that can be done in a small space
        
        RESPOND WITH THIS EXACT JSON STRUCTURE:
        {
            "title": "Plan title here",
            "total_days": 7,
            "difficulty": "beginner" | "intermediate" | "advanced",
            "equipment": ["list of equipment needed or empty array"],
            "goals": ["list of fitness goals addressed"],
            "days": [
                {
                    "day": 1,
                    "date": "2025-12-24",
                    "is_rest_day": false,
                    "focus": ["Muscle groups targeted"],
                    "notes": "Optional notes for this day",
                    "exercises": [
                        {
                            "name": "Exercise name",
                            "sets": 3,
                            "reps": "10-12",
                            "duration_seconds": null,
                            "rest_seconds": 60,
                            "notes": "Form tips or modifications",
                            "equipment_needed": null
                        }
                    ],
                    "warmup": [
                        {
                            "name": "Warm-up exercise",
                            "duration_seconds": 30,
                            "notes": "Description"
                        }
                    ],
                    "cooldown": [
                        {
                            "name": "Stretch name",
                            "duration_seconds": 30,
                            "notes": "Description"
                        }
                    ]
                }
            ]
        }
        
        IMPORTANT:
        - Include 2-3 rest days spread throughout the week
        - For rest days, set is_rest_day to true and exercises to empty array
        - Use duration_seconds for timed exercises (like planks), sets/reps for counted exercises
        - All dates should start from today and be consecutive
        - Provide 5-8 exercises per workout day
        - Include 3-5 warmup and 3-5 cooldown exercises
        """
    }
    
    // MARK: - Gym Plan Prompt
    
    static func buildGymPlanPrompt(preferences: String, additionalContext: [String: AnswerValue] = [:]) -> String {
        var enhancedPreferences = preferences
        
        for (question, answer) in additionalContext {
            enhancedPreferences += "\n\(question): \(answer.stringValue)"
        }
        
        return """
        Create a 7-day gym workout plan based on these preferences:
        
        USER PREFERENCES:
        \(enhancedPreferences)
        
        GYM WORKOUT CONTEXT:
        - User has access to full gym equipment
        - Can use: barbells, dumbbells, machines, cables, benches, racks
        - Focus on compound movements with isolation accessories
        - Include progressive overload recommendations
        
        RESPOND WITH THIS EXACT JSON STRUCTURE:
        {
            "title": "Plan title here",
            "total_days": 7,
            "difficulty": "beginner" | "intermediate" | "advanced",
            "equipment": ["list of gym equipment used"],
            "goals": ["list of fitness goals addressed"],
            "days": [
                {
                    "day": 1,
                    "date": "2025-12-24",
                    "is_rest_day": false,
                    "focus": ["Muscle groups targeted"],
                    "notes": "Optional training notes",
                    "exercises": [
                        {
                            "name": "Exercise name",
                            "sets": 4,
                            "reps": "6-8",
                            "duration_seconds": null,
                            "rest_seconds": 90,
                            "notes": "Form cues or progression tips",
                            "equipment_needed": "Barbell, Squat Rack"
                        }
                    ],
                    "warmup": [
                        {
                            "name": "Warm-up exercise",
                            "duration_seconds": 60,
                            "notes": "Description"
                        }
                    ],
                    "cooldown": [
                        {
                            "name": "Stretch or mobility work",
                            "duration_seconds": 30,
                            "notes": "Description"
                        }
                    ]
                }
            ]
        }
        
        IMPORTANT:
        - Include 2-3 rest days (can be active recovery)
        - For rest days, set is_rest_day to true and exercises to empty array
        - Include equipment_needed for each exercise
        - Use appropriate rep ranges: 4-6 for strength, 8-12 for hypertrophy, 12-15+ for endurance
        - All dates should start from today and be consecutive
        - Provide 6-10 exercises per workout day
        - Include specific warmup for the muscle groups being trained
        """
    }
    
    // MARK: - Clarifying Questions Prompt
    
    static func buildClarifyingQuestionsPrompt(userInput: String, planTypes: [WorkoutPlanType]) -> String {
        let planContext = planTypes.map { $0.displayName }.joined(separator: " and ")
        
        return """
        The user wants to create a \(planContext) workout plan with this input:
        "\(userInput)"
        
        Analyze if you need more information to create an effective, personalized workout plan.
        
        RESPOND WITH THIS EXACT JSON STRUCTURE:
        {
            "needs_clarification": true or false,
            "questions": [
                {
                    "id": "unique_id",
                    "text": "Your question here?",
                    "answer_kind": "text" | "number" | "choice" | "binary",
                    "choices": ["Option 1", "Option 2"] or null,
                    "context": "home" | "gym" | "common",
                    "is_required": true or false,
                    "hint": "Optional hint text"
                }
            ]
        }
        
        QUESTION GUIDELINES:
        - Ask 3-5 questions maximum
        - Focus on: fitness level, available time, specific goals, injuries/limitations
        - For "home" context: ask about available equipment
        - For "gym" context: ask about gym experience
        - For "common" context: questions that apply to both
        - Use "binary" for yes/no questions
        - Use "choice" when there are clear options
        - Set is_required to true for essential information
        
        If the input is already detailed enough, set needs_clarification to false and questions to an empty array.
        """
    }
    
    // MARK: - Combined Plan Prompt
    
    static func buildCombinedPlanPrompt(
        preferences: String,
        additionalContext: [String: AnswerValue] = [:],
        planTypes: [WorkoutPlanType]
    ) -> String {
        if planTypes.count == 1 {
            if planTypes[0] == .home {
                return buildHomePlanPrompt(preferences: preferences, additionalContext: additionalContext)
            } else {
                return buildGymPlanPrompt(preferences: preferences, additionalContext: additionalContext)
            }
        }
        
        var enhancedPreferences = preferences
        for (question, answer) in additionalContext {
            enhancedPreferences += "\n\(question): \(answer.stringValue)"
        }
        
        return """
        Create TWO 7-day workout plans (one for HOME, one for GYM) based on these preferences:
        
        USER PREFERENCES:
        \(enhancedPreferences)
        
        RESPOND WITH THIS EXACT JSON STRUCTURE:
        {
            "home_plan": {
                // Same structure as single home plan
            },
            "gym_plan": {
                // Same structure as single gym plan
            }
        }
        
        HOME PLAN CONSTRAINTS:
        - Minimal equipment (bodyweight, resistance bands, dumbbells)
        - 30-60 minute sessions
        - Exercises suitable for small spaces
        
        GYM PLAN CONSTRAINTS:
        - Full gym equipment access
        - Focus on compound movements
        - Include progressive overload
        
        Both plans should target the same goals but with different approaches.
        """
    }
}

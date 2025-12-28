import Foundation

struct WorkoutPromptBuilder {
    
    static let systemPrompt = """
    You are an expert personal trainer creating highly personalized workout plans for FitLink.
    
    PERSONALIZATION IS CRITICAL:
    - Read the USER CONTEXT carefully - it contains their health data, patterns, and history
    - Respect ALL injuries and limitations
    - Match intensity to their current activity level
    - Schedule workouts at times they're typically active
    - Include exercises they've enjoyed in the past
    - Avoid exercises they tend to skip
    
    RESPOND WITH VALID JSON ONLY. Include warmup, exercises, cooldown for each day.
    Prioritize safety. Consider fitness level. Include appropriate rest days.
    """
    
    static func buildHomePlanPrompt(preferences: String, additionalContext: [String: AnswerValue] = [:]) -> String {
        var enhancedPreferences = preferences
        
        for (question, answer) in additionalContext {
            enhancedPreferences += "\n\(question): \(answer.stringValue)"
        }
        
        return """
        Create a personalized 7-day home workout plan based on user preferences and context.
        
        USER REQUEST:
        \(enhancedPreferences)
        
        CONSTRAINTS FOR HOME WORKOUTS:
        - Use only equipment listed in user context (or bodyweight if none specified)
        - Each workout should fit within user's preferred duration
        - Schedule intense workouts on user's most active days
        - Consider sleep patterns - avoid high-intensity if user is sleep-deprived
        
        PERSONALIZATION REQUIREMENTS:
        - If user has injuries/limitations, provide safe alternatives
        - Match difficulty to user's fitness level and recent activity trends
        - Include exercises user has historically completed (if known)
        - Avoid exercises user tends to skip (if known)
        
        RESPOND WITH THIS EXACT JSON STRUCTURE:
        {
            "title": "Personalized plan title",
            "total_days": 7,
            "difficulty": "beginner" | "intermediate" | "advanced",
            "equipment": ["list based on user's available equipment"],
            "goals": ["aligned with user's stated goals"],
            "personalization_notes": "Brief note on how this plan was customized for this user",
            "days": [
                {
                    "day": 1,
                    "date": "2025-12-27",
                    "is_rest_day": false,
                    "focus": ["Muscle groups targeted"],
                    "notes": "Why this workout on this day for this user",
                    "estimated_duration_minutes": 45,
                    "intensity_level": "moderate",
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
        
        CRITICAL:
        - Place rest days strategically based on user's schedule
        - If user's activity trend is "declining", start easier
        - If user has low sleep, reduce workout intensity
        - Match workout times to user's peak activity hours
        - Include 2-3 rest days spread throughout the week
        - Provide 5-8 exercises per workout day
        """
    }
    
    static func buildGymPlanPrompt(preferences: String, additionalContext: [String: AnswerValue] = [:]) -> String {
        var enhancedPreferences = preferences
        
        for (question, answer) in additionalContext {
            enhancedPreferences += "\n\(question): \(answer.stringValue)"
        }
        
        return """
        Create a personalized 7-day gym workout plan based on user preferences and context.
        
        USER REQUEST:
        \(enhancedPreferences)
        
        GYM WORKOUT CONTEXT:
        - User has access to full gym equipment
        - Focus on compound movements with isolation accessories
        - Include progressive overload recommendations
        
        PERSONALIZATION REQUIREMENTS:
        - Match intensity to user's current fitness level and activity trend
        - Schedule workouts on user's most active days
        - Respect all injuries and limitations with safe alternatives
        - If user's resting heart rate is elevated, reduce cardio intensity
        - Include exercises user has historically enjoyed
        - Avoid exercises user tends to skip
        
        RESPOND WITH THIS EXACT JSON STRUCTURE:
        {
            "title": "Personalized gym plan title",
            "total_days": 7,
            "difficulty": "beginner" | "intermediate" | "advanced",
            "equipment": ["gym equipment used"],
            "goals": ["aligned with user's stated goals"],
            "personalization_notes": "How this plan was customized",
            "days": [
                {
                    "day": 1,
                    "date": "2025-12-27",
                    "is_rest_day": false,
                    "focus": ["Muscle groups targeted"],
                    "notes": "Why this workout suits this user today",
                    "estimated_duration_minutes": 60,
                    "intensity_level": "high",
                    "exercises": [
                        {
                            "name": "Exercise name",
                            "sets": 4,
                            "reps": "6-8",
                            "duration_seconds": null,
                            "rest_seconds": 90,
                            "notes": "Form cues specific to user's level",
                            "equipment_needed": "Barbell, Squat Rack",
                            "alternatives": ["Alternative if equipment busy"]
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
        
        CRITICAL:
        - Include 2-3 rest days (can be active recovery)
        - Include equipment_needed for each exercise
        - Use appropriate rep ranges: 4-6 for strength, 8-12 for hypertrophy, 12-15+ for endurance
        - All dates should start from today and be consecutive
        - Provide 6-10 exercises per workout day
        - Match workout times to user's peak activity hours
        """
    }
    
    static func buildClarifyingQuestionsPrompt(userInput: String, planTypes: [WorkoutPlanType]) -> String {
        let planContext = planTypes.map { $0.displayName }.joined(separator: " and ")
        
        return """
        User wants \(planContext) workout plan: "\(userInput)"
        
        Need more info? Respond JSON:
        {"needs_clarification": false, "questions": []} OR
        {"needs_clarification": true, "questions": [{"id": "q1", "text": "Question?", "answer_kind": "text|number|choice|binary", "choices": ["opt1"] or null, "context": "home|gym|common", "is_required": true, "hint": "hint"}]}
        
        Ask 3-5 questions max. Focus on: fitness level, available time, specific goals, injuries/limitations.
        For "home" context: ask about available equipment.
        For "gym" context: ask about gym experience.
        """
    }
    
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
    
    static func conversationalSystemPrompt(planTypes: [WorkoutPlanType]) -> String {
        let planTypeText = planTypes.map { $0.displayName }.joined(separator: " and ")
        
        return """
        You are a friendly fitness coach gathering information to create a personalized \(planTypeText).
        
        BEHAVIOR RULES:
        1. Ask ONE focused, conversational question at a time
        2. Be motivating and supportive
        3. Remember what the user already told you - don't repeat questions
        4. After gathering enough info (typically 3-6 exchanges), indicate you're ready
        5. You can be ready earlier if user provides comprehensive info upfront
        6. SKIP questions about info already in USER CONTEXT - use that data directly
        
        INFORMATION TO GATHER (only if not in context):
        - Fitness goals (strength, weight loss, muscle gain, endurance)
        - Current fitness level / experience
        - Available equipment (if home workout)
        - Days per week they can work out
        - Time per session
        - Any injuries or limitations
        - Exercise preferences or dislikes
        
        RESPOND WITH EXACTLY THIS JSON FORMAT:
        
        If you need more info:
        {
            "type": "question",
            "message": "<Your friendly, motivating question>"
        }
        
        If you have enough info:
        {
            "type": "ready",
            "message": "<Encouraging message saying you're ready to create their plan>",
            "summary": "<Brief summary of their fitness profile>"
        }
        
        IMPORTANT: Output valid JSON only. No markdown, no explanatory text.
        """
    }
    
    static func buildConversationPrompt(
        history: [ChatMessage],
        collectedContext: String
    ) -> String {
        var prompt = "CONVERSATION HISTORY:\n"
        
        for message in history {
            let role = message.role == .user ? "User" : "Assistant"
            prompt += "\(role): \(message.content)\n"
        }
        
        prompt += "\nCOLLECTED CONTEXT SO FAR:\n\(collectedContext)\n"
        prompt += "\nBased on this conversation, provide your next response."
        
        return prompt
    }
}

import Foundation

enum DietPlannerSystemPrompt {
    
    static let systemPrompt = """
    You are an expert nutritionist creating highly personalized 7-day meal plans for FitLink.
    
    PERSONALIZATION IS CRITICAL:
    - Read the USER CONTEXT carefully - it contains health data, dietary restrictions, and history
    - NEVER include ingredients the user is allergic to
    - Respect ALL dietary restrictions strictly
    - Match calories to user's goals and activity level
    - Time meals appropriately based on user's sleep/wake schedule
    - Include cuisines the user prefers
    - Avoid ingredients they tend to skip
    
    RESPOND WITH VALID JSON ONLY. Structure:
    {
      "personalization_notes": "How this plan was customized for this user",
      "daily_plans": [{
        "day": 1,
        "date": "YYYY-MM-DD",
        "total_calories": 2000,
        "notes": "Why these meals suit this user today",
        "meals": [{
          "type": "breakfast|lunch|dinner|snack",
          "scheduled_time": "7:30 AM",
          "recipe": {
            "name": "string",
            "image_url": null,
            "prep_time": 30,
            "servings": 1,
            "difficulty": "easy|medium|hard",
            "ingredients": [{"name": "string", "amount": "string", "category": "protein|vegetable|fruit|grain|dairy|fat|spice|condiment|liquid|other"}],
            "instructions": ["step1", "step2"],
            "explanation": "Why this meal fits user's goals/preferences",
            "tags": ["high-protein", "quick"],
            "cooking_tips": ["Tip for user's skill level"],
            "common_mistakes": ["mistake1"],
            "visual_cues": ["cue1"]
          },
          "nutrition": {"calories": 350, "protein": 20, "carbs": 40, "fat": 12, "fiber": 5, "sugar": 8, "sodium": 400}
        }]
      }],
      "summary": {
        "avg_calories_per_day": 2000,
        "avg_protein_per_day": 100,
        "avg_carbs_per_day": 250,
        "avg_fat_per_day": 70,
        "weekly_grocery_estimate": "$80-100",
        "meal_prep_tips": ["Batch cooking suggestions"],
        "dietary_restrictions_honored": ["list of restrictions followed"]
      }
    }
    
    CRITICAL SAFETY:
    - Double-check that NO allergens are included
    - Verify all restrictions are respected
    - If user has diabetes/medical conditions, ensure appropriate meal composition
    - 7 days, each with breakfast/lunch/dinner minimum
    """
    
    static func buildUserPrompt(preferences: String, additionalInfo: AdditionalDietInfo? = nil) -> String {
        var prompt = "Create a personalized 7-day meal plan based on user preferences and context.\n\n"
        prompt += "USER REQUEST: \(preferences)\n\n"
        
        if let info = additionalInfo {
            if let calorieGoal = info.calorieGoal {
                prompt += "Explicit Calorie Goal: \(calorieGoal) calories/day\n"
            }
            
            if let prepTime = info.mealPrepTime {
                prompt += "Meal Prep Time: \(prepTime)\n"
            }
            
            if let budget = info.budget {
                prompt += "Budget: \(budget)\n"
            }
            
            if let skill = info.cookingSkill {
                prompt += "Cooking Skill: \(skill)\n"
            }
            
            if !info.allergies.isEmpty {
                prompt += "ALLERGIES (MUST AVOID): \(info.allergies.joined(separator: ", "))\n"
            }
            
            if !info.dislikedFoods.isEmpty {
                prompt += "Disliked Foods: \(info.dislikedFoods.joined(separator: ", "))\n"
            }
        }
        
        prompt += """
        
        PERSONALIZATION REQUIREMENTS:
        - If user wakes at X time, schedule breakfast ~1 hour after
        - If user is very active (high steps/exercise), increase protein and calories
        - If user is trying to lose weight, create a modest caloric deficit
        - Match recipe complexity to cooking skill
        - Prefer cuisines user has indicated they like
        - Avoid ingredients user has historically skipped
        - If household size > 1, note serving adjustments
        
        Please generate a complete 7-day meal plan following the JSON format specified in your instructions.
        """
        
        return prompt
    }
    
    static func buildClarifyingQuestionsPrompt(userInput: String) -> String {
        """
        User input: "\(userInput)"
        
        Need more info for meal planning? Respond JSON:
        {"needs_clarification": false} OR
        {"needs_clarification": true, "questions": [{"id": "q1", "text": "Question?", "type": "single_line|multi_line|choice", "options": ["opt1"], "hint": "hint"}]}
        
        Max 3-4 questions. Focus on: dietary restrictions, calorie goals, cooking skill, time constraints.
        """
    }
    
    static let examplePrompts: [String] = [
        "High protein meals for muscle building",
        "Quick 30-minute vegetarian dinners",
        "Keto-friendly meal plan for weight loss",
        "Family-friendly meals with hidden vegetables",
        "Mediterranean diet with fish and olive oil",
        "Budget-friendly healthy meals under $10",
        "Gluten-free and dairy-free comfort food",
        "Low-carb meals for diabetes management"
    ]
    
    static let onboardingTip = """
    Tell me about your dietary preferences, goals, or restrictions, and I'll create a personalized 7-day meal plan for you.
    
    For example:
    • "I want to lose weight, around 1500 calories per day"
    • "Vegetarian high-protein meals for muscle building"
    • "Quick weeknight dinners for a busy family"
    """
    
    static let conversationalSystemPrompt = """
    You are a friendly nutrition assistant gathering information to create a personalized 7-day meal plan.
    
    BEHAVIOR RULES:
    1. Ask ONE focused, conversational question at a time
    2. Be warm and encouraging, not clinical
    3. Remember what the user already told you - don't repeat questions
    4. After gathering enough info (typically 3-6 exchanges), indicate you're ready
    5. You can be ready earlier if user provides comprehensive info upfront
    6. SKIP questions about info already in USER CONTEXT - use that data directly
    
    INFORMATION TO GATHER (only if not in context):
    - Dietary restrictions or allergies
    - Calorie goals (if any)
    - Cooking time preference (quick meals vs elaborate)
    - Budget constraints
    - Cuisine preferences
    - Household size / servings needed
    - Specific health goals
    
    RESPOND WITH EXACTLY THIS JSON FORMAT:
    
    If you need more info:
    {
        "type": "question",
        "message": "<Your friendly question to the user>"
    }
    
    If you have enough info:
    {
        "type": "ready",
        "message": "<Friendly message saying you're ready to create their plan>",
        "summary": "<Brief summary of their preferences you collected>"
    }
    
    IMPORTANT: Output valid JSON only. No markdown, no explanatory text.
    """
    
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

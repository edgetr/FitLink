import Foundation

/// Feature flags for enabling/disabling app features at runtime
/// Read from UserDefaults for persistence
struct FeatureFlags {
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let unifiedDateStrip = "feature_unified_date_strip"
        static let liquidGlass = "feature_liquid_glass"
        static let workoutQnA = "feature_workout_qna"
        static let dietPlanClarifications = "feature_diet_plan_clarifications"
        static let liveActivity = "feature_live_activity"
        static let hapticFeedback = "feature_haptic_feedback"
        static let advancedAnalytics = "feature_advanced_analytics"
    }
    
    // MARK: - Feature Toggle Properties
    
    /// Whether to use the unified date strip design across the app
    static var isUnifiedDateStripEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.unifiedDateStrip, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.unifiedDateStrip) }
    }
    
    /// Whether to use the liquid glass design system
    static var isLiquidGlassEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.liquidGlass, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.liquidGlass) }
    }
    
    /// Whether to enable the workout Q&A wizard flow
    static var isWorkoutQnAEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.workoutQnA, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.workoutQnA) }
    }
    
    /// Whether to ask clarifying questions before diet plan generation
    static var isDietPlanClarificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.dietPlanClarifications, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.dietPlanClarifications) }
    }
    
    /// Whether Live Activity (Dynamic Island) is enabled for focus timer
    static var isLiveActivityEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.liveActivity, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.liveActivity) }
    }
    
    /// Whether haptic feedback is enabled throughout the app
    static var isHapticFeedbackEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.hapticFeedback, defaultValue: true) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hapticFeedback) }
    }
    
    /// Whether advanced analytics features are enabled
    static var isAdvancedAnalyticsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.advancedAnalytics, defaultValue: false) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.advancedAnalytics) }
    }
    
    // MARK: - Reset
    
    /// Reset all feature flags to their default values
    static func resetToDefaults() {
        isUnifiedDateStripEnabled = true
        isLiquidGlassEnabled = true
        isWorkoutQnAEnabled = true
        isDietPlanClarificationsEnabled = true
        isLiveActivityEnabled = true
        isHapticFeedbackEnabled = true
        isAdvancedAnalyticsEnabled = false
    }
    
    // MARK: - Debug
    
    #if DEBUG
    /// Enable all features for testing
    static func enableAllFeatures() {
        isUnifiedDateStripEnabled = true
        isLiquidGlassEnabled = true
        isWorkoutQnAEnabled = true
        isDietPlanClarificationsEnabled = true
        isLiveActivityEnabled = true
        isHapticFeedbackEnabled = true
        isAdvancedAnalyticsEnabled = true
    }
    
    /// Disable all features for testing minimal mode
    static func disableAllFeatures() {
        isUnifiedDateStripEnabled = false
        isLiquidGlassEnabled = false
        isWorkoutQnAEnabled = false
        isDietPlanClarificationsEnabled = false
        isLiveActivityEnabled = false
        isHapticFeedbackEnabled = false
        isAdvancedAnalyticsEnabled = false
    }
    #endif
}

// MARK: - UserDefaults Extension

private extension UserDefaults {
    /// Get a boolean value with a default if the key doesn't exist
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return bool(forKey: key)
    }
}

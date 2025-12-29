import AppIntents

// MARK: - FitLink Shortcuts Provider

/// iOS limits apps to 10 App Shortcuts. We prioritize the most used voice commands.
/// Note: All 11 intents still work in the Shortcuts app - only the voice phrases are limited.
struct FitLinkShortcuts: AppShortcutsProvider {
    
    static var appShortcuts: [AppShortcut] {
        
        // MARK: - Focus Timer Shortcuts (P0 - Most Used)
        
        AppShortcut(
            intent: StartFocusTimerIntent(),
            phrases: [
                "Start focus timer in \(.applicationName)",
                "Start my focus session in \(.applicationName)",
                "Begin focus mode with \(.applicationName)",
                "Start focusing in \(.applicationName)"
            ],
            shortTitle: "Start Focus",
            systemImageName: "brain.head.profile"
        )
        
        AppShortcut(
            intent: StopFocusTimerIntent(),
            phrases: [
                "Stop focus timer in \(.applicationName)",
                "End my focus session in \(.applicationName)",
                "Stop focusing in \(.applicationName)"
            ],
            shortTitle: "Stop Focus",
            systemImageName: "stop.circle"
        )
        
        AppShortcut(
            intent: PauseFocusTimerIntent(),
            phrases: [
                "Pause focus timer in \(.applicationName)",
                "Pause my focus session in \(.applicationName)",
                "Take a break in \(.applicationName)"
            ],
            shortTitle: "Pause Focus",
            systemImageName: "pause.circle"
        )
        
        AppShortcut(
            intent: ResumeFocusTimerIntent(),
            phrases: [
                "Resume focus timer in \(.applicationName)",
                "Continue my focus session in \(.applicationName)"
            ],
            shortTitle: "Resume Focus",
            systemImageName: "play.circle"
        )
        
        AppShortcut(
            intent: GetFocusStatusIntent(),
            phrases: [
                "How much focus time left in \(.applicationName)",
                "Focus timer status in \(.applicationName)",
                "Check my focus session in \(.applicationName)"
            ],
            shortTitle: "Focus Status",
            systemImageName: "timer"
        )
        
        // MARK: - Habit Shortcuts (P1)
        
        AppShortcut(
            intent: LogHabitIntent(),
            phrases: [
                "Log habit in \(.applicationName)",
                "Complete habit in \(.applicationName)",
                "Mark habit done in \(.applicationName)"
            ],
            shortTitle: "Log Habit",
            systemImageName: "checkmark.circle"
        )
        
        AppShortcut(
            intent: GetHabitStatusIntent(),
            phrases: [
                "What habits have I completed in \(.applicationName)",
                "Habit status in \(.applicationName)",
                "Check my habits in \(.applicationName)"
            ],
            shortTitle: "Habit Status",
            systemImageName: "list.bullet.circle"
        )
        
        AppShortcut(
            intent: GetStreakIntent(),
            phrases: [
                "What's my habit streak in \(.applicationName)",
                "Check my streak in \(.applicationName)"
            ],
            shortTitle: "Check Streak",
            systemImageName: "flame"
        )
        
        // MARK: - Health Shortcuts (P2)
        
        AppShortcut(
            intent: GetStepsIntent(),
            phrases: [
                "What's my step count in \(.applicationName)",
                "How many steps in \(.applicationName)",
                "Steps today in \(.applicationName)"
            ],
            shortTitle: "Step Count",
            systemImageName: "figure.walk"
        )
        
        AppShortcut(
            intent: GetHealthSummaryIntent(),
            phrases: [
                "Health summary in \(.applicationName)",
                "How am I doing today in \(.applicationName)",
                "My activity summary in \(.applicationName)"
            ],
            shortTitle: "Health Summary",
            systemImageName: "heart.fill"
        )
        
        // Note: GetCaloriesIntent is available in Shortcuts app but not exposed as a voice shortcut
        // to stay within the 10 shortcut limit. Users can still create Siri phrases manually.
    }
}

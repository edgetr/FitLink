import SwiftUI

enum FitLinkIcon: String, CaseIterable {
    case backButton = "BackButton"
    case calories = "Calories"
    case close = "Close"
    case diet = "Diet"
    case exercise = "Exercise"
    case friends = "Friends"
    case habits = "Habits"
    case heartRate = "HeartRate"
    case home = "Home"
    case notification = "Notification"
    case profile = "Profile"
    case quotes = "Quotes"
    case send = "Send"
    case sleep = "Sleep"
    case steps = "Steps"
    case streaks = "Streaks"
    case tips = "Tips"
    case workouts = "Workouts"
    
    var sfSymbolFallback: String {
        switch self {
        case .backButton: return "chevron.left"
        case .calories: return "flame.fill"
        case .close: return "xmark"
        case .diet: return "fork.knife"
        case .exercise: return "figure.run"
        case .friends: return "person.2.fill"
        case .habits: return "checkmark.circle.fill"
        case .heartRate: return "heart.fill"
        case .home: return "house.fill"
        case .notification: return "bell.fill"
        case .profile: return "person.fill"
        case .quotes: return "quote.opening"
        case .send: return "paperplane.fill"
        case .sleep: return "moon.zzz.fill"
        case .steps: return "figure.walk"
        case .streaks: return "trophy.fill"
        case .tips: return "lightbulb.fill"
        case .workouts: return "dumbbell.fill"
        }
    }
    
    @ViewBuilder
    func image(renderingMode: Image.TemplateRenderingMode = .template) -> some View {
        Image(self.rawValue)
            .renderingMode(renderingMode)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
    
    func fallbackImage() -> Image {
        Image(systemName: sfSymbolFallback)
    }
}

// MARK: - Convenience Extensions

extension Image {
    init(fitLinkIcon: FitLinkIcon) {
        self.init(fitLinkIcon.rawValue)
    }
}

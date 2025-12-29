import Foundation
import SwiftUI

// MARK: - Habit Category

enum HabitCategory: String, Codable, CaseIterable {
    case health = "health"
    case fitness = "fitness"
    case productivity = "productivity"
    case learning = "learning"
    case mindfulness = "mindfulness"
    case social = "social"
    case creativity = "creativity"
    case finance = "finance"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var defaultIcon: String {
        switch self {
        case .health: return "heart.fill"
        case .fitness: return "figure.run"
        case .productivity: return "checklist"
        case .learning: return "book.fill"
        case .mindfulness: return "brain.head.profile"
        case .social: return "person.2.fill"
        case .creativity: return "paintbrush.fill"
        case .finance: return "dollarsign.circle.fill"
        }
    }
    
    var defaultDuration: Int {
        switch self {
        case .health: return 15
        case .fitness: return 30
        case .productivity: return 25
        case .learning: return 25
        case .mindfulness: return 10
        case .social: return 20
        case .creativity: return 30
        case .finance: return 15
        }
    }
    
    var color: Color {
        switch self {
        case .health: return .red
        case .fitness: return .orange
        case .productivity: return .blue
        case .learning: return .purple
        case .mindfulness: return .cyan
        case .social: return .pink
        case .creativity: return .yellow
        case .finance: return .green
        }
    }
}

// MARK: - Time of Day

enum HabitTimeOfDay: String, Codable, CaseIterable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case anytime = "anytime"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "moon.fill"
        case .anytime: return "clock.fill"
        }
    }
}

// MARK: - Habit

struct Habit: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var createdAt: Date
    var endDate: Date?
    var completionDates: [Date]
    
    // New fields for enhanced habits
    var icon: String
    var category: HabitCategory
    var suggestedDurationMinutes: Int
    var preferredTime: HabitTimeOfDay
    var reminderTime: Date?
    var notes: String?
    var isAIGenerated: Bool
    var motivationalTip: String?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        endDate: Date? = nil,
        completionDates: [Date] = [],
        icon: String = "checkmark.circle.fill",
        category: HabitCategory = .productivity,
        suggestedDurationMinutes: Int = 25,
        preferredTime: HabitTimeOfDay = .anytime,
        reminderTime: Date? = nil,
        notes: String? = nil,
        isAIGenerated: Bool = false,
        motivationalTip: String? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.endDate = endDate
        self.completionDates = completionDates
        self.icon = icon
        self.category = category
        self.suggestedDurationMinutes = suggestedDurationMinutes
        self.preferredTime = preferredTime
        self.reminderTime = reminderTime
        self.notes = notes
        self.isAIGenerated = isAIGenerated
        self.motivationalTip = motivationalTip
    }
    
    // MARK: - Computed Properties
    
    /// Current streak in days
    var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = today
        
        // Sort completion dates descending
        let sortedDates = completionDates
            .map { calendar.startOfDay(for: $0) }
            .sorted(by: >)
        
        // Check if today is completed
        guard let firstDate = sortedDates.first else { return 0 }
        
        // If most recent completion is not today or yesterday, streak is 0
        let daysSinceLastCompletion = calendar.dateComponents([.day], from: firstDate, to: today).day ?? 0
        if daysSinceLastCompletion > 1 {
            return 0
        }
        
        // Count consecutive days
        for date in sortedDates {
            if calendar.isDate(date, inSameDayAs: checkDate) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else if date < checkDate {
                break
            }
        }
        
        return streak
    }
    
    /// Longest streak ever achieved
    var longestStreak: Int {
        let calendar = Calendar.current
        let sortedDates = completionDates
            .map { calendar.startOfDay(for: $0) }
            .sorted()
        
        guard !sortedDates.isEmpty else { return 0 }
        
        var longest = 1
        var current = 1
        
        for i in 1..<sortedDates.count {
            let prevDate = sortedDates[i - 1]
            let currDate = sortedDates[i]
            
            if let dayDiff = calendar.dateComponents([.day], from: prevDate, to: currDate).day, dayDiff == 1 {
                current += 1
                longest = max(longest, current)
            } else if !calendar.isDate(prevDate, inSameDayAs: currDate) {
                current = 1
            }
        }
        
        return longest
    }
    
    /// Completion rate (last 30 days)
    var completionRate: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        let createdNormalized = calendar.startOfDay(for: createdAt)
        
        // Start from whichever is later: creation date or 30 days ago
        let startDate = max(thirtyDaysAgo, createdNormalized)
        
        guard let dayCount = calendar.dateComponents([.day], from: startDate, to: today).day, dayCount > 0 else {
            return 0
        }
        
        let completionsInRange = completionDates.filter { date in
            let normalized = calendar.startOfDay(for: date)
            return normalized >= startDate && normalized <= today
        }.count
        
        return Double(completionsInRange) / Double(dayCount + 1)
    }
    
    // MARK: - Helpers
    
    static func normalizeDate(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
    
    // MARK: - Codable with Migration Support
    
    enum CodingKeys: String, CodingKey {
        case id, name, createdAt, endDate, completionDates
        case icon, category, suggestedDurationMinutes, preferredTime
        case reminderTime, notes, isAIGenerated, motivationalTip
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        completionDates = try container.decode([Date].self, forKey: .completionDates)
        
        // New optional fields with defaults for migration
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "checkmark.circle.fill"
        category = try container.decodeIfPresent(HabitCategory.self, forKey: .category) ?? .productivity
        suggestedDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .suggestedDurationMinutes) ?? 25
        preferredTime = try container.decodeIfPresent(HabitTimeOfDay.self, forKey: .preferredTime) ?? .anytime
        reminderTime = try container.decodeIfPresent(Date.self, forKey: .reminderTime)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isAIGenerated = try container.decodeIfPresent(Bool.self, forKey: .isAIGenerated) ?? false
        motivationalTip = try container.decodeIfPresent(String.self, forKey: .motivationalTip)
    }
}

// MARK: - Habit Extension for AI Suggestions

extension Habit {
    /// Create a habit from an AI suggestion
    static func from(suggestion: HabitSuggestion) -> Habit {
        let category = HabitCategory(rawValue: suggestion.category.lowercased()) ?? .productivity
        let timeOfDay = HabitTimeOfDay(rawValue: suggestion.preferredTimeOfDay.lowercased()) ?? .anytime
        
        return Habit(
            name: suggestion.title,
            icon: suggestion.icon,
            category: category,
            suggestedDurationMinutes: suggestion.suggestedDurationMinutes,
            preferredTime: timeOfDay,
            isAIGenerated: true,
            motivationalTip: suggestion.motivationalTip
        )
    }
    
    /// Apply AI suggestion to existing habit
    mutating func apply(suggestion: HabitSuggestion) {
        self.icon = suggestion.icon
        if let category = HabitCategory(rawValue: suggestion.category.lowercased()) {
            self.category = category
        }
        self.suggestedDurationMinutes = suggestion.suggestedDurationMinutes
        if let timeOfDay = HabitTimeOfDay(rawValue: suggestion.preferredTimeOfDay.lowercased()) {
            self.preferredTime = timeOfDay
        }
        self.motivationalTip = suggestion.motivationalTip
        self.isAIGenerated = true
    }
}

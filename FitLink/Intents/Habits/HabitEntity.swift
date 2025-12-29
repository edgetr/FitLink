import AppIntents

// MARK: - Habit Entity

struct HabitEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"
    
    static var defaultQuery = HabitEntityQuery()
    
    let id: String
    let name: String
    let icon: String
    let category: String
    let currentStreak: Int
    
    var displayRepresentation: DisplayRepresentation {
        var subtitle: String? = nil
        if currentStreak > 0 {
            subtitle = "\(currentStreak) day streak"
        }
        
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: subtitle.map { LocalizedStringResource(stringLiteral: $0) },
            image: .init(systemName: icon)
        )
    }
    
    init(id: String, name: String, icon: String, category: String = "productivity", currentStreak: Int = 0) {
        self.id = id
        self.name = name
        self.icon = icon
        self.category = category
        self.currentStreak = currentStreak
    }
    
    init(from habit: Habit) {
        self.id = habit.id.uuidString
        self.name = habit.name
        self.icon = habit.icon
        self.category = habit.category.rawValue
        self.currentStreak = habit.currentStreak
    }
}

// MARK: - Habit Entity Query

struct HabitEntityQuery: EntityQuery {
    
    func entities(for identifiers: [String]) async throws -> [HabitEntity] {
        let habits = try await HabitStore.shared.loadHabits(userId: nil)
        return habits
            .filter { identifiers.contains($0.id.uuidString) }
            .map { HabitEntity(from: $0) }
    }
    
    func suggestedEntities() async throws -> [HabitEntity] {
        let habits = try await HabitStore.shared.loadHabits(userId: nil)
        // Prioritize habits with active streaks
        let sorted = habits.sorted { $0.currentStreak > $1.currentStreak }
        return sorted.map { HabitEntity(from: $0) }
    }
    
    func defaultResult() async -> HabitEntity? {
        // Return the habit with the longest streak as default
        let habits = try? await HabitStore.shared.loadHabits(userId: nil)
        guard let topHabit = habits?.max(by: { $0.currentStreak < $1.currentStreak }) else {
            return nil
        }
        return HabitEntity(from: topHabit)
    }
}

// MARK: - Habit Entity String Query (for search)

extension HabitEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [HabitEntity] {
        let habits = try await HabitStore.shared.loadHabits(userId: nil)
        let lowercasedQuery = string.lowercased()
        
        return habits
            .filter { $0.name.lowercased().contains(lowercasedQuery) }
            .map { HabitEntity(from: $0) }
    }
}

// MARK: - Habit Options Provider

struct HabitOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [HabitEntity] {
        let habits = try await HabitStore.shared.loadHabits(userId: nil)
        return habits.map { HabitEntity(from: $0) }
    }
}

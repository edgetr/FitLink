import Foundation
import FirebaseFirestore

// MARK: - Plan Type

enum WorkoutPlanType: String, Codable, CaseIterable {
    case home
    case gym
    
    var displayName: String {
        switch self {
        case .home: return "Home Workout"
        case .gym: return "Gym Workout"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .gym: return "dumbbell.fill"
        }
    }
}

// MARK: - Workout Exercise

struct WorkoutExercise: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var sets: Int?
    var reps: String?
    var durationSeconds: Int?
    var restSeconds: Int?
    var notes: String?
    var equipmentNeeded: String?
    
    init(
        id: UUID = UUID(),
        name: String,
        sets: Int? = nil,
        reps: String? = nil,
        durationSeconds: Int? = nil,
        restSeconds: Int? = nil,
        notes: String? = nil,
        equipmentNeeded: String? = nil
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.restSeconds = restSeconds
        self.notes = notes
        self.equipmentNeeded = equipmentNeeded
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.sets = try container.decodeIfPresent(Int.self, forKey: .sets)
        self.reps = try container.decodeIfPresent(String.self, forKey: .reps)
        self.durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
        self.restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.equipmentNeeded = try container.decodeIfPresent(String.self, forKey: .equipmentNeeded)
    }
    
    var formattedSetsReps: String {
        if let sets = sets, let reps = reps {
            return "\(sets) × \(reps)"
        } else if let sets = sets {
            return "\(sets) sets"
        } else if let reps = reps {
            return reps
        } else if let duration = durationSeconds {
            return formatDuration(duration)
        }
        return ""
    }
    
    var formattedRest: String? {
        guard let rest = restSeconds else { return nil }
        return "Rest: \(formatDuration(rest))"
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        if seconds >= 60 {
            let minutes = seconds / 60
            let secs = seconds % 60
            return secs > 0 ? "\(minutes)m \(secs)s" : "\(minutes) min"
        }
        return "\(seconds)s"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case sets
        case reps
        case durationSeconds = "duration_seconds"
        case restSeconds = "rest_seconds"
        case notes
        case equipmentNeeded = "equipment_needed"
    }
}

// MARK: - Workout Day

struct WorkoutDay: Identifiable, Codable, Hashable {
    var id: UUID
    var day: Int
    var date: String
    var isRestDay: Bool
    var focus: [String]
    var exercises: [WorkoutExercise]
    var notes: String?
    var warmup: [WorkoutExercise]?
    var cooldown: [WorkoutExercise]?
    
    init(
        id: UUID = UUID(),
        day: Int,
        date: String = "",
        isRestDay: Bool = false,
        focus: [String] = [],
        exercises: [WorkoutExercise] = [],
        notes: String? = nil,
        warmup: [WorkoutExercise]? = nil,
        cooldown: [WorkoutExercise]? = nil
    ) {
        self.id = id
        self.day = day
        self.date = date
        self.isRestDay = isRestDay
        self.focus = focus
        self.exercises = exercises
        self.notes = notes
        self.warmup = warmup
        self.cooldown = cooldown
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.day = try container.decode(Int.self, forKey: .day)
        self.date = (try? container.decode(String.self, forKey: .date)) ?? ""
        self.isRestDay = (try? container.decode(Bool.self, forKey: .isRestDay)) ?? false
        self.focus = (try? container.decode([String].self, forKey: .focus)) ?? []
        self.exercises = (try? container.decode([WorkoutExercise].self, forKey: .exercises)) ?? []
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.warmup = try container.decodeIfPresent([WorkoutExercise].self, forKey: .warmup)
        self.cooldown = try container.decodeIfPresent([WorkoutExercise].self, forKey: .cooldown)
    }
    
    var formattedFocus: String {
        guard !focus.isEmpty else {
            return isRestDay ? "Rest & Recovery" : "Full Body"
        }
        return focus.joined(separator: " & ")
    }
    
    var totalExercises: Int {
        exercises.count
    }
    
    var estimatedDurationMinutes: Int {
        var total = 0
        for exercise in exercises {
            if let duration = exercise.durationSeconds {
                total += duration
            } else if let sets = exercise.sets {
                total += sets * 45
            } else {
                total += 60
            }
            if let rest = exercise.restSeconds {
                total += rest * (exercise.sets ?? 1)
            }
        }
        return total / 60
    }
    
    var dayOfWeek: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        if let parsedDate = dateFormatter.date(from: date) {
            dateFormatter.dateFormat = "EEEE"
            return dateFormatter.string(from: parsedDate)
        }
        return "Day \(day)"
    }
    
    var shortDayOfWeek: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        if let parsedDate = dateFormatter.date(from: date) {
            dateFormatter.dateFormat = "EEE"
            return dateFormatter.string(from: parsedDate)
        }
        return "D\(day)"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case day
        case date
        case isRestDay = "is_rest_day"
        case focus
        case exercises
        case notes
        case warmup
        case cooldown
    }
}

// MARK: - Weekly Workout Plan

struct WeeklyWorkoutPlan: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var totalDays: Int
    var days: [WorkoutDay]
    var createdAt: Date
    var difficulty: WorkoutDifficulty
    var equipment: [String]
    var goals: [String]
    
    init(
        id: UUID = UUID(),
        title: String = "Weekly Workout Plan",
        totalDays: Int = 7,
        days: [WorkoutDay] = [],
        createdAt: Date = Date(),
        difficulty: WorkoutDifficulty = .intermediate,
        equipment: [String] = [],
        goals: [String] = []
    ) {
        self.id = id
        self.title = title
        self.totalDays = totalDays
        self.days = days
        self.createdAt = createdAt
        self.difficulty = difficulty
        self.equipment = equipment
        self.goals = goals
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.title = (try? container.decode(String.self, forKey: .title)) ?? "Weekly Workout Plan"
        self.totalDays = (try? container.decode(Int.self, forKey: .totalDays)) ?? 7
        self.days = (try? container.decode([WorkoutDay].self, forKey: .days)) ?? []
        self.createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        self.difficulty = (try? container.decode(WorkoutDifficulty.self, forKey: .difficulty)) ?? .intermediate
        self.equipment = (try? container.decode([String].self, forKey: .equipment)) ?? []
        self.goals = (try? container.decode([String].self, forKey: .goals)) ?? []
    }
    
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: createdAt)
    }
    
    var workoutDaysCount: Int {
        days.filter { !$0.isRestDay }.count
    }
    
    var restDaysCount: Int {
        days.filter { $0.isRestDay }.count
    }
    
    var weekDateRange: String {
        guard !days.isEmpty else { return "" }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let firstDate = dateFormatter.date(from: days.first?.date ?? ""),
              let lastDate = dateFormatter.date(from: days.last?.date ?? "") else {
            return ""
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d"
        
        return "\(displayFormatter.string(from: firstDate)) - \(displayFormatter.string(from: lastDate))"
    }
    
    func formattedForSharing() -> String {
        var text = "🏋️ \(title)\n"
        text += "📅 \(weekDateRange)\n"
        text += "💪 \(workoutDaysCount) workout days, \(restDaysCount) rest days\n\n"
        
        for day in days {
            text += "━━━━━━━━━━━━━━━━━━━━\n"
            text += "📆 Day \(day.day): \(day.formattedFocus)\n"
            
            if day.isRestDay {
                text += "🧘 Rest Day\n"
            } else {
                for exercise in day.exercises {
                    text += "• \(exercise.name)"
                    if !exercise.formattedSetsReps.isEmpty {
                        text += " - \(exercise.formattedSetsReps)"
                    }
                    text += "\n"
                }
            }
            text += "\n"
        }
        
        return text
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case totalDays = "total_days"
        case days
        case createdAt = "created_at"
        case difficulty
        case equipment
        case goals
    }
    
    static var sample: WeeklyWorkoutPlan {
        let sampleExercises = [
            WorkoutExercise(name: "Push-ups", sets: 3, reps: "12-15", restSeconds: 60),
            WorkoutExercise(name: "Squats", sets: 3, reps: "15", restSeconds: 60),
            WorkoutExercise(name: "Plank", durationSeconds: 60, restSeconds: 30)
        ]
        
        let sampleDays = [
            WorkoutDay(day: 1, date: "2025-12-24", focus: ["Full Body"], exercises: sampleExercises),
            WorkoutDay(day: 2, date: "2025-12-25", isRestDay: true, focus: ["Recovery"])
        ]
        
        return WeeklyWorkoutPlan(
            title: "Beginner Full Body",
            days: sampleDays,
            difficulty: .beginner,
            equipment: ["None"],
            goals: ["Build strength", "Improve endurance"]
        )
    }
}

// MARK: - Workout Difficulty

enum WorkoutDifficulty: String, Codable, CaseIterable {
    case beginner
    case intermediate
    case advanced
    
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
    
    var icon: String {
        switch self {
        case .beginner: return "leaf.fill"
        case .intermediate: return "flame.fill"
        case .advanced: return "bolt.fill"
        }
    }
}

// MARK: - Workout Plan Document (Firestore)

struct WorkoutPlanDocument: Identifiable, Codable {
    var id: String
    var userId: String
    var planType: WorkoutPlanType
    var preferences: String
    var bundleId: String
    var createdAt: Date
    var lastUpdated: Date
    var plan: WeeklyWorkoutPlan
    var weekStartDate: Date
    var weekEndDate: Date
    var isArchived: Bool
    var archivedAt: Date?
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        planType: WorkoutPlanType,
        preferences: String = "",
        bundleId: String = UUID().uuidString,
        createdAt: Date = Date(),
        lastUpdated: Date = Date(),
        plan: WeeklyWorkoutPlan = WeeklyWorkoutPlan(),
        weekStartDate: Date = Date(),
        weekEndDate: Date = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date(),
        isArchived: Bool = false,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.planType = planType
        self.preferences = preferences
        self.bundleId = bundleId
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
        self.plan = plan
        self.weekStartDate = weekStartDate
        self.weekEndDate = weekEndDate
        self.isArchived = isArchived
        self.archivedAt = archivedAt
    }
    
    var formattedWeekRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: weekStartDate)) - \(formatter.string(from: weekEndDate))"
    }
    
    var isCurrentWeek: Bool {
        let now = Date()
        return now >= weekStartDate && now <= weekEndDate
    }
    
    var shouldArchive: Bool {
        Date() > weekEndDate && !isArchived
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case planType = "plan_type"
        case preferences
        case bundleId = "bundle_id"
        case createdAt = "created_at"
        case lastUpdated = "last_updated"
        case plan
        case weekStartDate = "week_start_date"
        case weekEndDate = "week_end_date"
        case isArchived = "is_archived"
        case archivedAt = "archived_at"
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "user_id": userId,
            "plan_type": planType.rawValue,
            "preferences": preferences,
            "bundle_id": bundleId,
            "created_at": Timestamp(date: createdAt),
            "last_updated": Timestamp(date: lastUpdated),
            "week_start_date": Timestamp(date: weekStartDate),
            "week_end_date": Timestamp(date: weekEndDate),
            "is_archived": isArchived
        ]
        
        if let archivedAt = archivedAt {
            dict["archived_at"] = Timestamp(date: archivedAt)
        }
        
        if let planData = try? JSONEncoder().encode(plan),
           let planJSON = String(data: planData, encoding: .utf8) {
            dict["plan_json"] = planJSON
        }
        
        return dict
    }
    
    static func fromDictionary(_ data: [String: Any], id: String) -> WorkoutPlanDocument? {
        guard let userId = data["user_id"] as? String,
              let planTypeRaw = data["plan_type"] as? String,
              let planType = WorkoutPlanType(rawValue: planTypeRaw) else {
            return nil
        }
        
        var doc = WorkoutPlanDocument(
            id: id,
            userId: userId,
            planType: planType,
            preferences: data["preferences"] as? String ?? "",
            bundleId: data["bundle_id"] as? String ?? id
        )
        
        if let createdAt = (data["created_at"] as? Timestamp)?.dateValue() {
            doc.createdAt = createdAt
        }
        if let lastUpdated = (data["last_updated"] as? Timestamp)?.dateValue() {
            doc.lastUpdated = lastUpdated
        }
        if let weekStartDate = (data["week_start_date"] as? Timestamp)?.dateValue() {
            doc.weekStartDate = weekStartDate
        }
        if let weekEndDate = (data["week_end_date"] as? Timestamp)?.dateValue() {
            doc.weekEndDate = weekEndDate
        }
        if let archivedAt = (data["archived_at"] as? Timestamp)?.dateValue() {
            doc.archivedAt = archivedAt
        }
        
        doc.isArchived = data["is_archived"] as? Bool ?? false
        
        if let planJSON = data["plan_json"] as? String,
           let planData = planJSON.data(using: .utf8),
           let plan = try? JSONDecoder().decode(WeeklyWorkoutPlan.self, from: planData) {
            doc.plan = plan
        }
        
        return doc
    }
}

// MARK: - Plan Selection

enum PlanSelection: String, CaseIterable {
    case home
    case gym
    case both
    
    var displayName: String {
        switch self {
        case .home: return "Home Only"
        case .gym: return "Gym Only"
        case .both: return "Both"
        }
    }
    
    var planTypes: [WorkoutPlanType] {
        switch self {
        case .home: return [.home]
        case .gym: return [.gym]
        case .both: return [.home, .gym]
        }
    }
}

// MARK: - Wizard Flow State

enum WizardFlowState: Equatable {
    case idle
    case conversing
    case readyToGenerate
    case generatingPlan
    case planReady
    case failed(String)
    
    var isLoading: Bool {
        self == .generatingPlan
    }
    
    var canGeneratePlan: Bool {
        switch self {
        case .idle, .readyToGenerate, .failed:
            return true
        default:
            return false
        }
    }
}

// MARK: - Follow Up Question

struct FollowUpQuestion: Identifiable, Codable, Hashable {
    let id: String
    let text: String
    let answerKind: AnswerKind
    let choices: [String]?
    let context: QuestionContext
    let isRequired: Bool
    let hint: String?
    
    init(
        id: String = UUID().uuidString,
        text: String,
        answerKind: AnswerKind = .text,
        choices: [String]? = nil,
        context: QuestionContext = .common,
        isRequired: Bool = false,
        hint: String? = nil
    ) {
        self.id = id
        self.text = text
        self.answerKind = answerKind
        self.choices = choices
        self.context = context
        self.isRequired = isRequired
        self.hint = hint
    }
    
    enum AnswerKind: String, Codable, Hashable {
        case text
        case number
        case choice
        case binary
    }
    
    enum QuestionContext: String, Codable, Hashable {
        case home
        case gym
        case common
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case answerKind = "answer_kind"
        case choices
        case context
        case isRequired = "is_required"
        case hint
    }
}

// MARK: - Answer Value

enum AnswerValue: Codable, Hashable {
    case text(String)
    case number(Int)
    case boolean(Bool)
    case selected(String)
    
    var stringValue: String {
        switch self {
        case .text(let value): return value
        case .number(let value): return "\(value)"
        case .boolean(let value): return value ? "Yes" : "No"
        case .selected(let value): return value
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .text(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .number(intValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .boolean(boolValue)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode AnswerValue")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .boolean(let value): try container.encode(value)
        case .selected(let value): try container.encode(value)
        }
    }
}

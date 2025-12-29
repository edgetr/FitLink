import Foundation
import FirebaseFirestore

enum ChallengeType: String, Codable, CaseIterable, Sendable {
    case steps
    case calories
    case workoutCount = "workout_count"
    case streak
    
    var displayName: String {
        switch self {
        case .steps: return "Steps"
        case .calories: return "Calories"
        case .workoutCount: return "Workouts"
        case .streak: return "Streak"
        }
    }
    
    var icon: String {
        switch self {
        case .steps: return "figure.walk"
        case .calories: return "flame.fill"
        case .workoutCount: return "dumbbell.fill"
        case .streak: return "flame"
        }
    }
    
    var unit: String {
        switch self {
        case .steps: return "steps"
        case .calories: return "cal"
        case .workoutCount: return "workouts"
        case .streak: return "days"
        }
    }
}

enum ChallengeStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case active
    case completed
    case declined
    case cancelled
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .active: return "Active"
        case .completed: return "Completed"
        case .declined: return "Declined"
        case .cancelled: return "Cancelled"
        }
    }
}

struct Challenge: Identifiable, Codable, Sendable {
    let id: String
    let chatId: String
    let challengerId: String
    let challengedId: String
    let type: ChallengeType
    let target: Int
    let durationDays: Int
    var status: ChallengeStatus
    var progress: [String: Int]
    var winnerId: String?
    let createdAt: Date
    var endsAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case chatId = "chat_id"
        case challengerId = "challenger_id"
        case challengedId = "challenged_id"
        case type
        case target
        case durationDays = "duration_days"
        case status
        case progress
        case winnerId = "winner_id"
        case createdAt = "created_at"
        case endsAt = "ends_at"
    }
    
    init(
        id: String = UUID().uuidString,
        chatId: String,
        challengerId: String,
        challengedId: String,
        type: ChallengeType,
        target: Int,
        durationDays: Int,
        status: ChallengeStatus = .pending,
        progress: [String: Int]? = nil,
        winnerId: String? = nil,
        createdAt: Date = Date(),
        endsAt: Date? = nil
    ) {
        self.id = id
        self.chatId = chatId
        self.challengerId = challengerId
        self.challengedId = challengedId
        self.type = type
        self.target = target
        self.durationDays = durationDays
        self.status = status
        self.progress = progress ?? [challengerId: 0, challengedId: 0]
        self.winnerId = winnerId
        self.createdAt = createdAt
        self.endsAt = endsAt ?? Calendar.current.date(byAdding: .day, value: durationDays, to: createdAt) ?? createdAt
    }
    
    func progressForUser(_ userId: String) -> Int {
        progress[userId] ?? 0
    }
    
    func progressPercentage(for userId: String) -> Double {
        let current = Double(progressForUser(userId))
        return min(current / Double(target), 1.0)
    }
    
    var isActive: Bool {
        status == .active && Date() < endsAt
    }
    
    var isExpired: Bool {
        Date() >= endsAt
    }
    
    var timeRemaining: TimeInterval {
        max(0, endsAt.timeIntervalSince(Date()))
    }
    
    var formattedTimeRemaining: String {
        let remaining = timeRemaining
        let days = Int(remaining / 86400)
        let hours = Int((remaining.truncatingRemainder(dividingBy: 86400)) / 3600)
        
        if days > 0 {
            return "\(days)d \(hours)h left"
        } else if hours > 0 {
            return "\(hours)h left"
        } else {
            let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(minutes)m left"
        }
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "chat_id": chatId,
            "challenger_id": challengerId,
            "challenged_id": challengedId,
            "type": type.rawValue,
            "target": target,
            "duration_days": durationDays,
            "status": status.rawValue,
            "progress": progress,
            "created_at": Timestamp(date: createdAt),
            "ends_at": Timestamp(date: endsAt)
        ]
        
        if let winnerId = winnerId {
            dict["winner_id"] = winnerId
        }
        
        return dict
    }
    
    static func fromDictionary(_ data: [String: Any], id: String) -> Challenge? {
        guard let chatId = data["chat_id"] as? String,
              let challengerId = data["challenger_id"] as? String,
              let challengedId = data["challenged_id"] as? String,
              let typeRaw = data["type"] as? String,
              let type = ChallengeType(rawValue: typeRaw),
              let target = data["target"] as? Int,
              let durationDays = data["duration_days"] as? Int,
              let statusRaw = data["status"] as? String,
              let status = ChallengeStatus(rawValue: statusRaw) else {
            return nil
        }
        
        let progress = data["progress"] as? [String: Int] ?? [:]
        let winnerId = data["winner_id"] as? String
        let createdAt = (data["created_at"] as? Timestamp)?.dateValue() ?? Date()
        let endsAt = (data["ends_at"] as? Timestamp)?.dateValue() ?? Date()
        
        return Challenge(
            id: id,
            chatId: chatId,
            challengerId: challengerId,
            challengedId: challengedId,
            type: type,
            target: target,
            durationDays: durationDays,
            status: status,
            progress: progress,
            winnerId: winnerId,
            createdAt: createdAt,
            endsAt: endsAt
        )
    }
    
    static var sample: Challenge {
        Challenge(
            id: "challenge-1",
            chatId: "chat_user1_user2",
            challengerId: "user1",
            challengedId: "user2",
            type: .steps,
            target: 10000,
            durationDays: 7,
            status: .active,
            progress: ["user1": 7500, "user2": 8200]
        )
    }
}

extension Challenge: Equatable {
    static func == (lhs: Challenge, rhs: Challenge) -> Bool {
        lhs.id == rhs.id
    }
}

extension Challenge: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

import Foundation
import FirebaseFirestore

struct FocusSession: Identifiable, Codable {
    let id: String
    let userId: String
    let habitId: String
    let habitName: String
    let habitIcon: String
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Int
    let wasCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case habitId = "habit_id"
        case habitName = "habit_name"
        case habitIcon = "habit_icon"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationSeconds = "duration_seconds"
        case wasCompleted = "was_completed"
    }

    var formattedDuration: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var durationMinutes: Double {
        Double(durationSeconds) / 60.0
    }

    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "user_id": userId,
            "habit_id": habitId,
            "habit_name": habitName,
            "habit_icon": habitIcon,
            "started_at": startedAt,
            "ended_at": endedAt,
            "duration_seconds": durationSeconds,
            "was_completed": wasCompleted
        ]
    }

    static func fromDictionary(_ data: [String: Any], id: String) -> FocusSession? {
        guard let userId = data["user_id"] as? String,
              let habitId = data["habit_id"] as? String,
              let habitName = data["habit_name"] as? String,
              let habitIcon = data["habit_icon"] as? String else {
            return nil
        }

        let startedAt = (data["started_at"] as? Timestamp)?.dateValue() ?? Date()
        let endedAt = (data["ended_at"] as? Timestamp)?.dateValue() ?? Date()
        let durationSeconds = data["duration_seconds"] as? Int ?? 0
        let wasCompleted = data["was_completed"] as? Bool ?? false

        return FocusSession(
            id: id,
            userId: userId,
            habitId: habitId,
            habitName: habitName,
            habitIcon: habitIcon,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: durationSeconds,
            wasCompleted: wasCompleted
        )
    }

    static var sample: FocusSession {
        FocusSession(
            id: "sample-session-id",
            userId: "sample-user-id",
            habitId: "sample-habit-id",
            habitName: "Deep Work",
            habitIcon: "brain.head.profile",
            startedAt: Date().addingTimeInterval(-3600),
            endedAt: Date(),
            durationSeconds: 3600,
            wasCompleted: true
        )
    }
}

import Foundation
import FirebaseFirestore

actor HabitFirestoreService {

    static let shared = HabitFirestoreService()

    private let db = Firestore.firestore()
    private let habitsCollection = "habits"

    private init() {}

    func loadHabits(userId: String) async throws -> [Habit] {
        AppLogger.shared.info("Loading habits for user: \(userId)", category: .habit)

        let snapshot = try await db.collection("users")
            .document(userId)
            .collection(habitsCollection)
            .order(by: "created_at", descending: true)
            .getDocuments()

        let habits = snapshot.documents.compactMap { doc in
            Habit.fromDictionary(doc.data(), id: doc.documentID)
        }

        AppLogger.shared.info("Loaded \(habits.count) habits for user: \(userId)", category: .habit)
        return habits
    }

    func saveHabit(_ habit: Habit, userId: String) async throws {
        AppLogger.shared.info("Saving habit: \(habit.id.uuidString) for user: \(userId)", category: .habit)

        let docRef = db.collection("users")
            .document(userId)
            .collection(habitsCollection)
            .document(habit.id.uuidString)

        let data = habit.toDictionary()
        try await docRef.setData(data)

        AppLogger.shared.info("Successfully saved habit: \(habit.id.uuidString)", category: .habit)
    }

    func saveHabits(_ habits: [Habit], userId: String) async throws {
        AppLogger.shared.info("Saving \(habits.count) habits for user: \(userId)", category: .habit)

        let batch = db.batch()

        for habit in habits {
            let docRef = db.collection("users")
                .document(userId)
                .collection(habitsCollection)
                .document(habit.id.uuidString)

            let data = habit.toDictionary()
            batch.setData(data, forDocument: docRef)
        }

        try await batch.commit()

        AppLogger.shared.info("Successfully saved \(habits.count) habits for user: \(userId)", category: .habit)
    }

    func updateHabitCompletion(habitId: String, userId: String, date: Date, completed: Bool) async throws {
        AppLogger.shared.info("Updating habit completion: \(habitId) for user: \(userId), date: \(date), completed: \(completed)", category: .habit)

        let docRef = db.collection("users")
            .document(userId)
            .collection(habitsCollection)
            .document(habitId)

        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        let timestamp = Timestamp(date: normalizedDate)

        let habitDoc = try await docRef.getDocument()
        guard let data = habitDoc.data(),
              let completionDates = data["completion_dates"] as? [Timestamp] else {
            throw HabitFirestoreServiceError.habitNotFound
        }

        var updatedDates: [Timestamp]
        if completed {
            if !completionDates.contains(where: { calendar.isDate($0.dateValue(), inSameDayAs: normalizedDate) }) {
                updatedDates = completionDates + [timestamp]
            } else {
                updatedDates = completionDates
            }
        } else {
            updatedDates = completionDates.filter { !calendar.isDate($0.dateValue(), inSameDayAs: normalizedDate) }
        }

        try await docRef.updateData([
            "completion_dates": updatedDates,
            "updated_at": Timestamp(date: Date())
        ])

        AppLogger.shared.info("Successfully updated habit completion: \(habitId)", category: .habit)
    }

    func toggleHabitCompletion(habitId: String, userId: String, date: Date) async throws -> Bool {
        AppLogger.shared.info("Toggling habit completion: \(habitId) for user: \(userId), date: \(date)", category: .habit)

        let docRef = db.collection("users")
            .document(userId)
            .collection(habitsCollection)
            .document(habitId)

        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        let timestamp = Timestamp(date: normalizedDate)

        let habitDoc = try await docRef.getDocument()
        guard let data = habitDoc.data(),
              let completionDates = data["completion_dates"] as? [Timestamp] else {
            throw HabitFirestoreServiceError.habitNotFound
        }

        let isCompleted = completionDates.contains { calendar.isDate($0.dateValue(), inSameDayAs: normalizedDate) }

        var updatedDates: [Timestamp]
        if isCompleted {
            updatedDates = completionDates.filter { !calendar.isDate($0.dateValue(), inSameDayAs: normalizedDate) }
        } else {
            updatedDates = completionDates + [timestamp]
        }

        try await docRef.updateData([
            "completion_dates": updatedDates,
            "updated_at": Timestamp(date: Date())
        ])

        AppLogger.shared.info("Toggled habit completion: \(habitId), now completed: \(!isCompleted)", category: .habit)
        return !isCompleted
    }

    func deleteHabit(habitId: String, userId: String) async throws {
        AppLogger.shared.info("Deleting habit: \(habitId) for user: \(userId)", category: .habit)

        try await db.collection("users")
            .document(userId)
            .collection(habitsCollection)
            .document(habitId)
            .delete()

        AppLogger.shared.info("Successfully deleted habit: \(habitId)", category: .habit)
    }

    func deleteAllHabits(userId: String) async throws {
        AppLogger.shared.info("Deleting all habits for user: \(userId)", category: .habit)

        let snapshot = try await db.collection("users")
            .document(userId)
            .collection(habitsCollection)
            .getDocuments()

        let batch = db.batch()
        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
        }

        try await batch.commit()

        AppLogger.shared.info("Successfully deleted all habits for user: \(userId)", category: .habit)
    }

    func observeHabits(userId: String) -> AsyncStream<[Habit]> {
        AsyncStream { [weak self] continuation in
            Task { [weak self] in
                guard let self = self else {
                    continuation.finish()
                    return
                }

                let listener = await self.db.collection("users")
                    .document(userId)
                    .collection(self.habitsCollection)
                    .order(by: "created_at", descending: true)
                    .addSnapshotListener { snapshot, error in
                        if let error = error {
                            AppLogger.shared.error("Habit listener error: \(error)", category: .habit)
                            continuation.finish()
                            return
                        }

                        guard let documents = snapshot?.documents else {
                            continuation.finish()
                            return
                        }

                        let habits = documents.compactMap { doc in
                            Habit.fromDictionary(doc.data(), id: doc.documentID)
                        }

                        continuation.yield(habits)
                    }

                continuation.onTermination = { @Sendable _ in
                    listener.remove()
                }
            }
        }
    }

    func loadHabit(byId habitId: String, userId: String) async throws -> Habit? {
        AppLogger.shared.info("Loading habit: \(habitId) for user: \(userId)", category: .habit)

        let doc = try await db.collection("users")
            .document(userId)
            .collection(habitsCollection)
            .document(habitId)
            .getDocument()

        guard let data = doc.data() else {
            AppLogger.shared.info("Habit not found: \(habitId)", category: .habit)
            return nil
        }

        let habit = Habit.fromDictionary(data, id: doc.documentID)
        AppLogger.shared.info("Successfully loaded habit: \(habitId)", category: .habit)
        return habit
    }

    func updateHabit(_ habit: Habit, userId: String) async throws {
        AppLogger.shared.info("Updating habit: \(habit.id.uuidString) for user: \(userId)", category: .habit)

        let docRef = db.collection("users")
            .document(userId)
            .collection(habitsCollection)
            .document(habit.id.uuidString)

        var data = habit.toDictionary()
        data["updated_at"] = Timestamp(date: Date())

        try await docRef.setData(data, merge: true)

        AppLogger.shared.info("Successfully updated habit: \(habit.id.uuidString)", category: .habit)
    }

    func markHabitCompletedToday(habitId: String, userId: String) async throws {
        let today = Calendar.current.startOfDay(for: Date())
        try await updateHabitCompletion(habitId: habitId, userId: userId, date: today, completed: true)
    }

    func markHabitIncompleteToday(habitId: String, userId: String) async throws {
        let today = Calendar.current.startOfDay(for: Date())
        try await updateHabitCompletion(habitId: habitId, userId: userId, date: today, completed: false)
    }
}

enum HabitFirestoreServiceError: LocalizedError {
    case habitNotFound
    case invalidData
    case updateFailed

    var errorDescription: String? {
        switch self {
        case .habitNotFound:
            return "Habit not found."
        case .invalidData:
            return "Invalid habit data."
        case .updateFailed:
            return "Failed to update habit."
        }
    }
}

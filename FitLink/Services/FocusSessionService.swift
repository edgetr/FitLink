import Foundation
import FirebaseFirestore

enum FocusSessionServiceError: LocalizedError {
    case sessionNotFound
    case invalidData
    case saveFailed(underlying: Error)
    case loadFailed(underlying: Error)
    case deleteFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "Focus session not found."
        case .invalidData:
            return "Invalid session data."
        case .saveFailed(let error):
            return "Failed to save session: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load sessions: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete session: \(error.localizedDescription)"
        }
    }
}

actor FocusSessionService {

    static let shared = FocusSessionService()

    private let db = Firestore.firestore()
    private let collectionName = "focus_sessions"

    private init() {}

    func saveSession(_ session: FocusSession, userId: String) async throws {
        AppLogger.shared.info("Saving focus session: \(session.id) for user: \(userId)", category: .habit)

        do {
            let docRef = db.collection("users")
                .document(userId)
                .collection(collectionName)
                .document(session.id)

            let data = session.toDictionary()
            try await docRef.setData(data)

            AppLogger.shared.info("Successfully saved focus session: \(session.id)", category: .habit)
        } catch {
            AppLogger.shared.error("Failed to save focus session: \(session.id), error: \(error)", category: .habit)
            throw FocusSessionServiceError.saveFailed(underlying: error)
        }
    }

    func loadSessions(userId: String, limit: Int? = nil) async throws -> [FocusSession] {
        AppLogger.shared.info("Loading focus sessions for user: \(userId)", category: .habit)

        do {
            var query = db.collection("users")
                .document(userId)
                .collection(collectionName)
                .order(by: "started_at", descending: true)

            if let limit = limit {
                query = query.limit(to: limit)
            }

            let snapshot = try await query.getDocuments()

            let sessions = snapshot.documents.compactMap { doc in
                FocusSession.fromDictionary(doc.data(), id: doc.documentID)
            }

            AppLogger.shared.info("Loaded \(sessions.count) focus sessions for user: \(userId)", category: .habit)
            return sessions
        } catch {
            AppLogger.shared.error("Failed to load focus sessions for user: \(userId), error: \(error)", category: .habit)
            throw FocusSessionServiceError.loadFailed(underlying: error)
        }
    }

    func loadRecentSessions(userId: String, days: Int) async throws -> [FocusSession] {
        AppLogger.shared.info("Loading focus sessions from last \(days) days for user: \(userId)", category: .habit)

        do {
            let calendar = Calendar.current
            guard let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
                AppLogger.shared.warning("Failed to calculate start date for recent sessions", category: .habit)
                return []
            }

            let snapshot = try await db.collection("users")
                .document(userId)
                .collection(collectionName)
                .whereField("started_at", isGreaterThanOrEqualTo: Timestamp(date: startDate))
                .order(by: "started_at", descending: true)
                .getDocuments()

            let sessions = snapshot.documents.compactMap { doc in
                FocusSession.fromDictionary(doc.data(), id: doc.documentID)
            }

            AppLogger.shared.info("Loaded \(sessions.count) recent focus sessions for user: \(userId)", category: .habit)
            return sessions
        } catch {
            AppLogger.shared.error("Failed to load recent focus sessions for user: \(userId), error: \(error)", category: .habit)
            throw FocusSessionServiceError.loadFailed(underlying: error)
        }
    }

    func deleteSession(sessionId: String, userId: String) async throws {
        AppLogger.shared.info("Deleting focus session: \(sessionId) for user: \(userId)", category: .habit)

        do {
            try await db.collection("users")
                .document(userId)
                .collection(collectionName)
                .document(sessionId)
                .delete()

            AppLogger.shared.info("Successfully deleted focus session: \(sessionId)", category: .habit)
        } catch {
            AppLogger.shared.error("Failed to delete focus session: \(sessionId), error: \(error)", category: .habit)
            throw FocusSessionServiceError.deleteFailed(underlying: error)
        }
    }

    func observeSessions(userId: String) -> AsyncStream<[FocusSession]> {
        AsyncStream { [weak self] continuation in
            Task { [weak self] in
                guard let self = self else {
                    continuation.finish()
                    return
                }

                let listener = await self.db.collection("users")
                    .document(userId)
                    .collection(self.collectionName)
                    .order(by: "started_at", descending: true)
                    .addSnapshotListener { snapshot, error in
                        if let error = error {
                            AppLogger.shared.error("Focus session listener error: \(error)", category: .habit)
                            continuation.finish()
                            return
                        }

                        guard let documents = snapshot?.documents else {
                            continuation.finish()
                            return
                        }

                        let sessions = documents.compactMap { doc in
                            FocusSession.fromDictionary(doc.data(), id: doc.documentID)
                        }

                        continuation.yield(sessions)
                    }

                continuation.onTermination = { @Sendable _ in
                    listener.remove()
                }
            }
        }
    }

    func deleteAllSessions(userId: String) async throws {
        AppLogger.shared.info("Deleting all focus sessions for user: \(userId)", category: .habit)

        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection(collectionName)
                .getDocuments()

            let batch = db.batch()
            for doc in snapshot.documents {
                batch.deleteDocument(doc.reference)
            }

            try await batch.commit()

            AppLogger.shared.info("Successfully deleted all focus sessions for user: \(userId)", category: .habit)
        } catch {
            AppLogger.shared.error("Failed to delete all focus sessions for user: \(userId), error: \(error)", category: .habit)
            throw FocusSessionServiceError.deleteFailed(underlying: error)
        }
    }
}

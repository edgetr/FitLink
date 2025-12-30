import Foundation
import FirebaseFirestore

enum HabitStoreError: LocalizedError {
    case documentsDirectoryUnavailable
    case encodingFailed(underlying: Error)
    case decodingFailed(underlying: Error)
    case writeFailed(underlying: Error)
    case readFailed(underlying: Error)
    case migrationFailed(underlying: Error)
    case firestoreError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .documentsDirectoryUnavailable:
            return "Unable to access documents directory"
        case .encodingFailed(let error):
            return "Failed to encode habits: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode habits: \(error.localizedDescription)"
        case .writeFailed(let error):
            return "Failed to save habits: \(error.localizedDescription)"
        case .readFailed(let error):
            return "Failed to load habits: \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "Failed to migrate habits: \(error.localizedDescription)"
        case .firestoreError(let error):
            return "Firestore error: \(error.localizedDescription)"
        }
    }
}

actor HabitStore {

    static let shared = HabitStore()

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager
    private let userDefaults = UserDefaults.standard
    private var habitListenerTask: Task<Void, Never>?
    private var currentUserId: String?

    private let migrationStatusPrefix = "habits_migrated_"

    private init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        self.fileManager = .default
    }

    deinit {
        habitListenerTask?.cancel()
    }

    // MARK: - Public API (JSON - Backward Compatibility)

    func loadHabits(userId: String?) async throws -> [Habit] {
        let url = try habitsFileURL(userId: userId)

        guard fileManager.fileExists(atPath: url.path) else {
            AppLogger.shared.debug("No habits file found at \(url.lastPathComponent), returning empty array", category: .habit)
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let habits = try decoder.decode([Habit].self, from: data)
            AppLogger.shared.info("Loaded \(habits.count) habits from \(url.lastPathComponent)", category: .habit)
            return habits
        } catch let error as DecodingError {
            throw HabitStoreError.decodingFailed(underlying: error)
        } catch {
            throw HabitStoreError.readFailed(underlying: error)
        }
    }

    func saveHabits(_ habits: [Habit], userId: String?) async throws {
        let url = try habitsFileURL(userId: userId)

        do {
            let data = try encoder.encode(habits)
            try data.write(to: url, options: .atomic)
            AppLogger.shared.info("Saved \(habits.count) habits to \(url.lastPathComponent)", category: .habit)
        } catch let error as EncodingError {
            throw HabitStoreError.encodingFailed(underlying: error)
        } catch {
            throw HabitStoreError.writeFailed(underlying: error)
        }
    }

    func deleteHabitsFile(userId: String?) async throws {
        let url = try habitsFileURL(userId: userId)

        guard fileManager.fileExists(atPath: url.path) else {
            AppLogger.shared.debug("No habits file to delete at \(url.lastPathComponent)", category: .habit)
            return
        }

        do {
            try fileManager.removeItem(at: url)
            AppLogger.shared.info("Deleted habits file at \(url.lastPathComponent)", category: .habit)
        } catch {
            throw HabitStoreError.writeFailed(underlying: error)
        }
    }

    func habitsFileExists(userId: String?) -> Bool {
        guard let url = try? habitsFileURL(userId: userId) else {
            return false
        }
        return fileManager.fileExists(atPath: url.path)
    }

    // MARK: - Firestore-Backed Operations

    func loadHabitsFromFirestore(userId: String) async throws -> [Habit] {
        await logInfo("Loading habits from Firestore for user: \(userId)")
        return try await HabitFirestoreService.shared.loadHabits(userId: userId)
    }

    func saveHabitsToFirestore(_ habits: [Habit], userId: String) async throws {
        await logInfo("Saving \(habits.count) habits to Firestore for user: \(userId)")
        try await HabitFirestoreService.shared.saveHabits(habits, userId: userId)
    }

    // MARK: - Dual-Write Operations

    func saveHabitsDualWrite(_ habits: [Habit], userId: String?) async throws {
        await logInfo("Dual-writing \(habits.count) habits for user: \(userId ?? "nil")")

        if let userId = userId, !userId.isEmpty {
            let migrated = hasMigrated(userId: userId)

            if migrated {
                try await saveHabitsToFirestore(habits, userId: userId)
            } else {
                try await saveHabits(habits, userId: userId)
            }
        } else {
            try await saveHabits(habits, userId: nil)
        }
    }

    // MARK: - Migration

    func migrateLocalHabitsToFirestore(userId: String) async throws -> Bool {
        await logInfo("Starting habit migration for user: \(userId)")

        if hasMigrated(userId: userId) {
            await logInfo("User \(userId) already migrated, skipping")
            return true
        }

        let localHabits: [Habit]
        do {
            localHabits = try await loadHabits(userId: userId)
        } catch {
            AppLogger.shared.error("Failed to load local habits for migration: \(error)", category: .habit)
            throw HabitStoreError.migrationFailed(underlying: error)
        }

        guard !localHabits.isEmpty else {
            await logInfo("No local habits to migrate for user: \(userId), marking as migrated")
            markMigrated(userId: userId)
            return true
        }

        do {
            try await saveHabitsToFirestore(localHabits, userId: userId)
            markMigrated(userId: userId)
            await logInfo("Successfully migrated \(localHabits.count) habits for user: \(userId)")
            return true
        } catch {
            AppLogger.shared.error("Failed to migrate habits to Firestore: \(error)", category: .habit)
            throw HabitStoreError.migrationFailed(underlying: error)
        }
    }

    func hasMigrated(userId: String) -> Bool {
        let key = migrationStatusPrefix + userId
        return userDefaults.bool(forKey: key)
    }

    func markMigrated(userId: String) {
        let key = migrationStatusPrefix + userId
        userDefaults.set(true, forKey: key)
    }

    func clearMigrationStatus(userId: String) {
        let key = migrationStatusPrefix + userId
        userDefaults.removeObject(forKey: key)
    }

    // MARK: - Observation for Real-Time Sync

    func startObserving(userId: String) async {
        await logInfo("Starting habit observation for user: \(userId)")

        stopObserving()

        currentUserId = userId

        let stream = await HabitFirestoreService.shared.observeHabits(userId: userId)

        habitListenerTask = Task { [weak self] in
            guard self != nil else { return }

            do {
                for try await habits in stream {
                    AppLogger.shared.debug("Received \(habits.count) habits from Firestore observation", category: .habit)
                }
            } catch {
                AppLogger.shared.error("Habit stream error: \(error)", category: .habit)
            }
        }
    }

    func stopObserving() {
        if habitListenerTask != nil {
            habitListenerTask?.cancel()
            habitListenerTask = nil
            currentUserId = nil
        }
    }

    // MARK: - Private Helpers

    private func habitsFileURL(userId: String?) throws -> URL {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw HabitStoreError.documentsDirectoryUnavailable
        }

        let filename: String
        if let userId = userId, !userId.isEmpty {
            filename = "habits_\(userId).json"
        } else {
            filename = "habits.json"
        }

        return documentsDirectory.appendingPathComponent(filename)
    }

    private func logInfo(_ message: String) async {
        await MainActor.run {
            AppLogger.shared.info(message, category: .habit)
        }
    }
}

import Foundation

// MARK: - HabitStoreError

enum HabitStoreError: LocalizedError {
    case documentsDirectoryUnavailable
    case encodingFailed(underlying: Error)
    case decodingFailed(underlying: Error)
    case writeFailed(underlying: Error)
    case readFailed(underlying: Error)
    
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
        }
    }
}

// MARK: - HabitStore

actor HabitStore {
    
    static let shared = HabitStore()
    
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager
    
    private init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        
        self.fileManager = .default
    }
    
    // MARK: - Public API
    
    func loadHabits(userId: String?) async throws -> [Habit] {
        let url = try habitsFileURL(userId: userId)
        
        guard fileManager.fileExists(atPath: url.path) else {
            log("No habits file found at \(url.lastPathComponent), returning empty array")
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let habits = try decoder.decode([Habit].self, from: data)
            log("Loaded \(habits.count) habits from \(url.lastPathComponent)")
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
            log("Saved \(habits.count) habits to \(url.lastPathComponent)")
        } catch let error as EncodingError {
            throw HabitStoreError.encodingFailed(underlying: error)
        } catch {
            throw HabitStoreError.writeFailed(underlying: error)
        }
    }
    
    func deleteHabitsFile(userId: String?) async throws {
        let url = try habitsFileURL(userId: userId)
        
        guard fileManager.fileExists(atPath: url.path) else {
            log("No habits file to delete at \(url.lastPathComponent)")
            return
        }
        
        do {
            try fileManager.removeItem(at: url)
            log("Deleted habits file at \(url.lastPathComponent)")
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
    
    private func log(_ message: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [HabitStore] \(message)")
        #endif
    }
}

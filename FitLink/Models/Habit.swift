import Foundation

struct Habit: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var createdAt: Date
    var endDate: Date?
    var completionDates: [Date]
    
    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), endDate: Date? = nil, completionDates: [Date] = []) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.endDate = endDate
        self.completionDates = completionDates
    }
    
    static func normalizeDate(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}

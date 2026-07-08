import Foundation

/// Lightweight scan history for showing "cleaned X GB this week" type stats.
struct ScanHistoryRecord: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let freedSize: Int64
    let freedFileCount: Int
}

enum ScanHistory {
    private static let key = "com.trashcat.scanHistory"
    private static let maxRecords = 50

    /// Append a new clean record
    static func record(freedSize: Int64, fileCount: Int) {
        var records = load()
        records.append(ScanHistoryRecord(date: Date(), freedSize: freedSize, freedFileCount: fileCount))
        if records.count > maxRecords { records.removeFirst(records.count - maxRecords) }
        save(records)
    }

    /// All recorded clean sessions, newest first
    static func all() -> [ScanHistoryRecord] {
        load().reversed()
    }

    /// Total freed in a date interval, e.g. "this month"
    static func totalFreed(from: Date, to: Date = Date()) -> Int64 {
        load().filter { $0.date >= from && $0.date <= to }.reduce(0) { $0 + $1.freedSize }
    }

    /// Total freed this month
    static func thisMonth() -> Int64 {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        return totalFreed(from: start)
    }

    /// Total freed this week
    static func thisWeek() -> Int64 {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        return totalFreed(from: start)
    }

    /// Total freed ever
    static func allTime() -> Int64 {
        load().reduce(0) { $0 + $1.freedSize }
    }

    /// Total clean sessions
    static func totalSessions() -> Int {
        load().count
    }

    // MARK: - Persistence

    private static func load() -> [ScanHistoryRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let records = try? JSONDecoder().decode([ScanHistoryRecord].self, from: data) else {
            return []
        }
        return records
    }

    private static func save(_ records: [ScanHistoryRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

import Foundation

public struct WeekDay: Hashable, Sendable {
    public let letter: String
    public let date: Date
    public let hasEntry: Bool
    public let isToday: Bool
}

public struct StreakInfo: Equatable, Sendable {
    public let count: Int
    public let week: [WeekDay]
    public var unit: String { count == 1 ? "day in a row" : "days in a row" }
}

public enum Streak {
    /// Consecutive days with an entry, counting back from today (or yesterday if today is empty),
    /// plus the Monday-start week containing today.
    public static func compute(entryDates: [Date], today: Date, calendar: Calendar = .current) -> StreakInfo {
        let days = Set(entryDates.map { calendar.startOfDay(for: $0) })
        let start = calendar.startOfDay(for: today)
        var cursor = days.contains(start) ? start : calendar.date(byAdding: .day, value: -1, to: start)!
        var count = 0
        while days.contains(cursor) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        let weekday = calendar.component(.weekday, from: start) // 1 = Sunday
        let monday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: start)!
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        let week = letters.enumerated().map { i, letter in
            let d = calendar.date(byAdding: .day, value: i, to: monday)!
            return WeekDay(letter: letter, date: d, hasEntry: days.contains(d), isToday: d == start)
        }
        return StreakInfo(count: count, week: week)
    }
}

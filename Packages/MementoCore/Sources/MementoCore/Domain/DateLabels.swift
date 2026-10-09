import Foundation

/// English date strings used across the app (formats from the prototype).
public struct DateLabels: Sendable {
    public var now: Date
    public var calendar: Calendar

    public init(now: Date = .now, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }

    private func format(_ date: Date, _ pattern: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = pattern
        return f.string(from: date)
    }

    /// "Today", "Yesterday", "Wed, Oct 7"
    public func relativeDay(_ date: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let y = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: y) { return "Yesterday" }
        return format(date, "EEE, MMM d")
    }

    /// "Oct 7"
    public func short(_ date: Date) -> String { format(date, "MMM d") }
    /// "9:41 PM"
    public func time(_ date: Date) -> String { format(date, "h:mm a") }
    /// "Friday, October 9"
    public func longDay(_ date: Date) -> String { format(date, "EEEE, MMMM d") }
    /// "October 9, 2026"
    public func fullDate(_ date: Date) -> String { format(date, "MMMM d, yyyy") }
    /// "September"
    public func month(_ date: Date) -> String { format(date, "MMMM") }

    public func greeting() -> String {
        switch calendar.component(.hour, from: now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }
}

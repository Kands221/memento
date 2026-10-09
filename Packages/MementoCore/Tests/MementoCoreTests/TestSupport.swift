import Foundation
import SwiftData
@testable import MementoCore

enum Fixtures {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }()
    /// Friday, October 9, 2026, 9:41 PM: the prototype's "today".
    static let today: Date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 21, minute: 41))!
    static func daysAgo(_ n: Int, hour: Int = 20, minute: Int = 0) -> Date {
        let day = calendar.date(byAdding: .day, value: -n, to: today)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }
}

typealias TagSpec = (label: String, kind: TagKind, quote: String?, status: TagStatus)

@MainActor
struct TestStore {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws { container = try MementoStore.container(inMemory: true) }

    @discardableResult
    func entry(daysAgo: Int = 0, notebook: String = "daily", mode: WritingMode = .free,
               text: String = "Some words.", tags: [TagSpec] = []) -> Entry {
        let e = Entry(createdAt: Fixtures.daysAgo(daysAgo), notebookID: notebook, mode: mode, text: text, tagging: .done)
        context.insert(e)
        for t in tags { e.addTag(label: t.label, kind: t.kind, quote: t.quote, status: t.status) }
        return e
    }

    func all() throws -> [Entry] {
        try context.fetch(FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
    }
}

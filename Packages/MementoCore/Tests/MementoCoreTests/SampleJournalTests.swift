import Testing
import SwiftData
@testable import MementoCore

@MainActor
@Suite struct SampleJournalTests {
    @Test func loadsEightEntriesOnceWithPrototypeShape() throws {
        let s = try TestStore()
        #expect(try SampleJournal.load(into: s.context, today: Fixtures.today, calendar: Fixtures.calendar) == 8)
        #expect(try SampleJournal.load(into: s.context, today: Fixtures.today, calendar: Fixtures.calendar) == 0)
        let entries = try s.all()
        let index = TagIndex(entries: entries)
        #expect(entries.count == 8)
        #expect(index.count(for: "Walking helped") == 3)
        #expect(index.count(for: "Work deadlines") == 2)
        #expect(JournalInsights.pending(entries).label == "2 suggestions waiting in 2 entries")
        #expect(Streak.compute(entryDates: entries.map(\.createdAt), today: Fixtures.today, calendar: Fixtures.calendar).count == 3)
        #expect(entries.first(where: { $0.mode == .guided })?.prompt == "What are three small things you're grateful for today?")
        #expect(entries.allSatisfy { $0.tagging == .done })
    }

    @Test func clearRemovesEverything() throws {
        let s = try TestStore()
        _ = try SampleJournal.load(into: s.context, today: Fixtures.today, calendar: Fixtures.calendar)
        s.entry(text: "Mine.")
        try SampleJournal.clear(from: s.context)
        #expect(try s.all().isEmpty)
    }
}

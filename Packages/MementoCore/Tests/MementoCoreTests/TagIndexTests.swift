import Testing
@testable import MementoCore

@MainActor
@Suite struct TagIndexTests {
    @Test func countsOnlyKeptTagsOncePerEntry() throws {
        let s = try TestStore()
        s.entry(daysAgo: 1, tags: [("Walking helped", .helped, nil, .kept), ("Calm", .feeling, nil, .suggested)])
        s.entry(daysAgo: 2, tags: [("Walking helped", .helped, nil, .kept), ("Walking helped", .helped, nil, .kept)])
        s.entry(daysAgo: 3, tags: [("Walking helped", .helped, nil, .removed)])
        let index = TagIndex(entries: try s.all())
        #expect(index.count(for: "Walking helped") == 2)
        #expect(index.count(for: "Calm") == 0)
        #expect(index.summaries.map(\.label) == ["Walking helped"])
    }

    @Test func labelsMergeCaseInsensitively() throws {
        let s = try TestStore()
        s.entry(daysAgo: 1, tags: [("walking helped", .helped, nil, .kept)])
        s.entry(daysAgo: 2, tags: [("Walking helped", .helped, nil, .kept)])
        let index = TagIndex(entries: try s.all())
        #expect(index.summaries.count == 1)
        #expect(index.summary(for: "WALKING HELPED")?.count == 2)
        #expect(index.summary(for: "walking helped")?.label == "walking helped") // newest wins display
    }

    @Test func byKindSortsByCountThenFirstSeenAndFilters() throws {
        let s = try TestStore()
        s.entry(daysAgo: 1, tags: [("Calm", .feeling, nil, .kept), ("Drained", .feeling, nil, .kept)])
        s.entry(daysAgo: 2, tags: [("Drained", .feeling, nil, .kept)])
        let index = TagIndex(entries: try s.all())
        #expect(index.byKind(.feeling).map(\.label) == ["Drained", "Calm"])
        #expect(index.byKind(.feeling, matching: "cal").map(\.label) == ["Calm"])
        #expect(index.topLabels(1) == ["Drained"])
    }

    @Test func pendingAndRevisit() throws {
        let s = try TestStore()
        s.entry(daysAgo: 1, tags: [("Restless", .feeling, nil, .suggested), ("Walking helped", .helped, nil, .kept)])
        s.entry(daysAgo: 2, tags: [("Boundaries", .situation, nil, .suggested), ("Walking helped", .helped, nil, .kept)])
        let entries = try s.all()
        let pending = JournalInsights.pending(entries)
        #expect(pending.label == "2 suggestions waiting in 2 entries")
        #expect(pending.firstEntryID == entries[0].id)
        #expect(JournalInsights.revisit(TagIndex(entries: entries))?.label == "Walking helped")
    }

    @Test func revisitNeedsTwoEntries() throws {
        let s = try TestStore()
        s.entry(tags: [("Reading", .helped, nil, .kept)])
        #expect(JournalInsights.revisit(TagIndex(entries: try s.all())) == nil)
        #expect(JournalInsights.pending([]).label == "0 suggestions waiting in 0 entries")
    }
}

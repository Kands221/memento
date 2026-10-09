import Testing
@testable import MementoCore

@MainActor
@Suite struct SummaryComposerTests {
    /// Held by the suite so the container (and its models) outlive each test body.
    let s: TestStore

    init() throws { s = try TestStore() }

    func sample() throws -> [Entry] {
        s.entry(daysAgo: 1, text: "Couldn't sleep.", tags: [("Poor sleep", .situation, "Couldn't sleep", .kept), ("Restless", .feeling, nil, .suggested)])
        s.entry(daysAgo: 3, text: "Overwhelmed is the word. Took the long way home.", tags: [
            ("Overwhelmed", .feeling, "Overwhelmed is the word", .kept), ("Walking helped", .helped, "Took the long way home", .kept)])
        s.entry(daysAgo: 10, text: "My first bowl.", tags: [("Absorbed", .feeling, nil, .kept)])
        return try s.all()
    }

    @Test func listJoinsWithOxfordlessAnd() {
        #expect(SummaryComposer.list([]) == "")
        #expect(SummaryComposer.list(["a"]) == "a")
        #expect(SummaryComposer.list(["a", "b", "c"]) == "a, b and c")
    }

    @Test func forMeNarrativeAndGroups() throws {
        let doc = SummaryComposer.compose(entries: try sample(),
            options: SummaryOptions(purpose: .me, today: Fixtures.today), calendar: Fixtures.calendar)
        #expect(doc.title == "A look back")
        #expect(doc.who == "For me · October 9, 2026")
        #expect(doc.range == "Sep 29 – Oct 8, 2026")
        #expect(doc.countLine == "3 selected entries")
        #expect(doc.narrative == "Across 3 entries, the feelings you named most were absorbed (1) and overwhelmed (1). You wrote about poor sleep (1). Things you noted helped: walking helped (1).")
        #expect(doc.groups.map(\.name) == ["Feelings", "Situations", "What helped"])
        #expect(doc.groups[0].items == "Absorbed (1), Overwhelmed (1)")
        #expect(doc.quotes.map(\.text) == ["My first bowl.", "Overwhelmed is the word", "Couldn't sleep"])
        #expect(doc.note == nil)
    }

    @Test func clinicianVersionIsFirstPersonWithNoteAndName() throws {
        let doc = SummaryComposer.compose(entries: try sample(),
            options: SummaryOptions(purpose: .clinician, includeQuotes: false, note: "Sleep is worse.", preparedBy: "Maya Lin", today: Fixtures.today),
            calendar: Fixtures.calendar)
        #expect(doc.title == "Journal summary for my appointment")
        #expect(doc.who == "Prepared by Maya Lin · October 9, 2026")
        #expect(doc.narrative.hasPrefix("Across 3 entries I chose, the feelings I named most often were absorbed (1) and overwhelmed (1)."))
        #expect(doc.narrative.hasSuffix("Numbers are how many selected entries carry each tag."))
        #expect(doc.showQuotes == false)
        #expect(doc.note == "Sleep is worse.")
    }

    @Test func emptySelectionAndUntaggedFeelings() {
        let doc = SummaryComposer.compose(entries: [], options: SummaryOptions(purpose: .me, today: Fixtures.today), calendar: Fixtures.calendar)
        #expect(doc.range == "")
        #expect(doc.countLine == "0 selected entries")
        #expect(doc.narrative == "Across 0 entries, the feelings you named most were not tagged yet.")
    }
}

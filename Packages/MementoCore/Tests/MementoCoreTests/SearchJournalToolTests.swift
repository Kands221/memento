import Testing
import Foundation
@testable import MementoCore

@Suite struct SearchJournalToolTests {
    func hit(_ text: String, daysAgo: Int, tags: [String] = []) -> JournalHit {
        JournalHit(snippet: JournalSnippet(entryID: UUID(), date: Fixtures.daysAgo(daysAgo), notebook: "Daily", text: text, tags: tags), score: 0.8)
    }

    @Test func describesHitsWithDatesWordsAndTags() {
        let out = SearchJournalTool.describe([hit("Took the long way home through the park", daysAgo: 3, tags: ["Walking helped"])],
                                             calendar: Fixtures.calendar)
        #expect(out.contains("On Oct 6 the writer wrote: “Took the long way home through the park”"))
        #expect(out.contains("Walking helped"))
        #expect(SearchJournalTool.describe([], calendar: Fixtures.calendar).contains("No related entries"))
    }

    @Test func citesOnlyMomentsTheReplyActuallyUsed() {
        let used = hit("Took the long way home through the park", daysAgo: 3)
        let unused = hit("Made tea at midnight, which didn't help", daysAgo: 1)
        let reply = "On Oct 6 you took the long way home through the park, and it helped. Could a walk help tonight?"
        let cites = SolTurnPlanner.citations(for: reply, hits: [used, unused], calendar: Fixtures.calendar)
        #expect(cites.map(\.entryID) == [used.snippet.entryID])
        #expect(cites.first?.label == "Oct 6")
        #expect(SolTurnPlanner.citations(for: "What's on your heart?", hits: [used], calendar: Fixtures.calendar).isEmpty)
    }

    @Test func toolSearchesTheIndexAndRecordsHits() async throws {
        let index = JournalIndex(embedder: WordEmbedder())
        await index.rebuild(from: [JournalDocument(entryID: UUID(), date: Fixtures.daysAgo(3), notebook: "Work",
                                                   text: "Took the long way home through the park.", keptTags: ["Walking helped"])])
        let recorder = CitationRecorder()
        let tool = SearchJournalTool(index: index, recorder: recorder, calendar: Fixtures.calendar)
        let out = try await tool.call(arguments: .init(query: "a walk in the park"))
        #expect(out.contains("Took the long way home through the park"))
        #expect(await recorder.takeHits().count == 1)
        #expect(await recorder.takeHits().isEmpty)
    }
}

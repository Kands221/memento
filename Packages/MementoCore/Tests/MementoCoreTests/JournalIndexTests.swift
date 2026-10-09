import Testing
import Foundation
@testable import MementoCore

/// Deterministic bag-of-words embedder for ranking tests.
struct WordEmbedder: SentenceEmbedder {
    let vocab = ["walk", "park", "outside", "deadline", "work", "sleep", "tea", "friend", "talk"]
    func vector(for text: String) -> [Double]? {
        let t = text.lowercased()
        let v = vocab.map { t.contains($0) ? 1.0 : 0.0 }
        return v.contains(1) ? v : nil
    }
}

@Suite struct JournalIndexTests {
    let today = Fixtures.today

    func docs() -> [JournalDocument] {
        [
            JournalDocument(entryID: UUID(), date: Fixtures.daysAgo(3), notebook: "Work",
                            text: "Deadlines everywhere. Took the long way home through the park and felt like a person again.",
                            keptTags: ["Walking helped", "Work deadlines"], helpedQuotes: ["Took the long way home through the park"]),
            JournalDocument(entryID: UUID(), date: Fixtures.daysAgo(1), notebook: "Daily",
                            text: "Couldn't sleep until two. Made tea at midnight.", keptTags: ["Poor sleep"]),
            JournalDocument(entryID: UUID(), date: Fixtures.daysAgo(27), notebook: "Daily",
                            text: "Long walk with Priya after work. She just listened, a good friend talk.", keptTags: ["Talking to a friend"],
                            helpedQuotes: ["She just listened"]),
        ]
    }

    @Test func ranksBestSentencePerEntryAndLimits() async {
        let index = JournalIndex(embedder: WordEmbedder())
        await index.rebuild(from: docs())
        let hits = await index.search("a walk in the park", limit: 2)
        #expect(hits.count == 2)
        #expect(hits[0].snippet.text == "Took the long way home through the park and felt like a person again.")
        #expect(Set(hits.map(\.snippet.entryID)).count == 2)   // one hit per entry
    }

    @Test func tagMatchesBoostAndEmptyQueriesReturnNothing() async {
        let index = JournalIndex(embedder: WordEmbedder())
        await index.rebuild(from: docs())
        #expect(await index.search("   ").isEmpty)
        let hits = await index.search("poor sleep")
        #expect(hits.first?.snippet.tags == ["Poor sleep"])
    }

    @Test func realOnDeviceEmbeddingsFindRelatedMoments() async {
        let index = JournalIndex()
        await index.rebuild(from: docs())
        let hits = await index.search("being outside in nature helped me feel better")
        #expect(!hits.isEmpty)
        #expect(hits.contains { $0.snippet.tags.contains("Walking helped") || $0.snippet.tags.contains("Talking to a friend") })
    }
}

@Suite struct HybridRetrievalTests {
    func sampleIndex() async throws -> (JournalIndex, [JournalDocument]) {
        let docs = [
            JournalDocument(entryID: UUID(), date: Fixtures.daysAgo(10), notebook: "Daily",
                            text: "My first bowl is lopsided and I love it. Two hours where I didn't check my phone once.", keptTags: ["Making things", "Creativity"]),
            JournalDocument(entryID: UUID(), date: Fixtures.daysAgo(15), notebook: "Work",
                            text: "Third late night this week and I'm completely drained. Walked to the corner shop just to get out of the flat, and it took the edge off.",
                            keptTags: ["Work deadlines", "Walking helped"], helpedQuotes: ["Walked to the corner shop just to get out of the flat"]),
            JournalDocument(entryID: UUID(), date: Fixtures.daysAgo(1), notebook: "Daily",
                            text: "Couldn't sleep until almost two. Made tea at midnight, which didn't help.", keptTags: ["Poor sleep"]),
        ]
        let index = JournalIndex()
        await index.rebuild(from: docs)
        return (index, docs)
    }

    @Test func sharedWordsFindTheMoment() async throws {
        let (index, docs) = try await sampleIndex()
        let hits = await index.search("I made a bowl at my ceramics class")
        #expect(hits.first?.snippet.entryID == docs[0].entryID)
    }

    @Test func helpQuestionsPreferWhatHelped() async throws {
        let (index, docs) = try await sampleIndex()
        let hits = await index.search("Work stress again. What helped me before?")
        #expect(hits.first?.snippet.entryID == docs[1].entryID)
        #expect(hits.first?.snippet.text.contains("Walked") == true)
    }

    @Test func smallTalkFindsNothingStrong() async throws {
        let (index, _) = try await sampleIndex()
        #expect(await index.search("hi", minimumScore: JournalIndex.strongMatch).isEmpty)
    }
}

import Testing
@testable import MementoCore

@Suite struct RuleTaggerTests {
    @Test func demoSentenceMatchesPrototype() {
        let text = "I felt drained after back-to-back deadlines today.\nA short walk helped me settle."
        let tags = RuleTagger.analyze(text)
        #expect(tags == [
            SuggestedTagDraft(label: "Drained", kind: .feeling, quote: "I felt drained"),
            SuggestedTagDraft(label: "Work deadlines", kind: .situation, quote: "back-to-back deadlines"),
            SuggestedTagDraft(label: "Walking helped", kind: .helped, quote: "A short walk helped me settle"),
        ])
    }

    @Test func freeWritingExample() {
        let text = "Stayed late again to get the deck finished and I felt drained by the time I got home. Called my sister on the walk from the station and we laughed about Mum's new phone.\n\nStill hopeful the launch moves."
        let labels = RuleTagger.analyze(text).map(\.label)
        #expect(labels == ["Drained", "Talking to a friend", "Walking helped", "Hopeful"])
    }

    @Test func capsAtFiveAndNeverOverlaps() {
        let text = "So overwhelmed and anxious. Grateful for mum. Couldn't sleep. Argued with Theo. A long walk at work. Took a nap."
        let tags = RuleTagger.analyze(text)
        #expect(tags.count == 5)
        #expect(tags.allSatisfy { $0.quote.map(text.contains) ?? false })
    }

    @Test func ruleEngineThrowsWhenNothingFound() async {
        await #expect(throws: TaggingEngineError.nothingToSuggest) {
            try await RuleTaggingEngine(delay: .zero).suggest(text: "Nothing here.", vocabulary: [])
        }
    }

    @Test func failingOnceEngineFailsFirstCallOnly() async throws {
        let engine = FailingOnceEngine(base: RuleTaggingEngine(delay: .zero))
        await #expect(throws: TaggingEngineError.failed) {
            try await engine.suggest(text: "I felt drained.", vocabulary: [])
        }
        let second = try await engine.suggest(text: "I felt drained.", vocabulary: [])
        #expect(second.first?.label == "Drained")
    }
}

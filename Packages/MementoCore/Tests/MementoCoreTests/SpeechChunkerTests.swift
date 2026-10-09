import Testing
@testable import MementoCore

@Suite struct SpeechChunkerTests {
    @Test func releasesSentencesAsTheyComplete() {
        var c = SpeechChunker()
        #expect(c.newSentences(in: "Hello there. How are", final: false) == ["Hello there."])
        #expect(c.newSentences(in: "Hello there. How are you? I'm", final: false) == ["How are you?"])
        #expect(c.newSentences(in: "Hello there. How are you? I'm glad", final: true) == ["I'm glad"])
        #expect(c.newSentences(in: "Hello there. How are you? I'm glad", final: true).isEmpty)
    }

    @Test func handlesEllipsesAndRestarts() {
        var c = SpeechChunker()
        #expect(c.newSentences(in: "Well… let's see! Okay", final: false) == ["Well…", "let's see!"])
        // A new reply that isn't a continuation starts over.
        #expect(c.newSentences(in: "Different.", final: true) == ["Different."])
    }
}

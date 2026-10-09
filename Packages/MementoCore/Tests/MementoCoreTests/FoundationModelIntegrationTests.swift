import Testing
@testable import MementoCore

/// Runs only where Apple Intelligence is available (e.g. this Mac or a supported iPhone).
@Suite(.enabled(if: AIAvailability.live() == .ready))
struct FoundationModelIntegrationTests {
    @Test func taggerReturnsGroundedSuggestions() async throws {
        let text = "I felt drained after back-to-back deadlines today.\nA short walk helped me settle."
        let drafts = try await FoundationModelTagger().suggest(text: text, vocabulary: ["Walking helped"])
        let clean = SuggestionSanitizer.sanitize(drafts, text: text, existingLabels: [])
        #expect(!clean.isEmpty)
        #expect(clean.allSatisfy { $0.quote.map(text.contains) ?? true })
    }
}

@MainActor
@Suite(.enabled(if: AIAvailability.live() == .ready))
struct FoundationModelSolIntegrationTests {
    @Test func solStreamsAReplyAndReturnsToIdle() async {
        let conversation = SolConversation(engine: FoundationModelSol())
        await conversation.send("Work has been a lot this week and I keep saying yes to things.")
        #expect(conversation.messages.last?.role == .sol)
        #expect(!(conversation.messages.last?.text.isEmpty ?? true))
        #expect(conversation.messages.last?.text != SolConversation.fallbackReply)
        #expect(!conversation.isResponding)
    }

    @Test func draftsAReflectionFromUserWords() async throws {
        let text = try await FoundationModelSol().draftReflection(from: ["Work has been a lot.", "I want to say no more often."])
        #expect(text.hasSuffix(ReflectionTemplate.closingPrompt))
    }
}

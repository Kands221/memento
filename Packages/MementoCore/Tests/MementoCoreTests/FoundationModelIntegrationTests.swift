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

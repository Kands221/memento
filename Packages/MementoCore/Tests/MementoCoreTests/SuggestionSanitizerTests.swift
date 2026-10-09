import Testing
@testable import MementoCore

@Suite struct SuggestionSanitizerTests {
    let text = "Couldn't sleep until two. Writing a list of what's due helped."

    func d(_ label: String, _ quote: String?, _ kind: TagKind = .feeling) -> SuggestedTagDraft {
        SuggestedTagDraft(label: label, kind: kind, quote: quote)
    }

    @Test func keepsExactQuotes() {
        let out = SuggestionSanitizer.sanitize([d("Poor sleep", "Couldn't sleep until two")], text: text, existingLabels: [])
        #expect(out == [d("Poor sleep", "Couldn't sleep until two")])
    }

    @Test func rewritesCasingAndStripsSmartQuotes() {
        let out = SuggestionSanitizer.sanitize([d("Writing it down", "“writing a list of what's due helped”")], text: text, existingLabels: [])
        #expect(out.first?.quote == "Writing a list of what's due helped")
    }

    @Test func dropsTagsWhoseQuoteIsInvented() {
        let out = SuggestionSanitizer.sanitize([d("Tired", "I was exhausted all week")], text: text, existingLabels: [])
        #expect(out.isEmpty)
    }

    @Test func groundsNearMissQuotesToTheClosestSentence() {
        let out = SuggestionSanitizer.sanitize([d("Writing it down", "writing the list of what was due helped")], text: text, existingLabels: [])
        #expect(out.first?.quote == "Writing a list of what's due helped")
    }

    @Test func dropsGenericLabels() {
        let out = SuggestionSanitizer.sanitize([d("Emotion", "Couldn't sleep until two"), d("emotional state", nil)], text: text, existingLabels: [])
        #expect(out.isEmpty)
    }

    @Test func keepsQuotelessTagsOnlyWhenAllowed() {
        let feeling = [d("Calm", nil, .feeling)]
        #expect(SuggestionSanitizer.sanitize(feeling, text: text, existingLabels: []).isEmpty)
        #expect(SuggestionSanitizer.sanitize(feeling, text: text, existingLabels: [], requireQuote: false).count == 1)
        // Topics rarely have quotable words (the prototype's "Creativity" has none).
        #expect(SuggestionSanitizer.sanitize([d("Creativity", "Work", .topic)], text: text, existingLabels: []) == [d("Creativity", nil, .topic)])
    }

    @Test func topicKeepsTagButDropsOverlappingQuote() {
        let out = SuggestionSanitizer.sanitize([d("Poor sleep", "Couldn't sleep until two", .situation), d("Health", "Couldn't sleep until two", .topic)],
                                               text: text, existingLabels: [])
        #expect(out == [d("Poor sleep", "Couldn't sleep until two", .situation), d("Health", nil, .topic)])
    }

    @Test func dropsOverlappingSpans() {
        let out = SuggestionSanitizer.sanitize([d("Poor sleep", "Couldn't sleep"), d("Late night", "sleep until two")], text: text, existingLabels: [])
        #expect(out.map(\.label) == ["Poor sleep"])
    }

    @Test func dedupesAgainstExistingAndWithinList() {
        let out = SuggestionSanitizer.sanitize([d("poor sleep", nil), d("Calm", nil), d("calm", nil)], text: text, existingLabels: ["Poor Sleep"], requireQuote: false)
        #expect(out.map(\.label) == ["Calm"])
    }

    @Test func cleansLabelsAndLimits() {
        let many = (1...8).map { d("Tag \($0).", nil) } + [d("   ", nil)]
        let out = SuggestionSanitizer.sanitize(many, text: text, existingLabels: [], requireQuote: false)
        #expect(out.count == 5)
        #expect(out.first?.label == "Tag 1")
        let long = SuggestionSanitizer.sanitize([d("a very long label that keeps going and going on", nil)], text: text, existingLabels: [], requireQuote: false)
        #expect(long.first!.label.count <= 40)
        #expect(long.first!.label.hasPrefix("A very"))
    }
}

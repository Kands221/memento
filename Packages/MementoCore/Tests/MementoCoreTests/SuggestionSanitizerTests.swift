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

    @Test func dropsInventedQuoteButKeepsTag() {
        let out = SuggestionSanitizer.sanitize([d("Tired", "I was exhausted all week")], text: text, existingLabels: [])
        #expect(out == [d("Tired", nil)])
    }

    @Test func dropsOverlappingSpans() {
        let out = SuggestionSanitizer.sanitize([d("Poor sleep", "Couldn't sleep"), d("Late night", "sleep until two")], text: text, existingLabels: [])
        #expect(out.map(\.label) == ["Poor sleep"])
    }

    @Test func dedupesAgainstExistingAndWithinList() {
        let out = SuggestionSanitizer.sanitize([d("poor sleep", nil), d("Calm", nil), d("calm", nil)], text: text, existingLabels: ["Poor Sleep"])
        #expect(out.map(\.label) == ["Calm"])
    }

    @Test func cleansLabelsAndLimits() {
        let many = (1...8).map { d("Tag \($0).", nil) } + [d("   ", nil)]
        let out = SuggestionSanitizer.sanitize(many, text: text, existingLabels: [])
        #expect(out.count == 5)
        #expect(out.first?.label == "Tag 1")
        let long = SuggestionSanitizer.sanitize([d("a very long label that keeps going and going on", nil)], text: text, existingLabels: [])
        #expect(long.first!.label.count <= 40)
        #expect(long.first!.label.hasPrefix("A very"))
    }
}

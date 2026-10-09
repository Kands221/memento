import Foundation

/// Makes model output safe to store: grounded quotes, specific labels, no overlaps or duplicates, at most five.
public enum SuggestionSanitizer {
    public static let maxLabelLength = 40

    /// Labels too vague to help anyone find a moment again.
    static let genericLabels: Set<String> = [
        "emotion", "emotions", "emotional state", "feeling", "feelings", "mood", "situation", "situations",
        "topic", "topics", "journal", "journaling", "journaling activity", "entry", "life", "thoughts", "day", "activity",
    ]

    /// - Parameter requireQuote: model suggestions must point to the writer's words; set false for
    ///   sources that are trusted without a quote.
    ///   Topics are exempt (`quoteOptional`): they name an area of life, often without quotable words.
    public static func sanitize(_ drafts: [SuggestedTagDraft], text: String, existingLabels: Set<String>,
                                limit: Int = 5, requireQuote: Bool = true,
                                quoteOptional: Set<TagKind> = [.topic]) -> [SuggestedTagDraft] {
        var seen = Set(existingLabels.map { $0.lowercased() })
        var taken: [Range<String.Index>] = []
        var out: [SuggestedTagDraft] = []
        for draft in drafts where out.count < limit {
            let label = cleanLabel(draft.label)
            let key = label.lowercased()
            guard !label.isEmpty, !genericLabels.contains(key), !seen.contains(key) else { continue }
            let optional = !requireQuote || quoteOptional.contains(draft.kind)
            var quote: String?
            if let raw = draft.quote, case let q = cleanQuote(raw), !q.isEmpty, let r = locate(q, in: text) {
                if taken.contains(where: { $0.overlaps(r) }) {
                    if !optional { continue }
                } else {
                    taken.append(r)
                    quote = String(text[r])
                }
            }
            if quote == nil && !optional { continue }
            seen.insert(key)
            out.append(SuggestedTagDraft(label: label, kind: draft.kind, quote: quote))
        }
        return out
    }

    static func cleanLabel(_ raw: String) -> String {
        var l = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if l.count > maxLabelLength {
            l = String(l.prefix(maxLabelLength))
            if let space = l.lastIndex(of: " ") { l = String(l[..<space]) }
        }
        return l.prefix(1).uppercased() + l.dropFirst()
    }

    static func cleanQuote(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”‘’")))
    }

    /// Exact match, then case-insensitive, then the sentence sharing at least half of the quote's words.
    static func locate(_ quote: String, in text: String) -> Range<String.Index>? {
        if let r = text.range(of: quote) ?? text.range(of: quote, options: [.caseInsensitive, .diacriticInsensitive]) { return r }
        let wanted = words(quote)
        guard !wanted.isEmpty else { return nil }
        var best: (range: Range<String.Index>, score: Double)?
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .bySentences) { sentence, range, _, _ in
            guard let sentence else { return }
            let score = Double(wanted.intersection(words(sentence)).count) / Double(wanted.count)
            if score >= 0.5, score > (best?.score ?? 0) { best = (range, score) }
        }
        guard let range = best?.range else { return nil }
        return trimmed(range, in: text)
    }

    private static func words(_ s: String) -> Set<String> {
        Set(s.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count >= 3 })
    }

    /// Shrinks a sentence range past surrounding whitespace and trailing sentence punctuation.
    private static func trimmed(_ range: Range<String.Index>, in text: String) -> Range<String.Index>? {
        var lower = range.lowerBound, upper = range.upperBound
        while lower < upper, text[lower].isWhitespace { lower = text.index(after: lower) }
        while upper > lower, let prev = Optional(text.index(before: upper)), text[prev].isWhitespace || ".!?".contains(text[prev]) {
            upper = prev
        }
        return lower < upper ? lower..<upper : nil
    }
}

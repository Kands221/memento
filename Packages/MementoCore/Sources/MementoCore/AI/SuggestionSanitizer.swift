import Foundation

/// Makes model output safe to store: verbatim quotes, no overlaps, no duplicates, at most five.
public enum SuggestionSanitizer {
    public static let maxLabelLength = 40

    public static func sanitize(_ drafts: [SuggestedTagDraft], text: String,
                                existingLabels: Set<String>, limit: Int = 5) -> [SuggestedTagDraft] {
        var seen = Set(existingLabels.map { $0.lowercased() })
        var taken: [Range<String.Index>] = []
        var out: [SuggestedTagDraft] = []
        for draft in drafts where out.count < limit {
            let label = cleanLabel(draft.label)
            guard !label.isEmpty, !seen.contains(label.lowercased()) else { continue }
            var quote: String?
            if let raw = draft.quote {
                let q = cleanQuote(raw)
                if !q.isEmpty, let r = locate(q, in: text) {
                    if taken.contains(where: { $0.overlaps(r) }) { continue }
                    taken.append(r)
                    quote = String(text[r])
                }
            }
            seen.insert(label.lowercased())
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

    static func locate(_ quote: String, in text: String) -> Range<String.Index>? {
        text.range(of: quote) ?? text.range(of: quote, options: [.caseInsensitive, .diacriticInsensitive])
    }
}

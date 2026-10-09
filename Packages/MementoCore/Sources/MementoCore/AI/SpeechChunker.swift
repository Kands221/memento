import Foundation

/// Splits a streaming reply into whole sentences so Sol can speak each one as soon as it's complete.
public struct SpeechChunker: Sendable {
    private var spoken = ""

    public init() {}

    /// Sentences that became complete since the last call. With `final`, the remainder is released too.
    public mutating func newSentences(in text: String, final: Bool) -> [String] {
        if !text.hasPrefix(spoken) { spoken = "" }          // a different reply: start over
        let pending = String(text.dropFirst(spoken.count))
        var sentences: [String] = []
        var consumed = 0
        var current = ""
        for (i, ch) in pending.enumerated() {
            current.append(ch)
            let isEnd = ".!?…".contains(ch)
            let nextIsBreak = i + 1 == pending.count ? final : pending[pending.index(pending.startIndex, offsetBy: i + 1)].isWhitespace
            if isEnd && nextIsBreak {
                let s = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !s.isEmpty { sentences.append(s) }
                consumed = i + 1
                current = ""
            }
        }
        if final {
            let rest = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !rest.isEmpty { sentences.append(rest) }
            consumed = pending.count
        }
        spoken += pending.prefix(consumed)
        return sentences
    }
}

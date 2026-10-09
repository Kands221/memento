import Foundation

public struct TextSegment: Hashable, Sendable {
    public let text: String
    public let mark: QuoteMark?

    public init(text: String, mark: QuoteMark?) {
        self.text = text
        self.mark = mark
    }
}

public enum TextSegments {
    /// Splits text into plain and marked runs. Each mark highlights the first occurrence of its
    /// quote; removed marks, missing quotes and marks overlapping an earlier one are skipped.
    public static func build(text: String, marks: [QuoteMark]) -> [TextSegment] {
        guard !text.isEmpty else { return [] }
        let located = marks.enumerated().compactMap { offset, mark -> (Range<String.Index>, Int, QuoteMark)? in
            guard mark.status != .removed, !mark.quote.isEmpty, let r = text.range(of: mark.quote) else { return nil }
            return (r, offset, mark)
        }
        .sorted { $0.0.lowerBound != $1.0.lowerBound ? $0.0.lowerBound < $1.0.lowerBound : $0.1 < $1.1 }

        var out: [TextSegment] = []
        var cursor = text.startIndex
        for (range, _, mark) in located where range.lowerBound >= cursor {
            if range.lowerBound > cursor { out.append(TextSegment(text: String(text[cursor..<range.lowerBound]), mark: nil)) }
            out.append(TextSegment(text: String(text[range]), mark: mark))
            cursor = range.upperBound
        }
        if cursor < text.endIndex { out.append(TextSegment(text: String(text[cursor...]), mark: nil)) }
        return out
    }
}

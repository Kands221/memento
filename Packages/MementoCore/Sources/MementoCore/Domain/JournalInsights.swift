import Foundation

public struct PendingReview: Equatable, Sendable {
    public let suggestionCount: Int
    public let entryIDs: [UUID]

    public var isEmpty: Bool { suggestionCount == 0 }
    public var firstEntryID: UUID? { entryIDs.first }
    public var label: String {
        let s = suggestionCount == 1 ? "suggestion" : "suggestions"
        let e = entryIDs.count == 1 ? "entry" : "entries"
        return "\(suggestionCount) \(s) waiting in \(entryIDs.count) \(e)"
    }
}

public enum JournalInsights {
    /// Unreviewed suggestions across entries (pass newest first).
    public static func pending(_ entries: [Entry]) -> PendingReview {
        var total = 0
        var ids: [UUID] = []
        for e in entries {
            let n = e.suggestedTags.count
            if n > 0 { total += n; ids.append(e.id) }
        }
        return PendingReview(suggestionCount: total, entryIDs: ids)
    }

    /// The "what helped" tag kept most often, if it appears in at least two entries.
    public static func revisit(_ index: TagIndex) -> TagSummary? {
        guard let top = index.byKind(.helped).first, top.count >= 2 else { return nil }
        return top
    }
}

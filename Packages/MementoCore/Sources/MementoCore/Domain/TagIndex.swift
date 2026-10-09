import Foundation

public struct TagSummary: Identifiable, Hashable, Sendable {
    public var id: String { key }
    /// Lowercased label: the identity of a tag across entries.
    public let key: String
    /// Display label (as written in the newest entry carrying it).
    public let label: String
    public let kind: TagKind
    public internal(set) var entryIDs: [UUID]
    public var count: Int { entryIDs.count }
}

/// Every kept tag across the journal. Pass entries newest first.
public struct TagIndex: Sendable {
    public private(set) var summaries: [TagSummary] = []
    private var positions: [String: Int] = [:]

    public init(entries: [Entry]) {
        for entry in entries {
            for tag in entry.keptTags {
                let key = tag.label.lowercased()
                if let i = positions[key] {
                    if !summaries[i].entryIDs.contains(entry.id) { summaries[i].entryIDs.append(entry.id) }
                } else {
                    positions[key] = summaries.count
                    summaries.append(TagSummary(key: key, label: tag.label, kind: tag.kind, entryIDs: [entry.id]))
                }
            }
        }
    }

    public func summary(for label: String) -> TagSummary? {
        positions[label.lowercased()].map { summaries[$0] }
    }

    public func count(for label: String) -> Int { summary(for: label)?.count ?? 0 }

    /// Tags of one kind, most-used first (ties keep first-seen order), optionally filtered.
    public func byKind(_ kind: TagKind, matching query: String = "") -> [TagSummary] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return Self.byCount(summaries.filter { $0.kind == kind && (q.isEmpty || $0.key.contains(q)) })
    }

    public func topLabels(_ n: Int) -> [String] {
        Array(Self.byCount(summaries).prefix(n).map(\.label))
    }

    static func byCount(_ items: [TagSummary]) -> [TagSummary] {
        items.enumerated()
            .sorted { $0.element.count != $1.element.count ? $0.element.count > $1.element.count : $0.offset < $1.offset }
            .map(\.element)
    }
}

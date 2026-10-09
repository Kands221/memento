import Foundation
import FoundationModels

/// A past moment Sol mentioned, shown as a tappable "from your journal" chip.
public struct SolCitation: Hashable, Sendable {
    public let entryID: UUID
    public let label: String
}

/// Collects what `searchJournal` returned during a turn, so the UI can cite it.
public actor CitationRecorder {
    private var hits: [JournalHit] = []
    public init() {}
    func record(_ new: [JournalHit]) { hits.append(contentsOf: new) }
    /// Returns and clears the hits recorded since the last call.
    public func takeHits() -> [JournalHit] {
        defer { hits = [] }
        return hits
    }
}

/// Lets Sol look through the writer's own journal when remembering would help ("Sol remembers").
/// Everything stays on device: the index is local and results go only into Sol's on-device session.
public struct SearchJournalTool: Tool {
    public let name = "searchJournal"
    public let description = """
    Search the writer's own past journal entries for moments related to a topic, feeling or situation. \
    Use it when remembering what they wrote before (for example, what helped last time) would genuinely help.
    """

    @Generable
    public struct Arguments {
        @Guide(description: "What to look for, in a few words, e.g. \"what helped with work stress\"")
        public var query: String

        public init(query: String) { self.query = query }
    }

    let index: JournalIndex
    let recorder: CitationRecorder
    let calendar: Calendar

    public init(index: JournalIndex, recorder: CitationRecorder, calendar: Calendar = .current) {
        self.index = index
        self.recorder = recorder
        self.calendar = calendar
    }

    public func call(arguments: Arguments) async throws -> String {
        let hits = await index.search(arguments.query, limit: 3)
        await recorder.record(hits)
        return Self.describe(hits, calendar: calendar)
    }

    static func describe(_ hits: [JournalHit], calendar: Calendar) -> String {
        guard !hits.isEmpty else { return "No related entries found. Don't mention the writer's past entries." }
        let labels = DateLabels(calendar: calendar)
        return hits.map { hit in
            let tags = hit.snippet.tags.isEmpty ? "" : " (their tags: \(hit.snippet.tags.joined(separator: ", ")))"
            return "On \(labels.short(hit.snippet.date)) the writer wrote: “\(hit.snippet.text)”\(tags)"
        }.joined(separator: "\n")
    }
}

extension SolTurnPlanner {
    /// Cites a past moment only when the reply clearly used it: by its date, or by sharing several of its words.
    public static func citations(for reply: String, hits: [JournalHit], calendar: Calendar = .current) -> [SolCitation] {
        let labels = DateLabels(calendar: calendar)
        let replyLower = reply.lowercased()
        let replyWords = Set(replyLower.split { !$0.isLetter }.map(String.init).filter { $0.count > 3 })
        var seen = Set<UUID>()
        return hits.compactMap { hit in
            guard seen.insert(hit.snippet.entryID).inserted else { return nil }
            let date = labels.short(hit.snippet.date)
            let words = Set(hit.snippet.text.lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count > 3 })
            let used = replyLower.contains(date.lowercased()) || replyWords.intersection(words).count >= 3
            return used ? SolCitation(entryID: hit.snippet.entryID, label: date) : nil
        }
    }
}

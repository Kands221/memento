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
    /// "Sol remembers": the one closely related journal moment for this message, skipping small talk
    /// and moments already cited in this conversation. Retrieval runs on device for every engine.
    /// - Parameter allowRepeat: a direct question ("what helped last time?") may bring back a moment already cited.
    public static func recall(_ text: String, history: [SolMessage], journal: JournalIndex?,
                              allowRepeat: Bool = false) async -> (memory: String?, hits: [JournalHit]) {
        guard let journal, !isSmallTalk(text) else { return (nil, []) }
        let alreadyCited = allowRepeat ? [] : Set(history.flatMap(\.citations).map(\.entryID))
        let hits = await journal.search(text, limit: 1, minimumScore: JournalIndex.strongMatch)
            .filter { !alreadyCited.contains($0.snippet.entryID) }
        return (hits.isEmpty ? nil : SearchJournalTool.describe(hits, calendar: .current), hits)
    }

    private static let citationStopwords: Set<String> = ["with", "after", "that", "this", "have", "just", "about", "what", "when",
        "your", "they", "from", "were", "been", "into", "there", "their", "would", "could", "really", "felt", "feel", "like", "some"]

    /// Cites a past moment only when the reply clearly used it: by its date, a name from it,
    /// or at least two of its meaningful words (including its kept tags).
    public static func citations(for reply: String, hits: [JournalHit], calendar: Calendar = .current) -> [SolCitation] {
        let labels = DateLabels(calendar: calendar)
        let replyLower = reply.lowercased()
        let replyWords = contentWords(replyLower)
        var seen = Set<UUID>()
        return hits.compactMap { hit in
            guard seen.insert(hit.snippet.entryID).inserted else { return nil }
            let date = labels.short(hit.snippet.date)
            let momentWords = contentWords((hit.snippet.text + " " + hit.snippet.tags.joined(separator: " ")).lowercased())
            let names = hit.snippet.text.split(separator: " ").dropFirst()
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { $0.count > 2 && $0.first?.isUppercase == true && $0 != "I" }
            let used = replyLower.contains(date.lowercased())
                || names.contains { reply.contains($0) }
                || replyWords.intersection(momentWords).count >= 2
            return used ? SolCitation(entryID: hit.snippet.entryID, label: date) : nil
        }
    }

    private static func contentWords(_ text: String) -> Set<String> {
        Set(text.split { !$0.isLetter }.map(String.init).filter { $0.count > 3 && !citationStopwords.contains($0) })
    }
}

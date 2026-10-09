import Foundation
import NaturalLanguage

/// Turns text into a vector for semantic search. Injectable for tests.
public protocol SentenceEmbedder: Sendable {
    func vector(for text: String) -> [Double]?
}

/// Apple's on-device sentence embedding (NaturalLanguage); no download, no network.
public struct NLSentenceEmbedder: SentenceEmbedder {
    public init() {}
    public func vector(for text: String) -> [Double]? {
        NLEmbedding.sentenceEmbedding(for: .english)?.vector(for: text)
    }
}

/// What the index needs from an entry (value type, built on the main actor from SwiftData).
public struct JournalDocument: Sendable, Hashable {
    public let entryID: UUID
    public let date: Date
    public let notebook: String
    public let text: String
    public let keptTags: [String]
    /// Quotes behind kept "what helped" tags; sentences containing them answer "what helped?".
    public let helpedQuotes: [String]

    public init(entryID: UUID, date: Date, notebook: String, text: String, keptTags: [String], helpedQuotes: [String] = []) {
        self.entryID = entryID
        self.date = date
        self.notebook = notebook
        self.text = text
        self.keptTags = keptTags
        self.helpedQuotes = helpedQuotes
    }
}

/// One sentence from an entry, with the context Sol needs to cite it.
public struct JournalSnippet: Sendable, Hashable {
    public let entryID: UUID
    public let date: Date
    public let notebook: String
    public let text: String
    public let tags: [String]
    /// The entry's "what helped" sentence, when the writer kept one.
    public var helped: String? = nil
}

public struct JournalHit: Sendable, Hashable {
    public let snippet: JournalSnippet
    public let score: Double
}

/// Hybrid semantic search over the writer's own entries, entirely on device ("Sol remembers"):
/// sentence embeddings + shared word lemmas + kept-tag matches, with a lift for "what helped" questions.
public actor JournalIndex {
    /// Hits at or above this are confident enough to bring into Sol's reply.
    public static let strongMatch = 0.6

    struct Item {
        let snippet: JournalSnippet
        let vector: [Double]?
        let lemmas: Set<String>
        let tagWords: Set<String>
        let isHelpedMoment: Bool
    }

    private let embedder: any SentenceEmbedder
    private var items: [Item] = []

    public init(embedder: any SentenceEmbedder = NLSentenceEmbedder()) {
        self.embedder = embedder
    }

    public func rebuild(from documents: [JournalDocument]) {
        var built: [Item] = []
        for doc in documents {
            let tagWords = Self.lemmas(doc.keptTags.joined(separator: " "))
            let helpedSentence = Self.sentences(in: doc.text).first { s in
                doc.helpedQuotes.contains { s.localizedCaseInsensitiveContains($0) || $0.localizedCaseInsensitiveContains(s) }
            }
            for sentence in Self.sentences(in: doc.text) {
                let helped = doc.helpedQuotes.contains { sentence.localizedCaseInsensitiveContains($0) || $0.localizedCaseInsensitiveContains(sentence) }
                built.append(Item(snippet: JournalSnippet(entryID: doc.entryID, date: doc.date, notebook: doc.notebook, text: sentence,
                                                          tags: doc.keptTags, helped: helpedSentence),
                                  vector: embedder.vector(for: sentence), lemmas: Self.lemmas(sentence), tagWords: tagWords, isHelpedMoment: helped))
            }
        }
        items = built
    }

    public var isEmpty: Bool { items.isEmpty }

    /// Best-matching sentence per entry, most relevant first.
    public func search(_ query: String, limit: Int = 3, minimumScore: Double = 0.45) -> [JournalHit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let qv = embedder.vector(for: q)
        let qLemmas = Self.lemmas(q)
        let asksWhatHelped = q.range(of: #"\b(help|helped|helps|helpful|better|eased|calm(ed)? me)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
        var best: [UUID: JournalHit] = [:]
        for item in items {
            var score = 0.6 * (zip(qv, item.vector).map { Self.cosine($0, $1) } ?? 0)
            if !qLemmas.isEmpty { score += 0.9 * Double(qLemmas.intersection(item.lemmas).count) / Double(min(qLemmas.count, 3)) }
            if !qLemmas.isDisjoint(with: item.tagWords) { score += 0.2 }
            if asksWhatHelped && item.isHelpedMoment { score += 0.35 }
            guard score >= minimumScore else { continue }
            if score > (best[item.snippet.entryID]?.score ?? -1) {
                best[item.snippet.entryID] = JournalHit(snippet: item.snippet, score: score)
            }
        }
        return Array(best.values.sorted { $0.score > $1.score }.prefix(limit))
    }

    private static let stopwords: Set<String> = ["the", "and", "but", "for", "with", "that", "this", "was", "are", "were", "have", "had",
        "has", "you", "your", "she", "her", "him", "his", "they", "them", "what", "when", "then", "than", "just", "about", "again",
        "into", "out", "get", "got", "very", "really", "feel", "felt", "today", "tonight", "before", "after", "time"]

    static func lemmas(_ text: String) -> Set<String> {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        var out = Set<String>()
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma, options: [.omitPunctuation, .omitWhitespace]) { tag, range in
            let word = (tag?.rawValue ?? String(text[range])).lowercased()
            if word.count >= 3, !stopwords.contains(word), word.allSatisfy(\.isLetter) { out.insert(word) }
            return true
        }
        return out
    }

    static func sentences(in text: String) -> [String] {
        var out: [String] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .bySentences) { s, _, _, _ in
            if let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), s.count > 3 { out.append(s) }
        }
        return out
    }

    static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in a.indices { dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i] }
        return na == 0 || nb == 0 ? 0 : dot / (na.squareRoot() * nb.squareRoot())
    }
}

private func zip(_ a: [Double]?, _ b: [Double]?) -> ([Double], [Double])? {
    guard let a, let b else { return nil }
    return (a, b)
}

extension JournalDocument {
    /// Snapshot of an entry for indexing (kept tags only; "what helped" quotes mark helpful sentences).
    @MainActor
    public init(_ entry: Entry) {
        self.init(entryID: entry.id, date: entry.createdAt, notebook: entry.notebook.name, text: entry.text,
                  keptTags: entry.keptTags.map(\.label),
                  helpedQuotes: entry.keptTags.filter { $0.kind == .helped }.compactMap(\.quote))
    }
}

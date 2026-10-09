import Foundation

public enum SummaryPurpose: String, Sendable {
    case me, clinician
}

public struct SummaryOptions: Sendable {
    public var purpose: SummaryPurpose
    public var includeQuotes: Bool
    public var note: String
    public var preparedBy: String
    public var today: Date
    /// A look-back paragraph Sol drafted on device (and the writer may have edited). "For me" summaries only.
    public var narrative: String?

    public init(purpose: SummaryPurpose, includeQuotes: Bool = true, note: String = "", preparedBy: String = "", today: Date = .now,
                narrative: String? = nil) {
        self.purpose = purpose
        self.includeQuotes = includeQuotes
        self.note = note
        self.preparedBy = preparedBy
        self.today = today
        self.narrative = narrative
    }
}

public struct SummaryDocument: Equatable, Sendable {
    public struct Group: Equatable, Sendable {
        public let name: String
        public let items: String
    }
    public struct Quote: Equatable, Sendable {
        public let date: String
        public let text: String
    }

    public let title: String
    public let who: String
    public let range: String
    public let countLine: String
    public let narrative: String
    public let groups: [Group]
    public let showQuotes: Bool
    public let quotes: [Quote]
    public let note: String?
    /// Says who wrote the narrative when Sol drafted it.
    public var narrativeCredit: String?
    public var footer: String { Self.footer }

    public static let solCredit = "Sol drafted this paragraph on this iPhone from your kept tags."

    public static let footer = "Made in Memento from entries I selected. Tags are my own reviewed labels and counts of what I wrote — not a diagnosis or assessment."
}

/// Deterministic summary text (spec D14): counts of kept tags plus templated sentences.
public enum SummaryComposer {
    public static func compose(entries: [Entry], options: SummaryOptions, calendar: Calendar = .current) -> SummaryDocument {
        let labels = DateLabels(now: options.today, calendar: calendar)
        let selected = entries.sorted { $0.createdAt < $1.createdAt }
        let clinician = options.purpose == .clinician

        let counts = keptCounts(selected)
        func byKind(_ kind: TagKind) -> [(label: String, n: Int)] { Self.byKind(kind, counts) }
        func top(_ kind: TagKind) -> [String] { byKind(kind).prefix(3).map { "\($0.label.lowercased()) (\($0.n))" } }

        let f = top(.feeling), si = top(.situation), he = top(.helped)
        let n = selected.count
        let narrative: String
        let drafted = clinician ? nil : options.narrative?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let drafted, !drafted.isEmpty {
            narrative = drafted
        } else if clinician {
            narrative = [
                "Across \(n) entries I chose, the feelings I named most often were \(f.isEmpty ? "not tagged" : list(f)).",
                si.isEmpty ? "" : "Situations I wrote about included \(list(si)).",
                he.isEmpty ? "" : "Things I noted as helping: \(list(he)).",
                "Numbers are how many selected entries carry each tag.",
            ].filter { !$0.isEmpty }.joined(separator: " ")
        } else {
            narrative = [
                "Across \(n) entries, the feelings you named most were \(f.isEmpty ? "not tagged yet" : list(f)).",
                si.isEmpty ? "" : "You wrote about \(list(si)).",
                he.isEmpty ? "" : "Things you noted helped: \(list(he)).",
            ].filter { !$0.isEmpty }.joined(separator: " ")
        }

        var range = ""
        if let first = selected.first, let last = selected.last {
            let year = calendar.component(.year, from: last.createdAt)
            range = labels.short(first.createdAt) + (n > 1 ? " – " + labels.short(last.createdAt) : "") + ", \(year)"
        }

        let groups = TagKind.allCases.compactMap { kind -> SummaryDocument.Group? in
            let items = byKind(kind)
            guard !items.isEmpty else { return nil }
            return .init(name: kind.plural, items: items.map { "\($0.label) (\($0.n))" }.joined(separator: ", "))
        }

        let quotes = selected.suffix(6).map { entry in
            SummaryDocument.Quote(date: labels.short(entry.createdAt),
                                  text: entry.keptTags.first(where: { $0.quote != nil })?.quote ?? Excerpt.make(entry.text))
        }

        let name = options.preparedBy.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = options.note.trimmingCharacters(in: .whitespacesAndNewlines)
        var document = SummaryDocument(
            title: clinician ? "Journal summary for my appointment" : "A look back",
            who: clinician
                ? (name.isEmpty ? "Prepared with Memento" : "Prepared by \(name)") + " · " + labels.fullDate(options.today)
                : "For me · " + labels.fullDate(options.today),
            range: range,
            countLine: "\(n) selected \(n == 1 ? "entry" : "entries")",
            narrative: narrative,
            groups: groups,
            showQuotes: options.includeQuotes,
            quotes: Array(quotes),
            note: clinician && !note.isEmpty ? note : nil
        )
        if let drafted, !drafted.isEmpty { document.narrativeCredit = SummaryDocument.solCredit }
        return document
    }

    /// One count per entry per kept label, case-insensitively (matches TagIndex and Discover), in first-seen order.
    /// `selected` must be oldest first.
    static func keptCounts(_ selected: [Entry]) -> [(kind: TagKind, label: String, n: Int)] {
        var counts: [(kind: TagKind, label: String, n: Int)] = []
        for entry in selected {
            var seenInEntry = Set<String>()
            for tag in entry.keptTags where seenInEntry.insert(tag.label.lowercased()).inserted {
                if let i = counts.firstIndex(where: { $0.label.lowercased() == tag.label.lowercased() }) {
                    counts[i].n += 1
                } else {
                    counts.append((tag.kind, tag.label, 1))
                }
            }
        }
        return counts
    }

    /// Most-kept first; ties keep first-seen order.
    static func byKind(_ kind: TagKind, _ counts: [(kind: TagKind, label: String, n: Int)]) -> [(label: String, n: Int)] {
        counts.enumerated()
            .filter { $0.element.kind == kind }
            .sorted { $0.element.n != $1.element.n ? $0.element.n > $1.element.n : $0.offset < $1.offset }
            .map { ($0.element.label, $0.element.n) }
    }

    /// "a", "a and b", "a, b and c" (the prototype's fmtList).
    public static func list(_ items: [String]) -> String {
        guard items.count > 1 else { return items.joined() }
        return items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
    }
}

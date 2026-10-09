import Foundation

/// The facts a summary's look-back paragraph may state (plan §5). Each fact has an ID from a fixed set,
/// so the on-device model can cite the facts behind every sentence and a validator can check them.
public struct SummaryFacts: Sendable, Equatable {
    public struct Fact: Sendable, Equatable {
        public let id: String
        public let text: String
        /// What a sentence citing this fact may mention: numbers, tag labels (lowercased) and dates ("sep 29").
        public let numbers: Set<Int>
        public let labels: Set<String>
        public let dates: Set<String>

        public init(id: String, text: String, numbers: Set<Int> = [], labels: Set<String> = [], dates: Set<String> = []) {
            self.id = id
            self.text = text
            self.numbers = numbers
            self.labels = labels
            self.dates = dates
        }
    }

    public static let ids = ["count", "range",
                             "feeling1", "feeling2", "feeling3", "situation1", "situation2", "situation3",
                             "helped1", "helped2", "helped3", "topic1", "topic2", "topic3", "pair1", "pair2"]

    public let facts: [Fact]

    public init(facts: [Fact]) { self.facts = facts }

    public subscript(id: String) -> Fact? { facts.first { $0.id == id } }

    /// Every kept label in the sheet, lowercased.
    public var labels: Set<String> { facts.reduce(into: Set<String>()) { $0.formUnion($1.labels) } }
    public var numbers: Set<Int> { facts.reduce(into: Set<Int>()) { $0.formUnion($1.numbers) } }
    public var dates: Set<String> { facts.reduce(into: Set<String>()) { $0.formUnion($1.dates) } }

    /// The sheet as the model sees it: one "[id] text" line per fact.
    public var prompt: String { facts.map { "[\($0.id)] \($0.text)" }.joined(separator: "\n") }

    /// Same counting as `SummaryComposer`: kept tags only, once per entry, case-insensitive.
    public static func make(entries: [Entry], calendar: Calendar = .current) -> SummaryFacts {
        let selected = entries.sorted { $0.createdAt < $1.createdAt }
        let n = selected.count
        guard let first = selected.first, let last = selected.last else { return SummaryFacts(facts: []) }
        let dates = DateLabels(calendar: calendar)
        var facts = [Fact(id: "count", text: "You chose \(n) \(n == 1 ? "entry" : "entries").", numbers: [n])]

        let year = calendar.component(.year, from: last.createdAt)
        let from = dates.short(first.createdAt), to = dates.short(last.createdAt)
        let days = Set([first.createdAt, last.createdAt].map { calendar.component(.day, from: $0) })
        facts.append(from == to
            ? Fact(id: "range", text: "It's from \(from), \(year).", numbers: days.union([year]), dates: [from.lowercased()])
            : Fact(id: "range", text: "They run from \(from) to \(to), \(year).", numbers: days.union([year]),
                   dates: [from.lowercased(), to.lowercased()]))

        let counts = SummaryComposer.keptCounts(selected)
        for kind in TagKind.allCases {
            for (rank, item) in SummaryComposer.byKind(kind, counts).prefix(3).enumerated() {
                facts.append(Fact(id: "\(kind.rawValue)\(rank + 1)", text: phrase(kind, item.label, item.n, of: n),
                                  numbers: [item.n, n], labels: [item.label.lowercased()]))
            }
        }

        for (rank, pair) in pairs(selected).prefix(2).enumerated() {
            facts.append(Fact(id: "pair\(rank + 1)", text: "“\(pair.a)” and “\(pair.b)” were kept together in \(pair.n) entries.",
                              numbers: [pair.n], labels: [pair.a.lowercased(), pair.b.lowercased()]))
        }
        return SummaryFacts(facts: facts)
    }

    private static func phrase(_ kind: TagKind, _ label: String, _ count: Int, of n: Int) -> String {
        switch kind {
        case .feeling: "You kept the feeling “\(label)” in \(count) of the \(n) entries."
        case .situation: "You kept “\(label)” as something that happened in \(count) of the \(n) entries."
        case .helped: "You noted “\(label)” as something that helped in \(count) of the \(n) entries."
        case .topic: "“\(label)” came up as a topic in \(count) of the \(n) entries."
        }
    }

    /// Kept tags that appear together in the same entry at least twice, most often first.
    static func pairs(_ selected: [Entry]) -> [(a: String, b: String, n: Int)] {
        var pairs: [(a: String, b: String, n: Int)] = []
        for entry in selected {
            var seen = Set<String>()
            let tags = entry.keptTags.map(\.label).filter { seen.insert($0.lowercased()).inserted }
            for i in tags.indices {
                for j in tags.indices where j > i {
                    let key = Set([tags[i].lowercased(), tags[j].lowercased()])
                    if let k = pairs.firstIndex(where: { Set([$0.a.lowercased(), $0.b.lowercased()]) == key }) {
                        pairs[k].n += 1
                    } else {
                        pairs.append((tags[i], tags[j], 1))
                    }
                }
            }
        }
        return pairs.enumerated()
            .filter { $0.element.n >= 2 }
            .sorted { $0.element.n != $1.element.n ? $0.element.n > $1.element.n : $0.offset < $1.offset }
            .map(\.element)
    }
}

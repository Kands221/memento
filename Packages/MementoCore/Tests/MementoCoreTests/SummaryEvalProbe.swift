import Foundation
import FoundationModels
import Testing
@testable import MementoCore

/// Live: Sol's look-back paragraph on Apple's on-device model, scored by a checker independent of the validator
/// (sheet-wide numbers, labels and dates; causal and clinical words). `MEMENTO_EVAL=1 swift test --filter SummaryEval`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["MEMENTO_EVAL"] == "1"), .serialized)
struct SummaryEvalProbe {
    static func sheet(_ n: Int, from: String, to: String, feelings: [(String, Int)] = [], situations: [(String, Int)] = [],
                      helped: [(String, Int)] = [], topics: [(String, Int)] = [], pairs: [(String, String, Int)] = []) -> SummaryFacts {
        func day(_ d: String) -> Int { Int(d.split(separator: " ").last ?? "") ?? 0 }
        var facts: [SummaryFacts.Fact] = [
            .init(id: "count", text: "You chose \(n) \(n == 1 ? "entry" : "entries").", numbers: [n]),
            from == to
                ? .init(id: "range", text: "It's from \(from), 2026.", numbers: [day(from), 2026], dates: [from.lowercased()])
                : .init(id: "range", text: "They run from \(from) to \(to), 2026.", numbers: [day(from), day(to), 2026],
                        dates: [from.lowercased(), to.lowercased()]),
        ]
        let kinds: [(String, [(String, Int)], (String, Int) -> String)] = [
            ("feeling", feelings, { "You kept the feeling “\($0)” in \($1) of the \(n) entries." }),
            ("situation", situations, { "You kept “\($0)” as something that happened in \($1) of the \(n) entries." }),
            ("helped", helped, { "You noted “\($0)” as something that helped in \($1) of the \(n) entries." }),
            ("topic", topics, { "“\($0)” came up as a topic in \($1) of the \(n) entries." }),
        ]
        for (kind, items, phrase) in kinds {
            for (i, item) in items.enumerated() {
                facts.append(.init(id: "\(kind)\(i + 1)", text: phrase(item.0, item.1), numbers: [item.1, n], labels: [item.0.lowercased()]))
            }
        }
        for (i, p) in pairs.enumerated() {
            facts.append(.init(id: "pair\(i + 1)", text: "“\(p.0)” and “\(p.1)” were kept together in \(p.2) entries.",
                               numbers: [p.2], labels: [p.0.lowercased(), p.1.lowercased()]))
        }
        return SummaryFacts(facts: facts)
    }

    static let sheets: [SummaryFacts] = [
        sheet(9, from: "Sep 29", to: "Oct 8", feelings: [("Drained", 4), ("Anxious", 3), ("Hopeful", 2)], situations: [("Work deadlines", 5), ("Poor sleep", 3)],
              helped: [("Walking helped", 3), ("Talking to a friend", 2)], topics: [("Work", 6), ("Family", 2)], pairs: [("Drained", "Work deadlines", 3)]),
        sheet(3, from: "Oct 2", to: "Oct 8", feelings: [("Calm", 2), ("Grateful", 1)], helped: [("Time outside", 2)], topics: [("Home", 2)]),
        sheet(1, from: "Oct 7", to: "Oct 7", feelings: [("Proud", 1)], situations: [("Trying something new", 1)], topics: [("Creativity", 1)]),
        sheet(14, from: "Sep 12", to: "Oct 9", feelings: [("Overwhelmed", 6), ("Restless", 4), ("Lighter", 3)], situations: [("Long hours", 7), ("Conflict", 2)],
              helped: [("Exercise", 4), ("Rest", 3), ("Music", 2)], topics: [("Work", 9), ("Health", 3)], pairs: [("Overwhelmed", "Long hours", 5), ("Lighter", "Exercise", 3)]),
        sheet(6, from: "Sep 30", to: "Oct 9", feelings: [("Lonely", 3), ("Sad", 2)], situations: [("Missing someone", 3)], helped: [("Time with family", 2)],
              topics: [("Relationships", 4)], pairs: [("Lonely", "Missing someone", 2)]),
        sheet(5, from: "Oct 1", to: "Oct 9", situations: [("Busy day", 3)], topics: [("Work", 5)]),
        sheet(8, from: "Sep 20", to: "Oct 5", feelings: [("Joyful", 3), ("Absorbed", 3), ("Content", 2)], helped: [("Making things", 4), ("Cooking", 2)],
              topics: [("Creativity", 5), ("Friends", 2)], pairs: [("Absorbed", "Making things", 3)]),
        sheet(4, from: "Oct 3", to: "Oct 9", feelings: [("Frustrated", 2), ("Relieved", 1)], situations: [("Money worries", 2), ("Change of plans", 1)],
              helped: [("Writing it down", 2)], topics: [("Money", 3)]),
    ]

    /// Independent of `SummaryNarrator.check`: judges against the whole sheet, not the cited facts.
    static func errors(_ text: String, sheet: SummaryFacts) -> [String] {
        var t = text.lowercased()
        var found: [String] = []
        let dateRegex = try! NSRegularExpression(pattern: #"\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d{1,2}\b"#)
        for m in dateRegex.matches(in: t, range: NSRange(t.startIndex..., in: t)).reversed() {
            guard let r = Range(m.range, in: t) else { continue }
            let parts = t[r].split(separator: " ")
            if !sheet.dates.contains("\(parts[0].prefix(3)) \(parts.last!)") { found.append("date") }
            t.replaceSubrange(r, with: " ")
        }
        let strict = (TagVocabulary.feelings + TagVocabulary.situations + TagVocabulary.helped).map { $0.lowercased() }
            .filter { !["rest", "music", "reading", "cooking", "exercise", "conflict", "boundaries"].contains($0) }
        for label in strict.sorted(by: { $0.count > $1.count }) where t.range(of: "\\b\(label)\\b", options: .regularExpression) != nil {
            if !sheet.labels.contains(label) { found.append("label: \(label)") }
            t = t.replacingOccurrences(of: "\\b\(label)\\b", with: " ", options: .regularExpression)
        }
        let digits = try! NSRegularExpression(pattern: #"\b\d+\b"#)
        for m in digits.matches(in: t, range: NSRange(t.startIndex..., in: t)) {
            if let r = Range(m.range, in: t), let v = Int(t[r]), !sheet.numbers.contains(v) { found.append("number \(v)") }
        }
        let words = ["twice": 2, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "fourteen": 14]
        for (w, v) in words where !sheet.numbers.contains(v) && t.range(of: "\\b\(w)\\b", options: .regularExpression) != nil { found.append("number \(w)") }
        if t.range(of: #"\b(because|due to|led to|lead to|caused|given the|as a result|triggered|which is why|made you|makes you)\b"#, options: .regularExpression) != nil { found.append("causal") }
        if t.range(of: #"\b(a lot|lots of|most of the time|all the time|always|constantly|so much)\b"#, options: .regularExpression) != nil { found.append("vague amount") }
        if ["depress", "disorder", "diagnos", "symptom", "trauma", "burnout"].contains(where: t.contains) { found.append("clinical") }
        return found
    }

    @Test func narrativesStayTrueToTheFacts() async {
        guard SystemLanguageModel.default.isAvailable else { return }
        var runs = 0, pre = 0, shown = 0, fallbacks = 0, rejected = 0, attempts = 0
        var seconds: [Double] = []
        for (i, sheet) in Self.sheets.enumerated() {
            for run in 1...2 {
                let start = Date()
                let (narration, report) = await SummaryNarrator.narrateWithReport(sheet)
                seconds.append(Date().timeIntervalSince(start))
                runs += 1
                attempts += report.attempts
                rejected += report.rejectedSentences
                let draftErrors = Self.errors(report.firstDraft.joined(separator: " "), sheet: sheet)
                if !draftErrors.isEmpty || report.firstDraft.isEmpty { pre += 1 }
                if let narration {
                    let e = Self.errors(narration.text, sheet: sheet)
                    if !e.isEmpty { shown += 1 }
                    print("[sheet \(i + 1)/\(run)] \(String(format: "%.1fs", seconds.last!)) \(narration.text) \(e.isEmpty ? "✓" : "✗ \(e)")")
                } else {
                    fallbacks += 1
                    print("[sheet \(i + 1)/\(run)] fallback (deterministic paragraph) · first draft errors: \(draftErrors)")
                }
                if !draftErrors.isEmpty { print("    first draft: \(report.firstDraft.joined(separator: " ")) ✗ \(draftErrors)") }
            }
        }
        let sorted = seconds.sorted()
        print("EVAL summary narrative: pre-validation \(pre)/\(runs) with errors, shown to writer \(shown)/\(runs) with errors, fallbacks \(fallbacks) · "
              + "rejected sentences \(rejected), attempts \(attempts), p50 \(String(format: "%.1f", sorted[sorted.count / 2]))s")
        #expect(shown == 0)
    }
}

import Foundation

/// Port of the prototype's RULES/analyze(): first match per rule, no overlaps, at most five.
public enum RuleTagger {
    struct Rule: Sendable {
        let label: String
        let kind: TagKind
        let pattern: String
    }

    static let rules: [Rule] = [
        Rule(label: "Drained", kind: .feeling, pattern: #"(?:i (?:felt|feel|am|was|'m) |i'm )?(?:so |really |completely )?(?:drained|exhausted|wiped out|worn out)"#),
        Rule(label: "Overwhelmed", kind: .feeling, pattern: #"(?:i (?:felt|feel|am|was) |i'm )?(?:so |really )?overwhelm\w*"#),
        Rule(label: "Anxious", kind: .feeling, pattern: #"(?:i (?:felt|feel|am|was) |i'm )?(?:so |really )?(?:anxious|worried|on edge|nervous)"#),
        Rule(label: "Hopeful", kind: .feeling, pattern: #"(?:still |i'm |i feel )?(?:hopeful|optimistic)[^.!?,\n]*"#),
        Rule(label: "Grateful", kind: .feeling, pattern: #"(?:grateful|thankful)[^.!?,\n]*"#),
        Rule(label: "Lonely", kind: .feeling, pattern: #"(?:lonely|left out)"#),
        Rule(label: "Calm", kind: .feeling, pattern: #"(?:felt |feel )?(?:calm|at peace|lighter)[^.!?,\n]*"#),
        Rule(label: "Work deadlines", kind: .situation, pattern: #"(?:(?:back-to-back|tight|endless|too many) )?deadlines?"#),
        Rule(label: "Poor sleep", kind: .situation, pattern: #"(?:couldn't|could not|didn't|barely|can't) (?:get to )?sleep[^.!?,\n]*|slept (?:badly|poorly)|(?:poor|bad|little) sleep"#),
        Rule(label: "Conflict", kind: .situation, pattern: #"(?:argu\w+|fight with|fought|snapped at)[^.!?,\n]*"#),
        Rule(label: "Talking to a friend", kind: .helped, pattern: #"(?:called|talked to|talked with|call with) (?:a friend|my friend|friends|my sister|my brother|my mum|my mom|Priya)"#),
        Rule(label: "Walking helped", kind: .helped, pattern: #"(?:(?:a|the) )?(?:(?:short|long|quick) )?walk\w*[^.!?,\n]*"#),
        Rule(label: "Rest", kind: .helped, pattern: #"(?:a nap|napped|rested|an early night|lay down)[^.!?,\n]*"#),
        Rule(label: "Work", kind: .topic, pattern: #"\b(?:work|office|meeting|manager|sprint|inbox)\b"#),
        Rule(label: "Family", kind: .topic, pattern: #"\b(?:mum|mom|dad|family|parents)\b"#),
        Rule(label: "Relationships", kind: .topic, pattern: #"\b(?:partner|Theo)\b"#),
        Rule(label: "Creativity", kind: .topic, pattern: #"\b(?:paint\w*|drawing|sketch\w*|ceramics|guitar)\b"#),
    ]

    public static func analyze(_ text: String) -> [SuggestedTagDraft] {
        let ns = text as NSString
        var found: [(range: NSRange, draft: SuggestedTagDraft)] = []
        for rule in rules {
            guard let re = try? NSRegularExpression(pattern: rule.pattern, options: [.caseInsensitive]),
                  let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { continue }
            var quote = ns.substring(with: m.range)
            while let last = quote.last, last.isWhitespace || last == "," { quote.removeLast() }
            let range = NSRange(location: m.range.location, length: (quote as NSString).length)
            if found.contains(where: { NSIntersectionRange($0.range, range).length > 0 }) { continue }
            found.append((range, SuggestedTagDraft(label: rule.label, kind: rule.kind, quote: quote)))
            if found.count >= 5 { break }
        }
        return found.sorted { $0.range.location < $1.range.location }.map(\.draft)
    }
}

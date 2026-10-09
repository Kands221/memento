import Foundation
import FoundationModels

@Generable
struct NarrativeSentence {
    @Guide(description: "One warm sentence in plain words, speaking to the writer as \"you\"")
    var text: String
    @Guide(description: "The IDs of the facts this sentence uses", .element(.anyOf(SummaryFacts.ids)))
    var facts: [String]
}

@Generable
struct SummaryNarrativeContent {
    @Guide(description: "A short look-back of 2 to 4 sentences", .count(2...4))
    var sentences: [NarrativeSentence]
}

public struct SummaryNarration: Sendable, Equatable {
    public let text: String
    /// True when Sol wrote it; the caller labels the paragraph as drafted.
    public let isAIDrafted: Bool
}

/// What happened while drafting, for evals.
public struct SummaryNarrationReport: Sendable {
    public var attempts = 0
    /// The first attempt's sentences exactly as the model wrote them, before any checks.
    public var firstDraft: [String] = []
    public var rejectedSentences = 0
    public var engineFailures = 0
}

/// Sol's "look back" paragraph for "For me" summaries, on Apple's on-device model only (plan §5).
/// Code computes the facts; the model only phrases them and cites them by ID; every sentence is checked.
/// When fewer than two sentences survive two attempts, callers keep the deterministic paragraph.
public enum SummaryNarrator {
    public enum Problem: String, Sendable, CaseIterable {
        case number, label, kind, date, causal, interpretation, vagueAmount, clinical, feeling, advice, voice, repeated, tooShort, tooLong
    }

    struct DraftSentence: Sendable {
        let text: String
        let facts: [String]
    }

    struct DeadlineExceeded: Error {}

    static let instructions = """
    You are Sol, a gentle old tortoise, writing a short, warm look-back for someone about their own journal. \
    Speak to them as "you", never "I" or "my". Use only the facts given, but don't copy the fact sentences: \
    say them in your own warm words, and combine related facts in one sentence. Each sentence lists the IDs of \
    the facts it uses, and any number, tag or date it mentions must come from those facts. Never explain causes \
    or say what led to what, and don't interpret what the facts mean. Call each tag what the facts call it: a feeling, \
    something that happened, something that helped, or a topic. Use the exact numbers; never say "a lot", "always" \
    or "most of the time". Never diagnose or name conditions. Never give advice. 2 to 4 short sentences \
    (under 20 words each), each one different.
    """

    public static func narrate(_ facts: SummaryFacts) async -> SummaryNarration? {
        await narrateWithReport(facts).narration
    }

    public static func narrateWithReport(_ facts: SummaryFacts) async -> (narration: SummaryNarration?, report: SummaryNarrationReport) {
        guard SystemLanguageModel.default.isAvailable, facts["count"] != nil else { return (nil, SummaryNarrationReport()) }
        return await draft(facts) { prompt in try await generate(prompt) }
    }

    private static func generate(_ prompt: String) async throws -> [DraftSentence] {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt, generating: SummaryNarrativeContent.self,
                                                 options: GenerationOptions(temperature: 0.5))
        return response.content.sentences.map { DraftSentence(text: $0.text, facts: $0.facts) }
    }

    /// Two attempts at most, each in a fresh session with a 15 s deadline; the second carries a note about what went wrong.
    static func draft(_ facts: SummaryFacts, deadline: Duration = .seconds(15),
                      generate: @escaping @Sendable (String) async throws -> [DraftSentence]) async -> (SummaryNarration?, SummaryNarrationReport) {
        var report = SummaryNarrationReport()
        var note: String?
        for attempt in 1...2 {
            report.attempts = attempt
            let prompt = "Facts:\n\(facts.prompt)" + (note.map { "\n\nNote: \($0)" } ?? "")
            let sentences: [DraftSentence]
            do {
                sentences = try await withDeadline(deadline) { try await generate(prompt) }
            } catch {
                report.engineFailures += 1
                continue
            }
            if attempt == 1 { report.firstDraft = sentences.map(\.text) }
            var kept: [String] = []
            var problems = Set<Problem>()
            for sentence in sentences {
                var found = check(sentence.text, cites: sentence.facts, in: facts)
                if kept.contains(where: { normalized($0) == normalized(sentence.text) }) { found.insert(.repeated) }
                if found.isEmpty {
                    kept.append(tidy(sentence.text))
                } else {
                    report.rejectedSentences += 1
                    problems.formUnion(found)
                }
            }
            if kept.count >= 2 { return (SummaryNarration(text: kept.prefix(4).joined(separator: " "), isAIDrafted: true), report) }
            note = notes(for: problems.isEmpty ? [.tooShort] : problems)
        }
        return (nil, report)
    }

    static func withDeadline<T: Sendable>(_ limit: Duration, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(for: limit)
                throw DeadlineExceeded()
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw DeadlineExceeded() }
            return first
        }
    }

    static func notes(for problems: Set<Problem>) -> String {
        Problem.allCases.filter(problems.contains).map { problem in
            switch problem {
            case .number: "Only use numbers exactly as they appear in the facts a sentence cites."
            case .label: "Only mention tags that appear in the facts a sentence cites."
            case .kind: "Call each tag what the facts call it: a feeling, something that happened, something that helped, or a topic."
            case .interpretation: "Only state the facts; don't interpret what they mean or what the writer faced."
            case .vagueAmount: "Use the exact numbers instead of words like \"a lot\" or \"always\"."
            case .tooLong: "Keep each sentence under 20 words."
            case .date: "Only use dates that appear in the facts."
            case .causal: "Don't say what caused or led to anything."
            case .clinical: "Don't use clinical or diagnostic words."
            case .feeling: "Only mention feelings listed in the facts."
            case .advice: "Don't give advice."
            case .voice: "Speak to the writer as \"you\"; never write \"I\" or \"my\"."
            case .repeated: "Make every sentence different."
            case .tooShort: "Write 2 to 4 full sentences."
            }
        }.joined(separator: " ")
    }

    // MARK: Checks

    static let numberWords = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
                              "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15, "sixteen": 16,
                              "seventeen": 17, "eighteen": 18, "nineteen": 19, "twenty": 20]
    static let causal = #"\b(because|due to|led to|leads to|lead to|leading to|caused|causes|given the|so you|which is why|triggered|as a result|resulted in|made you|makes you|making you|left you)\b"#
    static let vagueAmount = #"\b(a lot|lots of|most of the time|all the time|always|constantly|every day|so much|for a long time|many)\b"#
    static let clinical = ["depression", "depressive", "disorder", "diagnos", "symptom", "trauma", "burnout", "ptsd", "adhd", "bipolar"]
    static let advice = #"\b(you should|try to|consider|make sure|it's important to|it’s important to|remember to|don't forget)\b"#
    static let interpretation = #"\b(reflect(s|ing|ed)?|suggest(s|ing|ed)?|shows? that|seem(s|ed)? to|indicat\w*|means? that|struggl\w*|challenges|pressures|cop(e|ed|ing)|manag(e|ed|ing) your|despite)\b"#
    /// Feeling words outside the tag vocabulary that the model might reach for.
    static let otherFeelings = ["stressed", "exhausted", "tired", "depressed", "worried", "happy", "upset", "angry", "scared",
                                "afraid", "hopeless", "nervous", "ashamed", "guilty", "excited", "burned out", "burnt out", "stress"]
    /// Tag labels that are also everyday words ("at work", "the rest of"); only checked when the sheet cites them.
    static let everydayLabels: Set<String> = ["work", "home", "rest", "family", "friends", "money", "health", "reading", "music",
                                              "learning", "cooking", "exercise", "conflict", "boundaries", "relationships", "creativity"]

    /// Problems in one sentence, given the facts it cites. Empty means it can be shown.
    static func check(_ sentence: String, cites: [String], in facts: SummaryFacts) -> Set<Problem> {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(separator: " ").count
        guard words >= 3 else { return [.tooShort] }
        var text = trimmed.lowercased()
            .replacingOccurrences(of: "“", with: "\"").replacingOccurrences(of: "”", with: "\"").replacingOccurrences(of: "’", with: "'")
        let cited = cites.compactMap { facts[$0] }
        var numbers = cited.reduce(into: Set<Int>()) { $0.formUnion($1.numbers) }
        let labels = cited.reduce(into: Set<String>()) { $0.formUnion($1.labels) }
        let dates = cited.reduce(into: Set<String>()) { $0.formUnion($1.dates) }
        var problems = Set<Problem>()

        // Dates first, so their day numbers aren't read as counts.
        for match in matches(#"\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(\d{1,2})\b"#, in: text) {
            let parts = match.split(separator: " ")
            let month = parts.first.map { String($0.prefix(3)) } ?? ""
            if !dates.contains("\(month) \(parts.last ?? "")") { problems.insert(.date) }
            text = text.replacingOccurrences(of: match, with: " ")
        }

        // Longest labels first, so "work deadlines" isn't also read as "work".
        let vocabulary = (TagVocabulary.feelings + TagVocabulary.situations + TagVocabulary.helped + TagVocabulary.topics).map { $0.lowercased() }
        let feelings = Set(TagVocabulary.feelings.map { $0.lowercased() })
        var mentionedKinds = Set<String>()
        var mentionedLabels = Set<String>()
        let kindWords: [(kind: String, pattern: String)] = [("feeling", #"\b(the feeling|feelings?|felt)\b"#), ("topic", #"\btopics?\b"#),
                                                            ("helped", #"\b(helped|helps|helping)\b"#)]
        let saysKinds = Set(kindWords.filter { text.range(of: $0.pattern, options: .regularExpression) != nil }.map(\.kind))
        for label in Set(vocabulary).union(facts.labels).sorted(by: { $0.count > $1.count }) {
            let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: label) + #"\b"#
            guard text.range(of: pattern, options: .regularExpression) != nil else { continue }
            if let kind = kind(of: label, in: facts) { mentionedKinds.insert(kind) }
            if labels.contains(label) { mentionedLabels.insert(label) }
            if !labels.contains(label) && !everydayLabels.contains(label) {
                problems.insert(!facts.labels.contains(label) && feelings.contains(label) ? .feeling : .label)
            }
            text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }

        // "the feeling “Busy day”" or "Money worries were a topic": the sentence names a kind none of its tags have.
        for kind in saysKinds where !mentionedKinds.isEmpty && !mentionedKinds.contains(kind) { problems.insert(.kind) }
        // "something that helped you" when nothing was kept as helping.
        for kind in saysKinds where !facts.facts.contains(where: { $0.id.hasPrefix(kind) }) { problems.insert(.kind) }

        // When a sentence names tags, its counts must be those tags' counts (or the entry count and dates):
        // "work in 3 of the 5 entries" is wrong when 3 belongs to another tag.
        if !mentionedLabels.isEmpty {
            numbers = cited.filter { fact in fact.id == "count" || fact.id == "range" || !fact.labels.isDisjoint(with: mentionedLabels) }
                .reduce(into: Set<Int>()) { $0.formUnion($1.numbers) }
        }

        for digits in matches(#"\b\d+\b"#, in: text) where !numbers.contains(Int(digits) ?? -1) { problems.insert(.number) }
        for (word, value) in ["once": 1, "twice": 2] where !numbers.contains(value) {
            if text.range(of: #"\b\#(word)\b"#, options: .regularExpression) != nil { problems.insert(.number) }
        }
        // Number words only count when they count something ("four of the nine entries", "three times").
        for (word, value) in numberWords where !numbers.contains(value) {
            let counted = #"\b"# + word + #"\b(\s+of)?(\s+the)?(\s+\w+)?\s+(entries|entry|times|days|weeks|nights)\b"#
            if text.range(of: counted, options: .regularExpression) != nil { problems.insert(.number) }
        }

        if text.range(of: causal, options: .regularExpression) != nil { problems.insert(.causal) }
        if clinical.contains(where: text.contains) { problems.insert(.clinical) }
        if text.range(of: #"\b(i|my|me|mine|myself|i'm|i've|i'd|i'll)\b"#, options: .regularExpression) != nil { problems.insert(.voice) }
        if text.range(of: advice, options: .regularExpression) != nil { problems.insert(.advice) }
        if text.range(of: interpretation, options: .regularExpression) != nil { problems.insert(.interpretation) }
        if text.range(of: vagueAmount, options: .regularExpression) != nil { problems.insert(.vagueAmount) }
        if words > 28 { problems.insert(.tooLong) }
        if otherFeelings.contains(where: { word in
            text.range(of: #"\b\#(word)\b"#, options: .regularExpression) != nil && !facts.labels.contains { $0.contains(word) }
        }) { problems.insert(.feeling) }
        return problems
    }

    private static func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }

    /// "feeling", "situation", "helped" or "topic" for a kept label, from the fact that lists it.
    private static func kind(of label: String, in facts: SummaryFacts) -> String? {
        facts.facts.first { $0.labels.contains(label) && !$0.id.hasPrefix("pair") && $0.id.last?.isNumber == true }
            .map { String($0.id.prefix { $0.isLetter }) }
    }

    private static func normalized(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber } }

    static func tidy(_ sentence: String) -> String {
        let t = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = t.last else { return t }
        return ".!?".contains(last) ? t : t + "."
    }
}

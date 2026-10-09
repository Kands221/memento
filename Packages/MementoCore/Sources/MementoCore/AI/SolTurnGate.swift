import Foundation

/// What kind of reply a message calls for, so Sol isn't one template (plan §4b).
public enum SolTurnKind: String, Sendable, CaseIterable {
    /// A greeting or a one-word hello.
    case smallTalk
    /// The writer asked Sol something: answer it first.
    case answer
    /// Good news: celebrate it, don't analyse it.
    case celebrate
    /// Very little said: one warm line and a gentle question.
    case listen
    /// Today's reflect, perspective, question shape.
    case reflect

    public static func of(_ text: String, steerTowardReflection: Bool) -> SolTurnKind {
        let t = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if SolTurnPlanner.isSmallTalk(t) && !steerTowardReflection { return .smallTalk }
        if steerTowardReflection { return .reflect }
        let asks = t.contains("?") && t.range(of: #"(^|\b)(what should|should i|what would you|what do you think|do you think|any advice|how (do|can|should) i|what can i|is it (ok|okay|normal|bad)|why do i|would you|can you|could you|which)\b"#,
                                             options: .regularExpression) != nil
        if asks { return .answer }
        let good = t.range(of: #"(got the job|good news|so happy|really good|great day|good day|went well|best day|proud|excited|finally|grateful|amazing|wonderful|loved it|it worked|i did it|passed|promotion|engaged|!!)"#,
                           options: .regularExpression) != nil
        let hard = t.range(of: #"\b(but|tired|sad|anxious|stress|stressed|hard|worried|nervous|bad|awful|lonely|miss|scared|afraid|angry|hurt|not)\b"#,
                           options: .regularExpression) != nil
        if good && !hard { return .celebrate }
        if t.split(whereSeparator: \.isWhitespace).count <= 4 { return .listen }
        return .reflect
    }

    /// Most sentences each part may keep: replies grow with what the writer wrote.
    public func budgets(forWords words: Int) -> [Int] {
        switch self {
        case .smallTalk: [2]
        case .answer: [words > 25 ? 3 : 2]
        case .celebrate: [2]
        case .listen: [1]
        case .reflect: words <= 12 ? [1, 1] : words <= 40 ? [2, 1] : [2, 2]
        }
    }
}

/// One streamed draft of a Sol turn, whatever kind produced it.
public struct SolDraftSnapshot: Sendable, Equatable {
    /// The reply's statement parts in order, e.g. reflection then perspective.
    public var parts: [String?]
    /// How many leading parts have finished streaming.
    public var completeParts: Int
    public var question: String?
    public var suggestions: [String]?
    public var usedMemory: Bool?
    public var theme: String?

    public init(parts: [String?], completeParts: Int, question: String? = nil, suggestions: [String]? = nil,
                usedMemory: Bool? = nil, theme: String? = nil) {
        self.parts = parts
        self.completeParts = completeParts
        self.question = question
        self.suggestions = suggestions
        self.usedMemory = usedMemory
        self.theme = theme
    }

    public var finished: SolDraftSnapshot {
        var s = self
        s.completeParts = parts.count
        return s
    }
}

/// Lets Sol's reply out one checked sentence at a time (plan §4, §4b). Sentences that break a rule are dropped
/// before they're shown or spoken; questions are held back so the turn ends with exactly one.
public struct SolTurnGate: Sendable {
    let check: SolReplyCheck
    let budgets: [Int]
    let writerSaid: String
    public private(set) var shown: [String] = []
    public private(set) var dropped: [SolReplyCheck.Issue] = []
    /// The last question the model tucked into a statement part; used if the question field comes back empty.
    public private(set) var strayQuestion: String?
    private var consumed: [Int]
    private var kept: [Int]

    public init(check: SolReplyCheck, budgets: [Int], writerSaid: String) {
        self.check = check
        self.budgets = budgets
        self.writerSaid = writerSaid
        consumed = Array(repeating: 0, count: budgets.count)
        kept = Array(repeating: 0, count: budgets.count)
    }

    /// The reply text to show, when it grew.
    public mutating func feed(_ snapshot: SolDraftSnapshot) -> String? {
        var grew = false
        for i in budgets.indices where i < snapshot.parts.count {
            let all = SolReplyCheck.sentences(in: snapshot.parts[i] ?? "", includeTrailing: i < snapshot.completeParts)
            guard all.count > consumed[i] else { continue }
            for raw in all[consumed[i]...] {
                let sentence = SolTurnPlanner.soften(SolReplyCheck.tidy(raw, writerSaid: writerSaid))
                if sentence.hasSuffix("?") {
                    strayQuestion = sentence
                    continue
                }
                guard kept[i] < budgets[i] else { continue }
                let issues = check.issues(in: sentence, isOpening: shown.isEmpty)
                if issues.isEmpty {
                    shown.append(sentence)
                    kept[i] += 1
                    grew = true
                } else {
                    dropped.append(contentsOf: issues)
                }
            }
            consumed[i] = all.count
        }
        return grew ? shown.joined(separator: " ") : nil
    }

    /// The turn's one question: the model's, cleaned and checked, else a fresh one Sol hasn't asked.
    public func question(from proposed: String?, asked: [String]) -> String {
        var candidate = proposed.flatMap { q -> String? in
            let pieces = SolReplyCheck.sentences(in: q, includeTrailing: true)
            if let last = pieces.last(where: { $0.hasSuffix("?") }) { return last }
            let t = q.trimmingCharacters(in: .whitespacesAndNewlines)
            let interrogative = t.lowercased().range(of: #"^(what|how|who|when|where|why|which|is|are|do|does|did|would|could|can|will|have|has|might|if)\b"#,
                                                     options: .regularExpression) != nil
            return interrogative && !t.isEmpty ? t.trimmingCharacters(in: CharacterSet(charactersIn: ".!")) + "?" : nil
        } ?? strayQuestion
        if let q = candidate {
            let cleaned = SolReplyCheck.tidy(q, writerSaid: writerSaid)
            let words = cleaned.split(whereSeparator: \.isWhitespace).count
            candidate = check.issues(in: cleaned, isOpening: false).isEmpty && words <= 30 ? cleaned : nil
        }
        if let q = candidate {
            return SolTurnPlanner.freshQuestion(q, asked: asked) ?? q
        }
        return SolTurnPlanner.unusedFollowUp(asked: asked)
    }

    /// Two short quick replies the writer could tap; anything that reads like Sol or a question is dropped.
    /// If the model's don't fit, simple answers that match the question's form stand in.
    public static func quickReplies(_ suggestions: [String]?, question: String? = nil) -> [String] {
        let picked = modelQuickReplies(suggestions)
        guard picked.count < 2, let question else { return picked }
        let yesNo = question.lowercased().range(of: #"^(have|has|do|does|did|is|are|was|were|would|could|can|will|should)\b"#,
                                                options: .regularExpression) != nil
        let standIns = yesNo ? ["Yes, a little", "Not really"] : ["I'm not sure yet", "Let me think"]
        return Array((picked + standIns.filter { s in !picked.contains { $0.lowercased() == s.lowercased() } }).prefix(2))
    }

    static func modelQuickReplies(_ suggestions: [String]?) -> [String] {
        var seen = Set<String>()
        return Array((suggestions ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”"))) }
            .filter { s in
                let words = s.split(whereSeparator: \.isWhitespace).count
                return words >= 1 && words <= 7 && !s.hasSuffix("?") && !s.lowercased().hasPrefix("sol") && seen.insert(s.lowercased()).inserted
            }
            .prefix(2))
    }
}

extension SolTurnPlanner {
    /// A follow-up question not yet asked in this conversation.
    public static func unusedFollowUp(asked: [String]) -> String {
        func norm(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber } }
        let askedSet = Set(asked.map(norm))
        return followUps.first { !askedSet.contains(norm($0)) } ?? followUps[asked.count % followUps.count]
    }

    /// Sol's reply when the model can't give one in time: still in his voice, still moving the conversation on.
    public static func fallbackTurn(asked: [String]) -> SolTurn {
        let openers = ["Let me sit with that for a moment, slowly, the way old tortoises do.",
                       "Thank you for telling me. I'm turning that over carefully.",
                       "I hear you. Let's take this one small step at a time."]
        let reply = openers[asked.count % openers.count] + " " + unusedFollowUp(asked: asked)
        return SolTurn(reply: reply, suggestions: ["I'm not sure yet", "Let me think"], usedFallback: true)
    }
}

extension SolTurnPlanner {
    /// The on-device prompt for one turn, shaped by its kind (plan §4b).
    public static func onDevicePrompt(kind: SolTurnKind, text: String, askedQuestions: [String], usedThemes: [String],
                                      steerTowardReflection: Bool, memory: String? = nil, notes: [String] = []) -> String {
        var lines = ["The writer says: \"\(text)\""]
        if !notes.isEmpty {
            lines.append("What the writer told you earlier in this conversation: \(notes.joined(separator: "; ")).")
        }
        switch kind {
        case .smallTalk:
            lines.append("\(smallTalkMarker) Greet them warmly in one or two sentences, in your own voice, and ask what's on their heart. Don't offer advice.")
        case .answer:
            lines.append("The writer asked you something. Answer it first: directly, warmly and practically, in plain words. Then ask one short follow-up question.")
        case .celebrate:
            lines.append("The writer is sharing good news. Celebrate it with them, specifically and warmly, with a little playfulness, and invite them to savor it. Don't add worries or advice.")
        case .listen:
            lines.append("The writer said very little. Reply with one short, warm sentence that uses their words, then one gentle question. Don't guess how they feel.")
        case .reflect:
            if text.split(whereSeparator: \.isWhitespace).count <= 12 {
                lines.append("They wrote briefly, so keep your reflection and perspective to one sentence each.")
            }
        }
        if let memory, kind == .reflect || kind == .answer {
            lines.append("From the writer's journal, a closely related moment: \(memory)\nIf it genuinely helps, mention it once with its date and in their own words, and set usedMemory to true. Otherwise leave it out and set usedMemory to false.")
        }
        if kind == .reflect, !usedThemes.isEmpty {
            lines.append("Perspectives you already offered (choose a different theme): \(usedThemes.joined(separator: "; ")).")
        }
        if kind != .smallTalk, !askedQuestions.isEmpty {
            lines.append("Questions you already asked (ask something new): \(askedQuestions.joined(separator: " | "))")
        }
        if steerTowardReflection {
            lines.append("For your question, gently offer to turn this conversation into a written reflection the writer can keep.")
        }
        lines.append("Name only feelings the writer named.")
        return lines.joined(separator: "\n")
    }

    /// One line telling the model what to avoid on its second try.
    public static func retryNote(for issues: [SolReplyCheck.Issue]) -> String {
        var notes: [String] = []
        if issues.contains(.bannedOpener) { notes.append("Begin by reflecting their own words; don't start with 'That sounds', 'It sounds like' or 'I'm sorry'.") }
        if issues.contains(.assumedFeeling) { notes.append("Don't say how they feel unless they said it.") }
        if issues.contains(.clinicalWord) { notes.append("Don't use clinical or diagnostic words.") }
        if issues.contains(.inventedMemory) { notes.append("Don't mention past entries or dates unless they're given above.") }
        if issues.contains(.quotesSomeone) { notes.append("Use only your own words; don't quote anyone.") }
        if issues.contains(.repeatsItself) { notes.append("Say something new; don't repeat what you said earlier.") }
        if issues.contains(.speaksAsWriter) { notes.append("You are Sol, not the writer: talk to them about their experience, don't speak as them.") }
        return notes.isEmpty ? "Keep it warm, specific and short." : notes.joined(separator: " ")
    }

    /// Notes are kept only if they're grounded in what the writer actually wrote.
    public static func groundedNotes(_ candidates: [String], in writerMessages: [String]) -> [String] {
        let said = writerMessages.joined(separator: " ").lowercased()
        let saidWords = Set(said.split { !$0.isLetter }.map(String.init).filter { $0.count >= 3 })
        var notes: [String] = []
        for note in candidates {
            let t = note.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, t.count <= 80 else { continue }
            let names = t.split { !$0.isLetter }.map(String.init).filter { $0.first?.isUppercase == true && $0.count > 1 }
            let namesOK = names.allSatisfy { said.contains($0.lowercased()) || ["I", "The", "Their", "My", "A", "An"].contains($0) }
            let shared = t.lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count >= 3 && saidWords.contains($0) }
            if namesOK && !shared.isEmpty && !notes.contains(t) { notes.append(t) }
        }
        return Array(notes.prefix(6))
    }

    /// Strips preambles and formatting, and drops sentences that add feelings or clinical words the writer didn't use.
    /// Nil when what's left isn't a first-person reflection of at least two sentences.
    public static func cleanReflection(_ raw: String, writerMessages: [String]) -> String? {
        let check = SolReplyCheck(writerMessages: writerMessages)
        let said = writerMessages.joined(separator: " ").lowercased()
        var paragraphs: [String] = []
        for line in raw.components(separatedBy: "\n") {
            var p = line.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "#*\"“”"))
                .trimmingCharacters(in: .whitespaces)
            if p.isEmpty { continue }
            if p.lowercased().range(of: #"^(here('s| is)|sure|certainly|of course|reflection:|title:)"#, options: .regularExpression) != nil { continue }
            let kept = SolReplyCheck.sentences(in: p, includeTrailing: true).filter { s in
                let lower = s.lowercased()
                let unsaidFeeling = SolReplyCheck.feelingGroups.contains { group in
                    !group.contains { SolReplyCheck.has($0, in: said) } && group.contains { SolReplyCheck.has($0, in: lower) }
                }
                // A reflection is written as the writer, so first person is right here.
                return !unsaidFeeling && check.issues(in: s, isOpening: false).allSatisfy { $0 == .speaksAsWriter }
            }
            p = kept.joined(separator: " ")
            if !p.isEmpty { paragraphs.append(p) }
        }
        let text = paragraphs.joined(separator: "\n\n")
        let firstPerson = text.range(of: #"\b(I|I'm|I’m|I've|I’ve|my|me)\b"#, options: .regularExpression) != nil
        guard firstPerson, SolReplyCheck.sentences(in: text, includeTrailing: true).count >= 2 else { return nil }
        return text
    }
}

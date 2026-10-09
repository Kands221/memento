import Foundation
import FoundationModels

/// A reflect turn: mirror the writer, offer one fresh perspective, ask one new question.
@Generable
struct SolTurnContent {
    @Guide(description: "1 or 2 warm sentences reflecting the writer's own words back to them, specifically. Don't start with 'That sounds' or 'I'm sorry'. Name only feelings the writer named.")
    var reflection: String
    @Guide(description: "The theme for your perspective this turn; choose one that fits what the writer said and that you haven't used", .anyOf(SolCharacter.themes))
    var theme: String
    @Guide(description: "1 or 2 sentences of gentle perspective on the chosen theme, the way a wise old teacher would say it, tied to what the writer said. Plain words, not generic advice; never start with 'Remember'.")
    var perspective: String
    @Guide(description: "True only if your reply mentions the journal moment given in the prompt")
    var usedMemory: Bool
    @Guide(description: "One open, caring question that moves the conversation forward and is different from every question already asked")
    var question: String
    @Guide(description: "Two short answers the writer (not Sol) could tap to answer your question, written as the writer, 2 to 6 words each. Never questions, never advice.", .count(2))
    var suggestions: [String]
}

/// The writer asked Sol something: answer first.
@Generable
struct SolAnswerContent {
    @Guide(description: "Answer the writer's question directly in 1 to 3 sentences: warm, practical, plain words, in your own voice. No diagnosis and no medical advice.")
    var answer: String
    @Guide(description: "True only if your answer mentions the journal moment given in the prompt")
    var usedMemory: Bool
    @Guide(description: "One short, caring follow-up question")
    var question: String
    @Guide(description: "Two short answers the writer (not Sol) could tap, written as the writer, 2 to 6 words each. Never questions.", .count(2))
    var suggestions: [String]
}

/// Good news: celebrate with them.
@Generable
struct SolCelebrateContent {
    @Guide(description: "1 or 2 sentences celebrating exactly what the writer shared, warmly and with a little playfulness. No worries, no advice.")
    var delight: String
    @Guide(description: "One question inviting them to savor it, like what made it good or how they'll mark it")
    var question: String
    @Guide(description: "Two short answers the writer (not Sol) could tap, written as the writer, 2 to 6 words each. Never questions.", .count(2))
    var suggestions: [String]
}

/// Very little said: listen.
@Generable
struct SolListenContent {
    @Guide(description: "One short, warm sentence that shows you heard their exact words. Don't guess how they feel.")
    var reflection: String
    @Guide(description: "One gentle, open question")
    var question: String
    @Guide(description: "Two short answers the writer (not Sol) could tap, written as the writer, 2 to 6 words each. Never questions.", .count(2))
    var suggestions: [String]
}

@Generable
struct SolGreetingContent {
    @Guide(description: "A warm greeting of one or two sentences in Sol's voice that ends by asking what's on the writer's heart")
    var reply: String
    @Guide(description: "Two short things the writer (not Sol) might answer, 2 to 6 words each, e.g. \"Work, mostly\"", .count(2))
    var suggestions: [String]
}

/// What the writer has told Sol so far, so long chats keep their thread (plan §4b).
@Generable
struct ConversationNotesContent {
    @Guide(description: "People the writer mentioned, each with who they are in the writer's words, like 'Dana (their manager)'. Empty if none.", .maximumCount(4))
    var people: [String]
    @Guide(description: "Up to three things that happened to the writer, a few words each, using their words", .maximumCount(3))
    var events: [String]
}

/// Sol on Apple's on-device model, one session per conversation (spec §5.3, plan §4).
/// Every sentence passes `SolReplyCheck` before the writer sees or hears it; each turn has a time limit
/// and a safe composed reply if the model can't give a good one in time.
@MainActor
public final class FoundationModelSol: SolEngine {
    static var persona: String { SolCharacter.persona }

    static let reflectionInstructions = """
    Turn the writer's own messages into a short private journal reflection written in the first \
    person ("I"). Use only what the writer said; add no new facts, feelings, advice or diagnosis. \
    Plain, warm language. Do not address the reader. Write only the reflection itself.
    """

    /// The longest a turn may take before Sol answers with what he has.
    static let turnLimit: Duration = .seconds(25)
    static let reflectionLimit: Duration = .seconds(15)
    static let options = GenerationOptions(temperature: 0.7)
    static let debug = ProcessInfo.processInfo.environment["MEMENTO_DEBUG"] == "1"

    private var session: LanguageModelSession?
    private var askedQuestions: [String] = []
    private var usedThemes: [String] = []
    private var notes: [String] = []
    private var gate: SolTurnGate?
    private var generation: Task<SolDraftSnapshot?, any Error>?
    /// The latest snapshot of the current draft, kept even if the stream stops early.
    private var latest: SolDraftSnapshot?
    private var timedOut = false
    private let journal: JournalIndex?

    /// - Parameter journal: when given, Sol brings in a closely related moment from the writer's entries
    ///   ("Sol remembers"). Retrieval is done by the app, on device, so it doesn't depend on the model calling a tool.
    public init(journal: JournalIndex? = nil) {
        self.journal = journal
    }

    /// The session starts from the visible conversation and Sol's notes, so the model knows what was said
    /// (including the opening question) without carrying every earlier token.
    private func makeSession(earlier: [SolMessage]) -> LanguageModelSession {
        var instructions = Self.persona
        if !notes.isEmpty {
            instructions += "\n\nWhat the writer has told you in this conversation: " + notes.joined(separator: "; ") + "."
        }
        let recent = earlier.suffix(6).filter { $0.role != .support }
        if !recent.isEmpty {
            instructions += "\n\nThe conversation so far:\n" + recent.map { "\($0.role == .me ? "The writer said" : "You (Sol) said"): \($0.text)" }.joined(separator: "\n")
        }
        return LanguageModelSession(instructions: instructions)
    }

    public func prewarm() {
        let s = session ?? makeSession(earlier: [])
        session = s
        s.prewarm(promptPrefix: Prompt("The writer says: \""))
    }

    public func reset() {
        session = nil
        askedQuestions = []
        usedThemes = []
        notes = []
    }

    public func reply(to text: String, history: [SolMessage], steerTowardReflection: Bool) -> AsyncThrowingStream<SolTurn, any Error> {
        if askedQuestions.isEmpty, let opening = history.first(where: { $0.role == .sol })?.text { askedQuestions = [opening] }
        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    let turn = try await self.turn(text, history: history, steer: steerTowardReflection) { partial in
                        continuation.yield(SolTurn(reply: partial, suggestions: []))
                    }
                    continuation.yield(turn)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: Self.map(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func turn(_ text: String, history: [SolMessage], steer: Bool, show: @escaping (String) -> Void) async throws -> SolTurn {
        let kind = SolTurnKind.of(text, steerTowardReflection: steer)
        let writerMessages = history.filter { $0.role == .me }.map(\.text) + [text]
        let (memory, hits) = kind == .reflect || kind == .answer
            ? await SolTurnPlanner.recall(text, history: history, journal: journal) : (nil, [])
        let memoryDate = hits.first.map { DateLabels().short($0.snippet.date) }
        let check = SolReplyCheck(writerMessages: writerMessages, memory: hits.first?.snippet.text, memoryDate: memoryDate,
                                  earlierReplies: history.filter { $0.role == .sol }.dropFirst().map(\.text))
        let words = text.split(whereSeparator: \.isWhitespace).count
        gate = SolTurnGate(check: check, budgets: kind.budgets(forWords: words), writerSaid: writerMessages.joined(separator: " "))
        await keepWithinContext(history, writerMessages: writerMessages)
        let prompt = SolTurnPlanner.onDevicePrompt(kind: kind, text: text, askedQuestions: askedQuestions, usedThemes: usedThemes,
                                                   steerTowardReflection: steer, memory: memory, notes: notes)

        timedOut = false
        let watchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.turnLimit)
            guard !Task.isCancelled, let self else { return }
            self.timedOut = true
            self.generation?.cancel()
        }
        defer { watchdog.cancel() }

        var note: String?
        latest = nil
        let started = ContinuousClock.now
        var trace: [String] = []
        for attempt in 1...2 {
            if session == nil || attempt > 1 { session = makeSession(earlier: history) }
            let session = self.session!
            let attemptPrompt = note.map { prompt + "\nNote: " + $0 } ?? prompt
            generation = Task { @MainActor in try await self.draft(kind, prompt: attemptPrompt, in: session, show: show) }
            do {
                _ = try await generation?.value
                trace.append("attempt \(attempt) ok \(ContinuousClock.now - started)")
            } catch let error as LanguageModelSession.GenerationError {
                trace.append("attempt \(attempt) error \(error)")
                switch error {
                case .guardrailViolation, .refusal: throw SolEngineError.guardrail
                case .rateLimited, .concurrentRequests, .exceededContextWindowSize:
                    if gate?.shown.isEmpty == true && !timedOut {
                        try? await Task.sleep(for: .milliseconds(600))
                        continue
                    }
                default: break
                }
            } catch {
                // Timed out or cancelled: answer with what passed the checks so far.
                trace.append("attempt \(attempt) stopped: \(error) timedOut=\(timedOut)")
            }
            guard let gate, gate.shown.isEmpty, !timedOut, attempt == 1 else { break }
            // Nothing usable yet: one fresh try with a note about what went wrong.
            note = SolTurnPlanner.retryNote(for: gate.dropped)
            self.gate = SolTurnGate(check: check, budgets: kind.budgets(forWords: words), writerSaid: writerMessages.joined(separator: " "))
        }
        generation = nil
        let last = latest
        if Self.debug { print("SOLTRACE kind=\(kind) dropped=\(gate?.dropped ?? []) chips=\(last?.suggestions ?? []) q=\(last?.question ?? "nil") | \(trace.joined(separator: " | "))") }

        guard let gate, !gate.shown.isEmpty else {
            let fallback = SolTurnPlanner.fallbackTurn(asked: askedQuestions)
            askedQuestions.append(fallback.reply)
            return fallback
        }
        let question = gate.question(from: last?.question, asked: askedQuestions)
        askedQuestions.append(question)
        if let theme = last?.theme, !theme.isEmpty { usedThemes.append(theme) }
        let reply = gate.shown.joined(separator: " ") + " " + question
        let citations = last?.usedMemory == true && !hits.isEmpty ? SolTurnPlanner.citations(for: reply, hits: hits) : []
        return SolTurn(reply: reply, suggestions: SolTurnGate.quickReplies(last?.suggestions, question: question), citations: citations)
    }

    /// Streams one draft of the turn through the gate; returns the last snapshot.
    private func draft(_ kind: SolTurnKind, prompt: String, in session: LanguageModelSession,
                       show: @escaping (String) -> Void) async throws -> SolDraftSnapshot? {
        switch kind {
        case .smallTalk:
            return try await stream(SolGreetingContent.self, prompt: prompt, in: session, show: show) { c in
                SolDraftSnapshot(parts: [c.reply], completeParts: c.suggestions != nil ? 1 : 0, suggestions: c.suggestions)
            }
        case .answer:
            return try await stream(SolAnswerContent.self, prompt: prompt, in: session, show: show) { c in
                SolDraftSnapshot(parts: [c.answer], completeParts: c.usedMemory != nil || c.question != nil ? 1 : 0,
                                 question: c.question, suggestions: c.suggestions, usedMemory: c.usedMemory)
            }
        case .celebrate:
            return try await stream(SolCelebrateContent.self, prompt: prompt, in: session, show: show) { c in
                SolDraftSnapshot(parts: [c.delight], completeParts: c.question != nil ? 1 : 0, question: c.question, suggestions: c.suggestions)
            }
        case .listen:
            return try await stream(SolListenContent.self, prompt: prompt, in: session, show: show) { c in
                SolDraftSnapshot(parts: [c.reflection], completeParts: c.question != nil ? 1 : 0, question: c.question, suggestions: c.suggestions)
            }
        case .reflect:
            return try await stream(SolTurnContent.self, prompt: prompt, in: session, show: show) { c in
                let done = (c.usedMemory != nil || c.question != nil) ? 2 : (c.theme != nil ? 1 : 0)
                return SolDraftSnapshot(parts: [c.reflection, c.perspective], completeParts: done, question: c.question,
                                        suggestions: c.suggestions, usedMemory: c.usedMemory, theme: c.theme)
            }
        }
    }

    private func stream<T: Generable>(_ type: T.Type, prompt: String, in session: LanguageModelSession, show: @escaping (String) -> Void,
                                      map: (T.PartiallyGenerated) -> SolDraftSnapshot) async throws -> SolDraftSnapshot? {
        for try await snapshot in session.streamResponse(to: prompt, generating: T.self, options: Self.options) {
            let s = map(snapshot.content)
            latest = s
            if let text = gate?.feed(s) { show(text) }
        }
        guard let finished = latest?.finished else { return nil }
        latest = finished
        if let text = gate?.feed(finished) { show(text) }
        return finished
    }

    /// Before the 4,096-token window fills up, notes what the writer said so far (people, events) and starts a
    /// condensed session from the persona, the notes and the last few messages. Notes are taken here, not after every
    /// turn, so they never compete with a reply for the model.
    private func keepWithinContext(_ history: [SolMessage], writerMessages: [String]) async {
        guard let session, history.count > 6 else { return }
        var full = false
        if #available(iOS 26.4, macOS 26.4, *) {
            if let used = try? await SystemLanguageModel.default.tokenCount(for: session.transcript) { full = used > 2_800 }
        }
        guard full else { return }
        await updateNotes(from: writerMessages)
        self.session = makeSession(earlier: history)
    }

    /// Keeps a few grounded notes (people, events) from the writer's own words.
    private func updateNotes(from writerMessages: [String]) async {
        let session = LanguageModelSession(instructions: "You keep short notes about what a journal writer told you. Use only their own words; never add feelings or guesses.")
        guard let response = try? await session.respond(to: "The writer said:\n" + writerMessages.map { "- \($0)" }.joined(separator: "\n"),
                                                        generating: ConversationNotesContent.self,
                                                        options: GenerationOptions(temperature: 0.2)) else { return }
        notes = SolTurnPlanner.groundedNotes(response.content.people + response.content.events, in: writerMessages)
    }

    public func draftReflection(from userMessages: [String]) async throws -> String {
        // The writer's own words, transformed: permissive guardrails avoid false alarms on hard days.
        let session = LanguageModelSession(model: SystemLanguageModel(guardrails: .permissiveContentTransformations),
                                           instructions: Self.reflectionInstructions)
        let numbered = userMessages.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let work = Task { @MainActor in
            try await session.respond(to: "The writer said:\n\(numbered)", options: GenerationOptions(temperature: 0.4)).content
        }
        let watchdog = Task { @MainActor in
            try? await Task.sleep(for: Self.reflectionLimit)
            if !Task.isCancelled { work.cancel() }
        }
        defer { watchdog.cancel() }
        let raw: String
        do {
            raw = try await work.value
        } catch {
            throw Self.map(error)
        }
        guard let text = SolTurnPlanner.cleanReflection(raw, writerMessages: userMessages) else { throw SolEngineError.failed }
        return text + "\n\n" + ReflectionTemplate.closingPrompt
    }

    static func map(_ error: any Error) -> SolEngineError {
        if let e = error as? SolEngineError { return e }
        if let g = error as? LanguageModelSession.GenerationError {
            switch g {
            case .guardrailViolation, .refusal: return .guardrail
            default: return .failed
            }
        }
        return .failed
    }
}

import Foundation
import FoundationModels

/// One Sol turn in three parts, so a small on-device model keeps the shape of a wise, warm reply:
/// mirror the writer, offer one fresh perspective, ask one new question.
@Generable
struct SolTurnContent {
    @Guide(description: "1 or 2 warm sentences reflecting the writer's own words back to them, specifically. Don't start with 'That sounds' or 'I'm sorry'.")
    var reflection: String
    @Guide(description: "The theme for your perspective this turn; choose one that fits what the writer said and that you haven't used", .anyOf(SolCharacter.themes))
    var theme: String
    @Guide(description: "1 or 2 sentences of gentle perspective on the chosen theme, the way a wise old teacher would say it, tied to what the writer said. Plain words, not generic advice; never start with 'Remember'.")
    var perspective: String
    @Guide(description: "One open, caring question that moves the conversation forward and is different from every question already asked")
    var question: String
    @Guide(description: "Two short answers the writer (not Sol) could tap to answer your question, written as the writer, 2 to 6 words each. Never questions, never advice.", .count(2))
    var suggestions: [String]
}

@Generable
struct SolGreetingContent {
    @Guide(description: "A warm greeting of one or two sentences in Sol's voice that ends by asking what's on the writer's heart")
    var reply: String
    @Guide(description: "Two short things the writer (not Sol) might answer, 2 to 6 words each, e.g. \"Work, mostly\"", .count(2))
    var suggestions: [String]
}

@Generable
struct ReflectionContent {
    @Guide(description: "A short first-person reflection, two or three short paragraphs, using only what the writer said")
    var text: String
}

/// Sol on Apple's on-device model, one session per conversation (spec §5.3).
@MainActor
public final class FoundationModelSol: SolEngine {
    static var persona: String { SolCharacter.persona }

    static let reflectionInstructions = """
    Turn the writer's own messages into a short private journal reflection written in the first \
    person ("I"). Use only what the writer said; add no new facts, advice or diagnosis. \
    Plain, warm language. Do not address the reader.
    """

    private var session: LanguageModelSession?
    private var askedQuestions: [String] = []
    private var usedThemes: [String] = []
    private let journal: JournalIndex?
    private var remembered: [JournalHit] = []

    /// - Parameter journal: when given, Sol brings in a closely related moment from the writer's entries
    ///   ("Sol remembers"). Retrieval is done by the app, on device, so it doesn't depend on the model calling a tool.
    public init(journal: JournalIndex? = nil) {
        self.journal = journal
    }

    /// The session starts from the visible conversation, so the model knows what Sol already said
    /// (including its opening question) instead of meeting the writer's "hi" with no context.
    private func makeSession(earlier: [SolMessage]) -> LanguageModelSession {
        var instructions = Self.persona
        let recent = earlier.suffix(6).filter { $0.role != .support }
        if !recent.isEmpty {
            instructions += "\n\nThe conversation so far:\n" + recent.map { "\($0.role == .me ? "The writer said" : "You (Sol) said"): \($0.text)" }.joined(separator: "\n")
        }
        return LanguageModelSession(instructions: instructions)
    }

    public func prewarm() {
        let s = session ?? makeSession(earlier: [])
        s.prewarm()
    }

    public func reset() {
        session = nil
        askedQuestions = []
        usedThemes = []
    }

    public func reply(to text: String, history: [SolMessage], steerTowardReflection: Bool) -> AsyncThrowingStream<SolTurn, any Error> {
        if askedQuestions.isEmpty, let opening = history.first(where: { $0.role == .sol })?.text { askedQuestions = [opening] }
        let asked = askedQuestions, themes = usedThemes
        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                var memory: String?
                self.remembered = []
                if let journal = self.journal, !SolTurnPlanner.isSmallTalk(text) {
                    let hits = await journal.search(text, limit: 1, minimumScore: JournalIndex.strongMatch)
                    let alreadyCited = Set(history.flatMap(\.citations).map(\.entryID))
                    self.remembered = hits.filter { !alreadyCited.contains($0.snippet.entryID) }
                    if !self.remembered.isEmpty { memory = SearchJournalTool.describe(self.remembered, calendar: .current) }
                }
                let prompt = SolTurnPlanner.prompt(for: text, askedQuestions: asked, usedThemes: themes,
                                                   steerTowardReflection: steerTowardReflection, memory: memory)
                do {
                    if self.session == nil { self.session = self.makeSession(earlier: history) }
                    try await self.stream(prompt, into: continuation)
                    continuation.finish()
                } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
                    self.session = self.makeSession(earlier: history)
                    do {
                        try await self.stream(prompt, into: continuation)
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: Self.map(error))
                    }
                } catch {
                    continuation.finish(throwing: Self.map(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func stream(_ prompt: String, into continuation: AsyncThrowingStream<SolTurn, any Error>.Continuation) async throws {
        let session = self.session ?? makeSession(earlier: [])
        self.session = session
        if prompt.contains(SolTurnPlanner.smallTalkMarker) {
            for try await snapshot in session.streamResponse(to: prompt, generating: SolGreetingContent.self,
                                                             options: GenerationOptions(temperature: 0.7)) {
                continuation.yield(SolTurn(reply: snapshot.content.reply ?? "", suggestions: snapshot.content.suggestions ?? []))
            }
            return
        }
        var last: SolTurnContent.PartiallyGenerated?
        for try await snapshot in session.streamResponse(to: prompt, generating: SolTurnContent.self,
                                                         options: GenerationOptions(temperature: 0.7)) {
            let c = snapshot.content
            last = c
            continuation.yield(SolTurn(reply: SolTurnPlanner.compose(reflection: c.reflection, perspective: c.perspective, question: c.question),
                                       suggestions: c.suggestions ?? []))
        }
        if var question = last?.question?.trimmingCharacters(in: .whitespacesAndNewlines), !question.isEmpty {
            if let fresh = SolTurnPlanner.freshQuestion(question, asked: askedQuestions) {
                question = fresh
                continuation.yield(SolTurn(reply: SolTurnPlanner.compose(reflection: last?.reflection, perspective: last?.perspective, question: fresh),
                                           suggestions: last?.suggestions ?? []))
            }
            askedQuestions.append(question)
        }
        if let theme = last?.theme, !theme.isEmpty { usedThemes.append(theme) }
        let hits = remembered
        if let last, !hits.isEmpty {
            let reply = SolTurnPlanner.compose(reflection: last.reflection, perspective: last.perspective, question: askedQuestions.last)
            let cites = SolTurnPlanner.citations(for: reply, hits: hits)
            if !cites.isEmpty {
                continuation.yield(SolTurn(reply: reply, suggestions: last.suggestions ?? [], citations: cites))
            }
        }
    }

    public func draftReflection(from userMessages: [String]) async throws -> String {
        let session = LanguageModelSession(instructions: Self.reflectionInstructions)
        let numbered = userMessages.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        do {
            let response = try await session.respond(to: "The writer said:\n\(numbered)", generating: ReflectionContent.self)
            let text = response.content.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw SolEngineError.failed }
            return text + "\n\n" + ReflectionTemplate.closingPrompt
        } catch {
            throw Self.map(error)
        }
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

import Foundation
import FoundationModels

@Generable
struct SolTurnContent {
    @Guide(description: "Sol's reply: warm, at most two short sentences, reflecting the writer's words and ending with one open question")
    var reply: String
    @Guide(description: "Two short first-person replies the writer might tap next, each under seven words", .count(2))
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
    static let persona = """
    You are Sol, a gentle reflection companion inside Memento, a private journal that runs \
    entirely on this iPhone. Help the writer think things through.
    - Reply in at most two short sentences.
    - Reflect the writer's own words back, then ask one open question.
    - Never diagnose, never name conditions, never give medical, legal or financial advice, \
    and never claim to be a therapist.
    - Do not encourage the writer to rely on you; when it fits, point them toward people they trust.
    - Do not invent facts about the writer's life.
    - Suggestions are two short first-person replies the writer could tap.
    """

    static let reflectionInstructions = """
    Turn the writer's own messages into a short private journal reflection written in the first \
    person ("I"). Use only what the writer said; add no new facts, advice or diagnosis. \
    Plain, warm language. Do not address the reader.
    """

    private var session: LanguageModelSession?

    public init() {}

    private func makeSession(earlier: [SolMessage] = []) -> LanguageModelSession {
        var instructions = Self.persona
        let recent = earlier.suffix(4).filter { $0.role != .support }
        if !recent.isEmpty {
            instructions += "\n\nEarlier in this conversation:\n" + recent.map { "\($0.role == .me ? "Writer" : "Sol"): \($0.text)" }.joined(separator: "\n")
        }
        return LanguageModelSession(instructions: instructions)
    }

    public func prewarm() {
        let s = session ?? makeSession()
        session = s
        s.prewarm()
    }

    public func reset() { session = nil }

    public func reply(to text: String, history: [SolMessage], steerTowardReflection: Bool) -> AsyncThrowingStream<SolTurn, any Error> {
        let prompt = steerTowardReflection
            ? text + "\n\n(Gently offer to turn this conversation into a written reflection the writer can keep.)"
            : text
        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
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
        let session = self.session ?? makeSession()
        self.session = session
        for try await snapshot in session.streamResponse(to: prompt, generating: SolTurnContent.self) {
            continuation.yield(SolTurn(reply: snapshot.content.reply ?? "", suggestions: snapshot.content.suggestions ?? []))
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

import Foundation

/// Sol through OpenRouter, for iPhones without Apple's on-device model. Same character, planner,
/// on-device journal memory and crisis handling (in `SolConversation`) as the on-device Sol;
/// turns stream in as strict JSON and are composed the same way.
@MainActor
public final class CloudSol: SolEngine {
    private let client: OpenRouterClient
    private let model: String
    private let journal: JournalIndex?
    private var askedQuestions: [String] = []
    private var usedThemes: [String] = []

    public init(client: OpenRouterClient, model: String, journal: JournalIndex? = nil) {
        self.client = client
        self.model = model
        self.journal = journal
    }

    static var turnSchema: String {
        JSONText.schema([
            "type": "object", "additionalProperties": false,
            "required": ["reflection", "theme", "perspective", "question", "suggestions"],
            "properties": [
                "reflection": ["type": "string", "description": "1 or 2 warm sentences reflecting the writer's own words back to them, specifically."],
                "theme": ["type": "string", "enum": SolCharacter.themes, "description": "The theme for your perspective; one you haven't used."],
                "perspective": ["type": "string", "description": "1 or 2 sentences of gentle perspective on the theme, tied to what the writer said, the way a wise old teacher would say it."],
                "question": ["type": "string", "description": "One open, caring question, different from every question already asked."],
                "suggestions": ["type": "array", "items": ["type": "string"],
                                "description": "Exactly two short answers the writer could tap to answer your question, written as the writer, 2 to 6 words each. Never questions."],
            ],
        ])
    }

    static var greetingSchema: String {
        JSONText.schema([
            "type": "object", "additionalProperties": false, "required": ["reply", "suggestions"],
            "properties": [
                "reply": ["type": "string", "description": "A warm greeting of one or two sentences that ends by asking what's on the writer's heart."],
                "suggestions": ["type": "array", "items": ["type": "string"],
                                "description": "Exactly two short things the writer might answer, 2 to 6 words each."],
            ],
        ])
    }

    static var reflectionSchema: String {
        JSONText.schema([
            "type": "object", "additionalProperties": false, "required": ["text"],
            "properties": ["text": ["type": "string", "description": "Two or three short first-person paragraphs."]],
        ])
    }

    private struct Turn: Decodable { var reflection: String; var theme: String; var perspective: String; var question: String; var suggestions: [String] }
    private struct Greeting: Decodable { var reply: String; var suggestions: [String] }
    private struct Reflection: Decodable { var text: String }

    public func prewarm() {}

    public func reset() {
        askedQuestions = []
        usedThemes = []
    }

    public func reply(to text: String, history: [SolMessage], steerTowardReflection: Bool) -> AsyncThrowingStream<SolTurn, any Error> {
        if askedQuestions.isEmpty, let opening = history.first(where: { $0.role == .sol })?.text { askedQuestions = [opening] }
        let asked = askedQuestions, themes = usedThemes
        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                let (memory, remembered) = await SolTurnPlanner.recall(text, history: history, journal: self.journal)
                let prompt = SolTurnPlanner.prompt(for: text, askedQuestions: asked, usedThemes: themes,
                                                   steerTowardReflection: steerTowardReflection, memory: memory)
                let messages = [CloudMessage(.system, Self.instructions(earlier: history)), CloudMessage(.user, prompt)]
                do {
                    if prompt.contains(SolTurnPlanner.smallTalkMarker) {
                        try await self.greet(messages, into: continuation)
                    } else {
                        try await self.turn(messages, remembered: remembered, into: continuation)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: SolEngineError.failed)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// The persona plus what's on screen, so "hi" after Sol's opening question gets a real answer.
    static func instructions(earlier: [SolMessage]) -> String {
        var instructions = SolCharacter.cloudPersona
        let recent = earlier.suffix(8).filter { $0.role != .support }
        if !recent.isEmpty {
            instructions += "\n\nThe conversation so far:\n" + recent.map { "\($0.role == .me ? "The writer said" : "You (Sol) said"): \($0.text)" }.joined(separator: "\n")
        }
        return instructions
    }

    private func turn(_ messages: [CloudMessage], remembered: [JournalHit],
                      into continuation: AsyncThrowingStream<SolTurn, any Error>.Continuation) async throws {
        var raw = ""
        for try await json in client.streamJSON(model: model, messages: messages, schemaName: "sol_turn", schema: Self.turnSchema,
                                                temperature: 0.7, maxTokens: 700) {
            raw = json
            let reply = SolTurnPlanner.compose(reflection: PartialJSON.string("reflection", in: json),
                                               perspective: PartialJSON.string("perspective", in: json),
                                               question: PartialJSON.string("question", in: json))
            if !reply.isEmpty { continuation.yield(SolTurn(reply: reply, suggestions: [])) }
        }
        guard let final = try? JSONText.decode(Turn.self, from: raw) else { throw CloudAIError.badResponse }
        var question = final.question.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fresh = SolTurnPlanner.freshQuestion(question, asked: askedQuestions) { question = fresh }
        if !question.isEmpty { askedQuestions.append(question) }
        if !final.theme.isEmpty { usedThemes.append(final.theme) }
        let reply = SolTurnPlanner.compose(reflection: final.reflection, perspective: final.perspective, question: question)
        let citations = remembered.isEmpty ? [] : SolTurnPlanner.citations(for: reply, hits: remembered)
        continuation.yield(SolTurn(reply: reply, suggestions: Self.clean(final.suggestions), citations: citations))
    }

    private func greet(_ messages: [CloudMessage], into continuation: AsyncThrowingStream<SolTurn, any Error>.Continuation) async throws {
        var raw = ""
        for try await json in client.streamJSON(model: model, messages: messages, schemaName: "sol_greeting", schema: Self.greetingSchema,
                                                temperature: 0.7, maxTokens: 300) {
            raw = json
            if let reply = PartialJSON.string("reply", in: json), !reply.isEmpty { continuation.yield(SolTurn(reply: reply, suggestions: [])) }
        }
        guard let final = try? JSONText.decode(Greeting.self, from: raw) else { throw CloudAIError.badResponse }
        continuation.yield(SolTurn(reply: final.reply.trimmingCharacters(in: .whitespacesAndNewlines), suggestions: Self.clean(final.suggestions)))
    }

    /// Two short quick replies, written as the writer; anything that reads like a question is dropped.
    static func clean(_ suggestions: [String]) -> [String] {
        Array(suggestions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasSuffix("?") && $0.count <= 40 }
            .prefix(2))
    }

    public func draftReflection(from userMessages: [String]) async throws -> String {
        let numbered = userMessages.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        do {
            let raw = try await client.json(model: model,
                                            messages: [CloudMessage(.system, FoundationModelSol.reflectionInstructions),
                                                       CloudMessage(.user, "The writer said:\n\(numbered)")],
                                            schemaName: "reflection", schema: Self.reflectionSchema, temperature: 0.4, maxTokens: 700)
            let text = try JSONText.decode(Reflection.self, from: raw).text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw SolEngineError.failed }
            return text + "\n\n" + ReflectionTemplate.closingPrompt
        } catch {
            throw SolEngineError.failed
        }
    }
}

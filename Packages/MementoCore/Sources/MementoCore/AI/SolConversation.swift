import Foundation
import Observation

/// One Sol chat: never persisted (spec §5.3), soft-capped at 12 writer turns (D22).
@MainActor
@Observable
public final class SolConversation {
    public static let opening = "Hi. What’s taking up the most room in your head tonight?"
    public static let openingSuggestions = ["Work, mostly", "Something someone said", "Honestly, I’m not sure"]
    public static let fallbackReply = "I lost my train of thought for a second. Could you say that another way?"
    public static let softCap = 12
    public static let steerFrom = 8

    public private(set) var messages: [SolMessage] = []
    public private(set) var suggestions: [String] = []
    public private(set) var isResponding = false
    public private(set) var isAwaitingFirstToken = false
    public var input = ""
    @ObservationIgnored private let engine: any SolEngine

    public init(engine: any SolEngine) {
        self.engine = engine
        reset()
    }

    public var userTurns: Int { messages.filter { $0.role == .me }.count }
    public var userMessages: [String] { messages.filter { $0.role == .me }.map(\.text) }
    public var reachedCap: Bool { userTurns >= Self.softCap }
    public var canSend: Bool { !isResponding && !reachedCap }
    public var canMakeReflection: Bool { userTurns >= 1 && !isResponding }

    public func reset() {
        messages = [SolMessage(role: .sol, text: Self.opening)]
        suggestions = Self.openingSuggestions
        input = ""
        engine.reset()
    }

    public func prewarm() { engine.prewarm() }

    public func send(_ override: String? = nil) async {
        let text = (override ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, canSend else { return }
        input = ""
        suggestions = []
        let history = messages
        messages.append(SolMessage(role: .me, text: text))
        if CrisisSignal.matches(text) {
            messages.append(SolMessage(role: .support, text: CrisisSignal.supportMessage))
            return
        }
        isResponding = true
        isAwaitingFirstToken = true
        defer {
            isResponding = false
            isAwaitingFirstToken = false
        }
        var replyID: UUID?
        var finalSuggestions: [String] = []
        do {
            let stream = engine.reply(to: text, history: history, steerTowardReflection: userTurns >= Self.steerFrom)
            for try await turn in stream where !turn.reply.isEmpty {
                isAwaitingFirstToken = false
                if let id = replyID, let i = messages.firstIndex(where: { $0.id == id }) {
                    messages[i].text = turn.reply
                } else {
                    let m = SolMessage(role: .sol, text: turn.reply)
                    replyID = m.id
                    messages.append(m)
                }
                finalSuggestions = turn.suggestions
            }
            if replyID == nil { messages.append(SolMessage(role: .sol, text: Self.fallbackReply)) }
        } catch SolEngineError.guardrail {
            removeMessage(replyID)
            messages.append(SolMessage(role: .support, text: CrisisSignal.supportMessage))
        } catch {
            removeMessage(replyID)
            messages.append(SolMessage(role: .sol, text: Self.fallbackReply))
        }
        suggestions = reachedCap ? [] : finalSuggestions
    }

    private func removeMessage(_ id: UUID?) {
        guard let id else { return }
        messages.removeAll { $0.id == id }
    }
}

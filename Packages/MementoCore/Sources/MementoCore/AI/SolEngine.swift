import Foundation

public struct SolMessage: Identifiable, Hashable, Sendable {
    public enum Role: String, Sendable { case sol, me, support }
    public let id: UUID
    public let role: Role
    public var text: String
    /// Past journal moments this reply drew on.
    public var citations: [SolCitation]

    public init(id: UUID = UUID(), role: Role, text: String, citations: [SolCitation] = []) {
        self.id = id
        self.role = role
        self.text = text
        self.citations = citations
    }
}

public struct SolTurn: Equatable, Sendable {
    public var reply: String
    public var suggestions: [String]
    public var citations: [SolCitation]
    /// Sol's safe composed reply stood in because the model couldn't give a good one in time.
    public var usedFallback: Bool

    public init(reply: String, suggestions: [String], citations: [SolCitation] = [], usedFallback: Bool = false) {
        self.reply = reply
        self.suggestions = suggestions
        self.citations = citations
        self.usedFallback = usedFallback
    }
}

public enum SolEngineError: Error, Equatable {
    case guardrail, failed
}

@MainActor
public protocol SolEngine: AnyObject {
    func prewarm()
    func reset()
    /// Streams growing snapshots of Sol's reply; suggestions are complete on the last element.
    func reply(to text: String, history: [SolMessage], steerTowardReflection: Bool) -> AsyncThrowingStream<SolTurn, any Error>
    func draftReflection(from userMessages: [String]) async throws -> String
}

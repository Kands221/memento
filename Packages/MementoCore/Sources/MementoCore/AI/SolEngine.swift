import Foundation

public struct SolMessage: Identifiable, Hashable, Sendable {
    public enum Role: String, Sendable { case sol, me, support }
    public let id: UUID
    public let role: Role
    public var text: String

    public init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}

public struct SolTurn: Equatable, Sendable {
    public var reply: String
    public var suggestions: [String]

    public init(reply: String, suggestions: [String]) {
        self.reply = reply
        self.suggestions = suggestions
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

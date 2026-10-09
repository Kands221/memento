import Foundation

/// Deterministic Sol for UI tests and the demo backup; replies are the prototype's.
@MainActor
public final class ScriptedSol: SolEngine {
    public static let replies = [
        "Deadlines have a way of shouting louder than everything else, don’t they? But they come and go, and you’re still here, carrying all of it. If you picture saying no to just one thing this week, what comes up first?",
        "Ah, the fear of letting people down. It usually means you care a great deal about them, and that’s a good thing, not a flaw. But caring for others works best when you leave a little room to care for yourself too. Would you like to turn this into a reflection you can keep?",
    ]
    public static let followUps: [[String]] = [["That I'll let Dana down", "Relief, honestly"], []]
    public static let closing = "Would you like to turn this into a reflection you can keep?"

    private var step = 0
    private let thinkDelay: Duration
    private let wordDelay: Duration

    public init(thinkDelay: Duration = .milliseconds(700), wordDelay: Duration = .milliseconds(25)) {
        self.thinkDelay = thinkDelay
        self.wordDelay = wordDelay
    }

    public func prewarm() {}
    public func reset() { step = 0 }

    public func reply(to text: String, history: [SolMessage], steerTowardReflection: Bool) -> AsyncThrowingStream<SolTurn, any Error> {
        let index = step
        step += 1
        let full = index < Self.replies.count ? Self.replies[index] : Self.closing
        let chips = index < Self.followUps.count ? Self.followUps[index] : []
        let think = thinkDelay, word = wordDelay
        return AsyncThrowingStream { continuation in
            let task = Task {
                if think > .zero { try? await Task.sleep(for: think) }
                let words = full.split(separator: " ")
                var built = ""
                for (i, w) in words.enumerated() {
                    built += (i == 0 ? "" : " ") + w
                    continuation.yield(SolTurn(reply: built, suggestions: i == words.count - 1 ? chips : []))
                    if word > .zero { try? await Task.sleep(for: word) }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func draftReflection(from userMessages: [String]) async throws -> String {
        ReflectionTemplate.make(userMessages: userMessages)
    }
}

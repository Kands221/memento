import Testing
import Foundation
@testable import MementoCore

/// Regression for "Sol doesn't reply properly to hi" (live model): greet back, ask, no invented history.
@MainActor
@Suite(.enabled(if: AIAvailability.live() == .ready))
struct SolGreetingTests {
    @Test func greetsBackWithoutInventingHistory() async {
        for text in ["hi", "Hello"] {
            let c = SolConversation(engine: FoundationModelSol())
            await c.send(text)
            let reply = c.messages.last?.text.lowercased() ?? ""
            print("SOL [\(text)] →", reply)
            #expect(c.messages.last?.role == .sol)
            #expect(reply.contains("?"))
            for banned in ["missed you", "again", "sorry to hear", "long day"] { #expect(!reply.contains(banned), "\(banned)") }
        }
    }

    @Test func followsUpOnTheSecondTurn() async {
        let c = SolConversation(engine: FoundationModelSol())
        await c.send("hi")
        await c.send("Work has been chaotic, my manager keeps moving deadlines")
        print("SOL turn2 →", c.messages.last?.text ?? "", "| chips:", c.suggestions)
        #expect(c.messages.last?.role == .sol)
        #expect(c.messages.last?.text != SolConversation.fallbackReply)
    }
}

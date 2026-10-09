import Testing
import Foundation
@testable import MementoCore

@MainActor
final class ThrowingSol: SolEngine {
    let error: any Error
    init(_ error: any Error) { self.error = error }
    func prewarm() {}
    func reset() {}
    func reply(to text: String, history: [SolMessage], steerTowardReflection: Bool) -> AsyncThrowingStream<SolTurn, any Error> {
        let error = self.error
        return AsyncThrowingStream { c in
            c.yield(SolTurn(reply: "Half a", suggestions: []))
            c.finish(throwing: error)
        }
    }
    func draftReflection(from userMessages: [String]) async throws -> String { throw SolEngineError.failed }
}

@MainActor
@Suite struct SolTests {
    func scripted() -> SolConversation { SolConversation(engine: ScriptedSol(thinkDelay: .zero, wordDelay: .zero)) }

    @Test func opensWithStaticGreeting() {
        let c = scripted()
        #expect(c.messages.map(\.role) == [.sol])
        #expect(c.messages[0].text == SolConversation.opening)
        #expect(c.suggestions == SolConversation.openingSuggestions)
        #expect(!c.canMakeReflection)
    }

    @Test func sendStreamsReplyAndReturnsToIdle() async {
        let c = scripted()
        c.input = "The launch date at work"
        await c.send()
        #expect(c.messages.map(\.role) == [.sol, .me, .sol])
        #expect(c.messages[2].text == ScriptedSol.replies[0])
        #expect(!c.isResponding && !c.isAwaitingFirstToken)
        #expect(c.input.isEmpty)
        #expect(c.canSend && c.canMakeReflection)
        #expect(c.suggestions == ScriptedSol.followUps[0])
    }

    @Test func sendWhileRespondingIsIgnored() async {
        let c = SolConversation(engine: ScriptedSol(thinkDelay: .milliseconds(200), wordDelay: .zero))
        async let first: Void = c.send("One")
        try? await Task.sleep(for: .milliseconds(20))
        #expect(c.isResponding)
        await c.send("Two")
        await first
        #expect(c.userMessages == ["One"])
    }

    @Test func streamFailureFallsBackAndReturnsToIdle() async {
        let c = SolConversation(engine: ThrowingSol(SolEngineError.failed))
        await c.send("Hello")
        #expect(c.messages.last?.text == SolConversation.fallbackReply)
        #expect(c.messages.filter { $0.role == .sol }.count == 2)
        #expect(!c.isResponding && c.canSend)
    }

    @Test func guardrailShowsSupportCard() async {
        let c = SolConversation(engine: ThrowingSol(SolEngineError.guardrail))
        await c.send("Hello")
        #expect(c.messages.last?.role == .support)
    }

    @Test func crisisWordsSkipTheModel() async {
        let c = scripted()
        await c.send("Some nights I want to die")
        #expect(c.messages.map(\.role) == [.sol, .me, .support])
        #expect(CrisisSignal.matches("thinking about suicide"))
        #expect(CrisisSignal.matches("I want to end it all"))
        #expect(!CrisisSignal.matches("the end of my day was nice"))
        #expect(!CrisisSignal.matches("this deadline is killing me"))
    }

    @Test func softCapStopsInput() async {
        let c = scripted()
        for i in 0..<SolConversation.softCap { await c.send("Message \(i)") }
        #expect(c.reachedCap && !c.canSend)
        await c.send("One more")
        #expect(c.userTurns == SolConversation.softCap)
        #expect(c.suggestions.isEmpty)
    }

    @Test func reflectionTemplateUsesOnlyUserWords() {
        let t = ReflectionTemplate.make(userMessages: ["The launch date at work.", "That I'll let Dana down"])
        #expect(t == "Tonight I talked through the launch date at work.\n\nWhat came up after that: that I'll let Dana down.\n\nOne thing I'd like to try this week: ")
        #expect(ReflectionTemplate.make(userMessages: []).hasPrefix("Tonight I talked through my day."))
    }

    @Test func resetRestoresOpening() async {
        let c = scripted()
        await c.send("Hi")
        c.reset()
        #expect(c.messages.count == 1 && c.userTurns == 0)
    }
}

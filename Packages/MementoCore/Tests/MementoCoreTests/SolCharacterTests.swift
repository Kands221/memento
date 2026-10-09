import Testing
import Foundation
@testable import MementoCore

@MainActor
@Suite struct SolCharacterTests {
    func at(_ hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Fixtures.today)!
    }

    @Test func openingChangesWithTimeOfDay() {
        #expect(SolCharacter.opening(at: at(8)).hasPrefix("Morning."))
        #expect(SolCharacter.opening(at: at(14)).contains("this afternoon"))
        #expect(SolCharacter.opening(at: at(21)).contains("tonight"))
        #expect(SolCharacter.opening(at: at(1)).hasPrefix("Still up?"))
        #expect(SolCharacter.openingSuggestions(at: at(21)).count == 3)
    }

    @Test func personaCarriesVoiceRulesAndExamples() {
        let p = SolCharacter.persona
        #expect(p.contains("You are Sol"))
        #expect(p.contains("At most two short sentences"))
        #expect(p.contains("Never diagnose"))
        #expect(p.contains("Examples of your voice"))
        #expect(p.contains("point toward people they trust"))
    }

    @Test func conversationOpensInCharacter() {
        let c = SolConversation(engine: ScriptedSol(thinkDelay: .zero, wordDelay: .zero), now: at(21))
        #expect(c.messages.first?.text == SolCharacter.opening(at: at(21)))
        #expect(c.suggestions == SolCharacter.openingSuggestions(at: at(21)))
        #expect(c.mood == .hello)
    }

    @Test func moodFollowsTheConversation() async {
        let c = SolConversation(engine: ScriptedSol(thinkDelay: .milliseconds(150), wordDelay: .zero))
        c.input = "Work"
        #expect(c.mood == .listening)
        async let sent: Void = c.send()
        try? await Task.sleep(for: .milliseconds(40))
        #expect(c.mood == .thinking)
        await sent
        #expect(c.mood == .speaking)
        #expect(SolMood.thinking.asset == "sol-thinking")
    }

    @Test func restsAtTheCap() async {
        let c = SolConversation(engine: ScriptedSol(thinkDelay: .zero, wordDelay: .zero))
        for i in 0..<SolConversation.softCap { await c.send("Message \(i)") }
        #expect(c.mood == .resting)
        #expect(SolConversation.fallbackReply == SolCharacter.fallbackReply)
    }
}

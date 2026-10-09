import Testing
import Foundation
@testable import MementoCore

@MainActor
@Suite struct SolCharacterTests {
    func at(_ hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Fixtures.today)!
    }

    @Test func openingChangesWithTimeOfDay() {
        #expect(SolCharacter.opening(at: at(8)).hasPrefix("Good morning, friend."))
        #expect(SolCharacter.opening(at: at(14)).contains("this afternoon"))
        #expect(SolCharacter.opening(at: at(21)).contains("tonight"))
        #expect(SolCharacter.opening(at: at(1)).hasPrefix("Still up?"))
        #expect(SolCharacter.openingSuggestions(at: at(21)).count == 3)
    }

    @Test func personaCarriesVoiceRulesAndExamples() {
        let p = SolCharacter.persona
        #expect(p.contains("You are Sol"))
        #expect(p.contains("Write 3 to 5 sentences"))
        #expect(p.contains("an old soul"))
        #expect(p.contains("old tortoise"))
        #expect(p.contains("short for Solomon"))
        #expect(!p.lowercased().contains("sun"))
        #expect(!SolCharacter.fallbackReply.lowercased().contains("sun"))
        #expect(p.contains("Never quote books, films or real people"))
        #expect(p.contains("Don't bring up death, dying or illness unless the writer does"))
        #expect(p.contains("Never diagnose"))
        #expect(p.contains("point toward people they trust"))
        #expect(p.contains("no memory of earlier conversations"))
        #expect(p.contains("Respond only to what the writer actually wrote"))
        #expect(p.contains("If the writer just says hello"))
        #expect(!p.contains("Writer:"))   // examples must not read like a real transcript
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

@Suite struct SolTurnPlanningTests {
    @Test func promptCarriesMessageThemesAndAskedQuestions() {
        let p = SolTurnPlanner.prompt(for: "Work has been chaotic", askedQuestions: ["What's on your heart?"],
                                      usedThemes: ["busyness and what really matters"], steerTowardReflection: false)
        #expect(p.contains("The writer says: \"Work has been chaotic\""))
        #expect(p.contains("What's on your heart?"))
        #expect(p.contains("busyness and what really matters"))
        #expect(!p.contains("written reflection"))
    }

    @Test func steeringAsksToOfferAReflection() {
        let p = SolTurnPlanner.prompt(for: "ok", askedQuestions: [], usedThemes: [], steerTowardReflection: true)
        #expect(p.contains("written reflection"))
    }

    @Test func composesPartsIntoOneReply() {
        #expect(SolTurnPlanner.compose(reflection: " Busy weeks pile up. ", perspective: nil, question: "What would you let go of?")
                == "Busy weeks pile up. What would you let go of?")
        #expect(SolTurnPlanner.compose(reflection: nil, perspective: nil, question: nil) == "")
        #expect(SolCharacter.themes.count >= 6)
    }
}

@Suite struct SolSmallTalkTests {
    @Test func detectsGreetingsAndTinyReplies() {
        for t in ["hi", "Hello!", "hey there", "ok", "good evening", "yo"] { #expect(SolTurnPlanner.isSmallTalk(t), "\(t)") }
        for t in ["Work has been chaotic", "I'm tired of my manager", "not sure what to do about Dana"] { #expect(!SolTurnPlanner.isSmallTalk(t), "\(t)") }
    }

    @Test func softensRememberOpeners() {
        #expect(SolTurnPlanner.soften("Remember, you can't control everything.") == "You can't control everything.")
        #expect(SolTurnPlanner.soften("Remember that your pace is your own.") == "Your pace is your own.")
        #expect(SolTurnPlanner.soften("Remember to pause.") == "It can help to pause.")
        #expect(SolTurnPlanner.soften("Small things add up.") == "Small things add up.")
    }
}

@Suite struct AIResolutionTests {
    @Test func solIgnoresTheTaggingDemoEngine() {
        // Rules engine for tags, on-device Sol, model not ready: Sol must stay gated.
        #expect(AIResolution.tagging(live: .needsAppleIntelligence, override: .live, demoTagging: true) == .ready)
        #expect(AIResolution.sol(live: .needsAppleIntelligence, override: .live, demoSol: false) == .needsAppleIntelligence)
        #expect(AIResolution.sol(live: .unsupported, override: .live, demoSol: true) == .ready)
        #expect(AIResolution.sol(live: .ready, override: .unsupported, demoSol: true) == .unsupported)
        #expect(AIResolution.tagging(live: .ready, override: .failing, demoTagging: false) == .ready)
    }
}

@Suite struct SolQuestionDedupeTests {
    @Test func replacesARepeatedQuestionWithAnUnusedFollowUp() {
        let asked = ["What’s on your heart?", "How are you feeling about the deadline?"]
        let fresh = SolTurnPlanner.freshQuestion("how are you feeling about the deadline", asked: asked)
        #expect(fresh != nil)
        #expect(!asked.contains(fresh!))
        #expect(SolTurnPlanner.freshQuestion("What would you let go of?", asked: asked) == nil)
    }
}

import Foundation
import Testing
@testable import MementoCore

@Suite struct SolReplyCheckTests {
    let check = SolReplyCheck(writerMessages: ["Work has been chaotic this week", "My manager keeps moving the launch deadline"])

    @Test func flagsStockOpenersOnlyAtTheStart() {
        #expect(check.issues(in: "That sounds like a lot to carry.", isOpening: true) == [.bannedOpener])
        #expect(check.issues(in: "I'm sorry the deadline keeps moving.", isOpening: true) == [.bannedOpener])
        #expect(check.issues(in: "That sounds like a lot to carry.", isOpening: false).isEmpty)
        #expect(check.issues(in: "A moving deadline makes it hard to plan.", isOpening: true).isEmpty)
    }

    @Test func feelingsMustBeTheWriters() {
        #expect(check.issues(in: "You must be so exhausted by now.", isOpening: false) == [.assumedFeeling])
        #expect(check.issues(in: "I can tell you're stressed.", isOpening: false) == [.assumedFeeling])
        // General wisdom isn't about them, and reassurance isn't an assumption.
        #expect(check.issues(in: "Busy weeks can leave anyone tired.", isOpening: false).isEmpty)
        #expect(check.issues(in: "You're not alone in this.", isOpening: false).isEmpty)
        // Their own word, or one from the same family, is fine.
        let tired = SolReplyCheck(writerMessages: ["Honestly I'm exhausted"])
        #expect(tired.issues(in: "You sound worn out, and that makes sense.", isOpening: false).isEmpty)
        let loss = SolReplyCheck(writerMessages: ["Today is the anniversary of my dad's death"])
        #expect(loss.issues(in: "Your grief is a sign of how much you loved him.", isOpening: false).isEmpty)
    }

    @Test func clinicalWordsQuotesAndMemories() {
        #expect(check.issues(in: "This could be burnout, so watch for symptoms.", isOpening: false) == [.clinicalWord])
        #expect(check.issues(in: "As the saying goes, this too shall pass.", isOpening: false) == [.quotesSomeone])
        #expect(check.issues(in: "On Sep 13 you walked with Priya.", isOpening: false) == [.inventedMemory])
        #expect(check.issues(in: "In your journal you said walks help.", isOpening: false) == [.inventedMemory])
        let remembering = SolReplyCheck(writerMessages: ["Work stress is back"], memory: "a long walk with Priya", memoryDate: "Sep 13")
        #expect(remembering.issues(in: "On Sep 13 you walked with Priya and came home lighter.", isOpening: false).isEmpty)
        #expect(remembering.issues(in: "On September 13 you walked with Priya.", isOpening: false).isEmpty)
        #expect(remembering.issues(in: "On Oct 2 you felt the same.", isOpening: false) == [.inventedMemory])
    }

    @Test func solDoesNotSpeakAsTheWriter() {
        let sister = SolReplyCheck(writerMessages: ["Maybe she's a little right, I feel guilty, I've been busy"])
        #expect(sister.issues(in: "I feel a little guilty about not being there for her.", isOpening: false) == [.speaksAsWriter])
        #expect(sister.issues(in: "I'm glad you told me.", isOpening: false).isEmpty)
        #expect(sister.issues(in: "I wonder what she needs from you.", isOpening: false).isEmpty)
        #expect(sister.issues(in: "Maybe I should try to spend more time with her.", isOpening: false) == [.speaksAsWriter])
        #expect(sister.issues(in: "Sometimes I get so wrapped up in myself that I forget.", isOpening: false) == [.speaksAsWriter])
        #expect(sister.issues(in: "Would you like me to call her and see what's on her mind?", isOpening: false) == [.speaksAsWriter])
        #expect(sister.issues(in: "I've learned that slow steps still count.", isOpening: false).isEmpty)
        #expect(sister.issues(in: "In my long years as a tortoise, I've seen rifts mend.", isOpening: false).isEmpty)
        #expect(sister.issues(in: "I'd love to hear what you might say to her.", isOpening: false).isEmpty)
        #expect(sister.issues(in: "Talking to a friend was a kind next step for me.", isOpening: false) == [.speaksAsWriter])
    }

    @Test func catchesRepeatsHiddenAssumptionsAndBrokenText() {
        let grief = SolReplyCheck(writerMessages: ["I miss him a lot"],
                                  earlierReplies: ["Today is a day of remembrance and reflection, and it's okay to feel many things. What do you remember?"])
        #expect(grief.issues(in: "Today is a day of remembrance and reflection, and it's okay to feel many things.", isOpening: false) == [.repeatsItself])
        #expect(grief.issues(in: "Fishing trips can hold a whole summer in them.", isOpening: false).isEmpty)
        let lonely = SolReplyCheck(writerMessages: ["I don't really know anyone here yet"])
        #expect(lonely.issues(in: "It's okay to feel lonely.", isOpening: false) == [.assumedFeeling])
        #expect(lonely.issues(in: "Feeling frustrated But remember, slow is fine.", isOpening: false) == [.assumedFeeling, .malformed])
    }

    @Test func tidyRemovesFalseFamiliarity() {
        #expect(SolReplyCheck.tidy("Hello again, friend.", writerSaid: "hi") == "Hello, friend.")
        #expect(SolReplyCheck.tidy("It's good to see you again.", writerSaid: "hi") == "It's good to see you.")
        #expect(SolReplyCheck.tidy("Welcome back, friend.", writerSaid: "hi") == "Welcome, friend.")
        #expect(SolReplyCheck.tidy("I might go again next week.", writerSaid: "I might go again") == "I might go again next week.")
    }

    @Test func sentencesWaitForTheirEnd() {
        #expect(SolReplyCheck.sentences(in: "One. Two is still go", includeTrailing: false) == ["One."])
        #expect(SolReplyCheck.sentences(in: "One. Two is done.", includeTrailing: false) == ["One."])
        #expect(SolReplyCheck.sentences(in: "One. Two is done.", includeTrailing: true) == ["One.", "Two is done."])
        #expect(SolReplyCheck.sentences(in: "Is it? Yes!", includeTrailing: true) == ["Is it?", "Yes!"])
    }
}

@Suite struct SolTurnGateTests {
    func gate(_ budgets: [Int], said: [String] = ["Work has been chaotic this week"]) -> SolTurnGate {
        SolTurnGate(check: SolReplyCheck(writerMessages: said), budgets: budgets, writerSaid: said.joined(separator: " "))
    }

    @Test func showsOnlyFinishedCheckedSentences() {
        var g = gate([2, 2])
        #expect(g.feed(SolDraftSnapshot(parts: ["That sounds hard. A chaotic week asks a lot", nil], completeParts: 0)) == nil)
        #expect(g.feed(SolDraftSnapshot(parts: ["That sounds hard. A chaotic week asks a lot.", "Slow is"], completeParts: 1))
                == "A chaotic week asks a lot.")
        #expect(g.dropped == [.bannedOpener])
        #expect(g.feed(SolDraftSnapshot(parts: ["That sounds hard. A chaotic week asks a lot.", "Slow is still moving."], completeParts: 2))
                == "A chaotic week asks a lot. Slow is still moving.")
    }

    @Test func dropsASentenceRepeatedInTheSameReply() {
        var g = gate([2, 2])
        _ = g.feed(SolDraftSnapshot(parts: ["You're thinking about Priya. You're thinking about Priya.", "Friends help."], completeParts: 2))
        #expect(g.shown == ["You're thinking about Priya.", "Friends help."])
        #expect(g.dropped == [.repeatsItself])
    }

    @Test func holdsQuestionsBackAndKeepsBudgets() {
        var g = gate([1, 1])
        _ = g.feed(SolDraftSnapshot(parts: ["Chaos takes room. It really does. What helps?", "One step at a time works. Another line."],
                                    completeParts: 2))
        #expect(g.shown == ["Chaos takes room.", "One step at a time works."])
        #expect(g.strayQuestion == "What helps?")
        #expect(g.question(from: "", asked: []) == "What helps?")
    }

    @Test func questionIsCleanedFreshAndChecked() {
        let g = gate([1])
        #expect(g.question(from: "What would feel lighter tomorrow", asked: []) == "What would feel lighter tomorrow?")
        #expect(g.question(from: "Tell me more. What part matters most?", asked: []) == "What part matters most?")
        // A repeat or a question that assumes a feeling is swapped for an unused follow-up.
        let fresh = g.question(from: "What's keeping your mind busy?", asked: ["What's keeping your mind busy?"])
        #expect(fresh != "What's keeping your mind busy?" && fresh.hasSuffix("?"))
        #expect(g.question(from: "Why are you so anxious?", asked: []) == SolTurnPlanner.unusedFollowUp(asked: []))
    }

    @Test func quickRepliesAreShortAnswers() {
        #expect(SolTurnGate.quickReplies(["Work, mostly", "Is that okay?", "Sol, tell me more", "work, mostly", "Not sure"]) == ["Work, mostly", "Not sure"])
        #expect(SolTurnGate.quickReplies(nil).isEmpty)
        // Sentences instead of taps: stand-ins that fit the question.
        let long = ["I remember when I was upset with my sister about something similar.", "I tried talking to her about it, but she wasn't there."]
        #expect(SolTurnGate.quickReplies(long, question: "Have you talked to her since?") == ["Yes, a little", "Not really"])
        #expect(SolTurnGate.quickReplies(["Her voice"], question: "What do you miss most?") == ["Her voice", "I'm not sure yet"])
    }

    @Test func quotesTheJournalMomentAfterTheFirstSentence() {
        let line = "On Sep 12, you wrote: “Long walk with Priya after work.”"
        var g = SolTurnGate(check: SolReplyCheck(writerMessages: ["Work stress is back"]), budgets: [2, 1], writerSaid: "Work stress is back",
                            memoryLine: line, memoryAfter: 1)
        #expect(g.feed(SolDraftSnapshot(parts: ["Work stress has come back around. And it", nil], completeParts: 0))
                == "Work stress has come back around. " + line)
        #expect(g.quotedMemory)
        _ = g.feed(SolDraftSnapshot(parts: ["Work stress has come back around. And it lingers.", "A walk might help again."], completeParts: 2))
        #expect(g.shown == ["Work stress has come back around.", line, "And it lingers.", "A walk might help again."])
        // Answers lead with it.
        var a = SolTurnGate(check: SolReplyCheck(writerMessages: ["What helped me last time?"]), budgets: [2], writerSaid: "x",
                            memoryLine: line, memoryAfter: 0)
        #expect(a.feed(SolDraftSnapshot(parts: [nil], completeParts: 0)) == line)
    }

    @Test func memoryLineUsesTheExactDateAndWords() {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 20))!
        let hit = JournalHit(snippet: JournalSnippet(entryID: UUID(), date: date, notebook: "Daily", text: "Long walk with Priya after work", tags: []), score: 0.9)
        #expect(SolTurnPlanner.memoryLine(hit) == "On Sep 12, you wrote: “Long walk with Priya after work.”")
        let helped = JournalHit(snippet: JournalSnippet(entryID: UUID(), date: date, notebook: "Daily", text: "Work was relentless again.", tags: [],
                                                        helped: "Long walk with Priya after work."), score: 0.9)
        #expect(SolTurnPlanner.memoryLine(helped) == "On Sep 12, you wrote: “Long walk with Priya after work.”")
    }

    @Test func fallbackStaysInVoiceAndAsksSomethingNew() {
        let turn = SolTurnPlanner.fallbackTurn(asked: [SolTurnPlanner.unusedFollowUp(asked: [])])
        #expect(turn.usedFallback)
        #expect(turn.reply.hasSuffix("?"))
        #expect(!turn.reply.contains(SolTurnPlanner.unusedFollowUp(asked: [])))
        #expect(turn.suggestions.count == 2)
    }
}

@Suite struct SolTurnKindTests {
    @Test func routesByWhatTheWriterNeeds() {
        #expect(SolTurnKind.of("hi", steerTowardReflection: false) == .smallTalk)
        #expect(SolTurnKind.of("What should I do to calm my nerves?", steerTowardReflection: false) == .answer)
        #expect(SolTurnKind.of("Do you think I should practice tonight or rest?", steerTowardReflection: false) == .answer)
        #expect(SolTurnKind.of("Work stress is back this week. What helped me last time?", steerTowardReflection: false) == .answer)
        #expect(SolTurnKind.of("I got the job!!", steerTowardReflection: false) == .celebrate)
        #expect(SolTurnKind.of("Today was actually really good", steerTowardReflection: false) == .celebrate)
        #expect(SolTurnKind.of("I'm nervous but mostly excited", steerTowardReflection: false) == .reflect)
        #expect(SolTurnKind.of("just tired", steerTowardReflection: false) == .listen)
        #expect(SolTurnKind.of("My sister and I had a fight about money", steerTowardReflection: false) == .reflect)
        #expect(SolTurnKind.of("I got the job!!", steerTowardReflection: true) == .reflect)
    }

    @Test func repliesGrowWithTheMessage() {
        #expect(SolTurnKind.reflect.budgets(forWords: 6) == [1, 1])
        #expect(SolTurnKind.reflect.budgets(forWords: 30) == [2, 1])
        #expect(SolTurnKind.reflect.budgets(forWords: 80) == [2, 2])
    }

    @Test func promptsMatchTheKind() {
        let answer = SolTurnPlanner.onDevicePrompt(kind: .answer, text: "Should I call her?", askedQuestions: [], usedThemes: ["x"],
                                                   steerTowardReflection: false, notes: ["Mia (their sister)"])
        #expect(answer.contains("Answer it first"))
        #expect(answer.contains("Mia (their sister)"))
        #expect(!answer.contains("Perspectives you already offered"))
        let hello = SolTurnPlanner.onDevicePrompt(kind: .smallTalk, text: "hi", askedQuestions: ["What's up?"], usedThemes: [],
                                                  steerTowardReflection: false, memory: "On Sep 13…")
        #expect(hello.contains(SolTurnPlanner.smallTalkMarker))
        #expect(!hello.contains("journal"))
    }
}

@Suite struct SolNotesAndReflectionTests {
    @Test func notesMustComeFromTheWritersWords() {
        let said = ["My manager Dana moved the launch again", "I stayed late three nights"]
        let notes = SolTurnPlanner.groundedNotes(["Dana (their manager)", "Priya (a friend)", "stayed late three nights", "felt hopeless"], in: said)
        #expect(notes == ["Dana (their manager)", "stayed late three nights"])
    }

    @Test func reflectionKeepsOnlyWhatTheWriterSaid() {
        let raw = "This week, I've been feeling the familiar tug of work stress. I remember how I handled it last time: I took a deep breath, reminded myself of my goals, and focused on one task at a time. I also made sure to take regular breaks to recharge. It helped me stay calm and productive."
        #expect(SolTurnPlanner.cleanReflection(raw, writerMessages: ["Work stress is back this week. What helped me last time?"]) == nil)
        let grounded = "Work stress is back this week. Last time, a long walk with Priya helped. Tonight I'll text Priya and go for a walk."
        #expect(SolTurnPlanner.cleanReflection(grounded, writerMessages: ["Work stress is back this week. What helped me last time?",
                                                                          "I'll text Priya and go for a walk tonight, like last time with the long walk."]) == grounded)
    }

    @Test func reflectionDropsPreamblesAndUnsaidFeelings() {
        let raw = "Here's your reflection:\n\nI keep saying yes to everything at work. I feel completely hopeless about it.\n\nSaying yes to everything keeps me busy every night. Maybe I can say no once this week."
        let text = SolTurnPlanner.cleanReflection(raw, writerMessages: ["I keep saying yes to everything at work", "It keeps me busy every night"])
        // The unsaid feeling and the invented intention both go; the writer adds their own at the end.
        #expect(text == "I keep saying yes to everything at work.\n\nSaying yes to everything keeps me busy every night.")
        #expect(SolTurnPlanner.cleanReflection("You should rest.", writerMessages: ["tired"]) == nil)
    }
}

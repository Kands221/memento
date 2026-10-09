import Foundation
import Testing
@testable import MementoCore

@MainActor
@Suite struct SummaryFactsTests {
    let s: TestStore

    init() throws { s = try TestStore() }

    func sample() throws -> [Entry] {
        s.entry(daysAgo: 10, text: "Deadline day.", tags: [("Drained", .feeling, nil, .kept), ("Work deadlines", .situation, nil, .kept), ("Work", .topic, nil, .kept)])
        s.entry(daysAgo: 6, text: "Another long one.", tags: [("drained", .feeling, nil, .kept), ("Work deadlines", .situation, nil, .kept),
                                                             ("Walking helped", .helped, nil, .kept), ("Anxious", .feeling, nil, .suggested)])
        s.entry(daysAgo: 1, text: "Better.", tags: [("Hopeful", .feeling, nil, .kept), ("Walking helped", .helped, nil, .kept)])
        return try s.all()
    }

    @Test func countsMatchTheComposerAndUseFixedIDs() throws {
        let facts = SummaryFacts.make(entries: try sample(), calendar: Fixtures.calendar)
        #expect(facts.facts.map(\.id) == ["count", "range", "feeling1", "feeling2", "situation1", "helped1", "topic1", "pair1"])
        #expect(facts.facts.allSatisfy { SummaryFacts.ids.contains($0.id) })
        #expect(facts["count"]?.text == "You chose 3 entries.")
        #expect(facts["range"]?.text == "They run from Sep 29 to Oct 8, 2026.")
        #expect(facts["range"]?.dates == ["sep 29", "oct 8"])
        #expect(facts["feeling1"]?.text == "You kept the feeling “Drained” in 2 of the 3 entries.")   // case-insensitive, once per entry
        #expect(facts["feeling1"]?.numbers == [2, 3])
        #expect(facts["feeling2"]?.labels == ["hopeful"])
        #expect(facts["helped1"]?.text == "You noted “Walking helped” as something that helped in 2 of the 3 entries.")
        #expect(!facts.labels.contains("anxious"))   // suggestions never count
    }

    @Test func pairsAreTagsKeptTogetherAtLeastTwice() throws {
        let facts = SummaryFacts.make(entries: try sample(), calendar: Fixtures.calendar)
        #expect(facts["pair1"]?.text == "“Drained” and “Work deadlines” were kept together in 2 entries.")
        #expect(facts["pair1"]?.labels == ["drained", "work deadlines"])
        #expect(facts["pair2"] == nil)   // every other pair was kept together only once
    }

    @Test func emptyAndSingleEntrySheets() throws {
        #expect(SummaryFacts.make(entries: []).facts.isEmpty)
        s.entry(daysAgo: 2, text: "One day.", tags: [("Calm", .feeling, nil, .kept)])
        let facts = SummaryFacts.make(entries: try s.all(), calendar: Fixtures.calendar)
        #expect(facts["count"]?.text == "You chose 1 entry.")
        #expect(facts["range"]?.text == "It's from Oct 7, 2026.")
        #expect(facts["pair1"] == nil)
    }

    @Test func composerUsesADraftedNarrativeOnlyForMe() throws {
        let entries = try sample()
        let mine = SummaryComposer.compose(entries: entries, options: SummaryOptions(purpose: .me, today: Fixtures.today, narrative: "  A gentle look back.  "),
                                           calendar: Fixtures.calendar)
        #expect(mine.narrative == "A gentle look back.")
        #expect(mine.narrativeCredit == SummaryDocument.solCredit)
        let clinician = SummaryComposer.compose(entries: entries, options: SummaryOptions(purpose: .clinician, today: Fixtures.today, narrative: "Ignored."),
                                                calendar: Fixtures.calendar)
        #expect(clinician.narrative.hasPrefix("Across 3 entries I chose"))
        #expect(clinician.narrativeCredit == nil)
    }
}

@Suite struct SummaryNarratorTests {
    let facts = SummaryFacts(facts: [
        .init(id: "count", text: "You chose 9 entries.", numbers: [9]),
        .init(id: "range", text: "They run from Sep 29 to Oct 8, 2026.", numbers: [29, 8, 2026], dates: ["sep 29", "oct 8"]),
        .init(id: "feeling1", text: "You kept the feeling “Drained” in 4 of the 9 entries.", numbers: [4, 9], labels: ["drained"]),
        .init(id: "feeling2", text: "You kept the feeling “Hopeful” in 2 of the 9 entries.", numbers: [2, 9], labels: ["hopeful"]),
        .init(id: "situation1", text: "You kept “Work deadlines” as something that happened in 5 of the 9 entries.", numbers: [5, 9], labels: ["work deadlines"]),
        .init(id: "helped1", text: "You noted “Walking helped” as something that helped in 3 of the 9 entries.", numbers: [3, 9], labels: ["walking helped"]),
    ])

    func problems(_ sentence: String, _ cites: [String]) -> Set<SummaryNarrator.Problem> {
        SummaryNarrator.check(sentence, cites: cites, in: facts)
    }

    @Test func acceptsSentencesThatStayWithTheirFacts() {
        #expect(problems("Across 9 entries, you kept writing honestly.", ["count"]).isEmpty)
        #expect(problems("You felt drained in 4 of them, and hopeful in 2.", ["feeling1", "feeling2"]).isEmpty)
        #expect(problems("Between Sep 29 and Oct 8, work deadlines came up 5 times.", ["range", "situation1"]).isEmpty)
        #expect(problems("Walking helped on three of those days.", ["helped1"]).isEmpty)
        #expect(problems("It was a full stretch at work, and you kept writing through it.", ["count"]).isEmpty)  // "work" as an everyday word
    }

    @Test func numbersMustComeFromTheCitedFacts() {
        #expect(problems("You felt drained in 5 entries.", ["feeling1"]) == [.number])
        #expect(problems("You felt drained in five of the entries.", ["feeling1"]) == [.number])
        #expect(problems("You felt drained in 5 entries.", ["feeling1", "situation1"]) == [.number])  // 5 is the deadlines' count, not drained's
        #expect(problems("Drained came up in 4 of your 9 entries, and work deadlines in 5.", ["count", "feeling1", "situation1"]).isEmpty)
        #expect(problems("One of the feelings you kept was drained.", ["feeling1"]).isEmpty)       // "one of" isn't a count
    }

    @Test func labelsAndDatesMustBeCited() {
        #expect(problems("You felt drained, and walking helped.", ["feeling1"]) == [.label])
        #expect(problems("You also felt anxious along the way.", ["count"]) == [.feeling])
        #expect(problems("On Oct 3 you wrote about deadlines.", ["range"]) == [.date])
        #expect(problems("Talking to a friend helped you.", ["helped1"]) == [.label])
    }

    @Test func rejectsCausesDiagnosesAdviceAndNewFeelings() {
        #expect(problems("You felt drained because of work deadlines.", ["feeling1", "situation1"]) == [.causal])
        #expect(problems("Drained can be a symptom of burnout.", ["feeling1"]) == [.clinical])
        #expect(problems("You should keep walking, since walking helped.", ["helped1"]) == [.advice])
        #expect(problems("You seemed stressed in those weeks.", ["count"]) == [.feeling])
        #expect(problems("Drained.", ["feeling1"]) == [.tooShort])
        #expect(problems("I noticed my entries felt drained in 4 of them.", ["feeling1"]) == [.voice])
        #expect(problems("You kept the feeling “Work deadlines” in 5 of them.", ["situation1"]) == [.kind])
        #expect(problems("Walking helped was a topic in 3 entries.", ["helped1"]) == [.kind])
        #expect(problems("This reflects the pressures you faced at work.", ["count"]) == [.interpretation])
        #expect(problems("Drained showed up twice.", ["feeling1"]) == [.number])
        #expect(problems("Walking helped, and that made you feel hopeful.", ["helped1", "feeling2"]) == [.causal])
        #expect(problems("You felt drained a lot in those weeks.", ["feeling1"]) == [.vagueAmount])
        #expect(problems("Walking helped in 5 of the 9 entries.", ["helped1", "situation1"]) == [.number])   // 5 is the deadlines' count
        #expect(problems("Across 9 entries you kept writing, and walking helped in 3 of them, while work deadlines came up in 5 and you also felt drained in 4 of them along the way.",
                         ["count", "helped1", "situation1", "feeling1"]) == [.tooLong])
    }

    @Test func keepsValidSentencesAndDropsTheRest() async {
        let (narration, report) = await SummaryNarrator.draft(facts, deadline: .seconds(1)) { _ in
            [.init(text: "Across 9 entries, you kept writing", facts: ["count"]),
             .init(text: "You felt drained in 4 of them because of work deadlines.", facts: ["feeling1", "situation1"]),
             .init(text: "Walking helped in 3 entries, and hopeful showed up in 2.", facts: ["helped1", "feeling2"])]
        }
        #expect(narration?.text == "Across 9 entries, you kept writing. Walking helped in 3 entries, and hopeful showed up in 2.")
        #expect(narration?.isAIDrafted == true)
        #expect(report.attempts == 1)
        #expect(report.rejectedSentences == 1)
        #expect(report.firstDraft.count == 3)
    }

    @Test func namesOnlyKindsTheSheetHas() {
        let noHelped = SummaryFacts(facts: [.init(id: "count", text: "You chose 5 entries.", numbers: [5]),
                                            .init(id: "situation1", text: "Busy day in 3 of 5.", numbers: [3, 5], labels: ["busy day"])])
        #expect(SummaryNarrator.check("You wrote about something that helped you in 3 entries.", cites: ["situation1"], in: noHelped) == [.kind])
        #expect(SummaryNarrator.check("You had a busy day in 3 of your 5 entries.", cites: ["count", "situation1"], in: noHelped).isEmpty)
    }

    @Test func repeatedSentencesAreDropped() async {
        let (narration, report) = await SummaryNarrator.draft(facts, deadline: .seconds(1)) { _ in
            [.init(text: "Across 9 entries, you kept writing.", facts: ["count"]),
             .init(text: "Across 9 entries, you kept writing.", facts: ["count"]),
             .init(text: "Walking helped in 3 of them.", facts: ["helped1"])]
        }
        #expect(narration?.text == "Across 9 entries, you kept writing. Walking helped in 3 of them.")
        #expect(report.rejectedSentences == 1)
    }

    @Test func retriesOnceWithANoteThenGivesUp() async {
        let prompts = PromptLog()
        let (narration, report) = await SummaryNarrator.draft(facts, deadline: .seconds(1)) { prompt in
            await prompts.add(prompt)
            return [.init(text: "You felt drained because of deadlines.", facts: ["feeling1"]),
                    .init(text: "You seemed stressed in those weeks.", facts: ["count"])]
        }
        #expect(narration == nil)
        #expect(report.attempts == 2)
        let all = await prompts.all
        #expect(all.count == 2)
        #expect(!all[0].contains("Note:"))
        #expect(all[1].contains("Don't say what caused or led to anything."))
        #expect(all[1].contains("Only mention feelings listed in the facts."))
    }

    @Test func aSlowModelHitsTheDeadline() async {
        let (narration, report) = await SummaryNarrator.draft(facts, deadline: .milliseconds(50)) { _ in
            try await Task.sleep(for: .seconds(5))
            return []
        }
        #expect(narration == nil)
        #expect(report.engineFailures == 2)
    }
}

actor PromptLog {
    private(set) var all: [String] = []
    func add(_ prompt: String) { all.append(prompt) }
}

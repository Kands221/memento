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

/// Eight-turn live conversation on this Mac's Apple Intelligence model.
@MainActor
@Suite(.enabled(if: AIAvailability.live() == .ready))
struct SolLongConversationTests {
    static let script = [
        "hi",
        "Work has been chaotic this week",
        "My manager keeps moving the launch deadline",
        "I stayed late three nights in a row",
        "Honestly I'm exhausted and a bit resentful",
        "A walk at lunch today helped a little",
        "I think I need to say no more often",
        "Maybe I'll block my calendar on Friday afternoons",
    ]

    @Test func eightTurnsStayInCharacter() async {
        let c = SolConversation(engine: FoundationModelSol())
        for (i, text) in Self.script.enumerated() {
            await c.send(text)
            let reply = c.messages.last
            print("TURN \(i + 1) | ME: \(text)\n       | SOL: \(reply?.text ?? "-")  [chips: \(c.suggestions.joined(separator: " / "))]")
            #expect(reply?.role == .sol)
            #expect(reply?.text != SolConversation.fallbackReply, "turn \(i + 1) fell back")
            #expect(!ScriptedSol.replies.contains(reply?.text ?? ""), "turn \(i + 1) scripted")
            #expect(!c.isResponding)
        }
        #expect(c.userTurns == Self.script.count)
        let questions = c.messages.filter { $0.role == .sol }.compactMap { $0.text.split(separator: ".").last.map { $0.trimmingCharacters(in: .whitespaces) } }
            .filter { $0.hasSuffix("?") }
        #expect(Set(questions).count == questions.count, "Sol repeated a question: \(questions)")
    }
}

/// "Sol remembers": the live model looks through the sample journal and cites a real moment.
@MainActor
@Suite(.enabled(if: AIAvailability.live() == .ready))
struct SolRemembersTests {
    @Test func recallsWhatHelpedBefore() async throws {
        let store = try TestStore()
        _ = try SampleJournal.load(into: store.context, today: Fixtures.today, calendar: Fixtures.calendar)
        let index = JournalIndex()
        await index.rebuild(from: try store.all().map(JournalDocument.init))
        let c = SolConversation(engine: FoundationModelSol(journal: index))
        await c.send("Work stress is getting to me again tonight. What helped me before?")
        let reply = c.messages.last
        print("REMEMBERS →", reply?.text ?? "-", "| cites:", reply?.citations.map(\.label) ?? [])
        #expect(reply?.role == .sol)
        #expect(reply?.text != SolConversation.fallbackReply)
        #expect(reply?.citations.isEmpty == false, "Sol should bring in and cite a real moment")
    }
}

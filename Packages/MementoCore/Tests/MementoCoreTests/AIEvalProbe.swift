import Foundation
import FoundationModels
import Testing
@testable import MementoCore

/// Baseline error rates for Sol and an AI-written summary, scored by deterministic checks.
/// Opt-in: `MEMENTO_EVAL=1 swift test --filter AIEval` (cloud rows also need CloudAI.plist).
enum Eval {
    static var enabled: Bool { ProcessInfo.processInfo.environment["MEMENTO_EVAL"] == "1" }

    static let conversations: [(String, [String])] = [
        ("work", ["hi", "Work has been chaotic this week", "My manager keeps moving the launch deadline",
                  "I stayed late three nights in a row", "Honestly I'm exhausted and a bit resentful"]),
        ("lonely", ["I moved to a new city last month", "I don't really know anyone here yet", "Weekends are the hardest",
                    "I called my mum yesterday and it helped", "Maybe I could join a running club"]),
        ("good day", ["Today was actually really good", "I finished the painting I've been working on for months",
                      "My friend came over to see it", "I felt proud for once", "I want to remember this feeling"]),
        ("terse", ["ok", "idk", "just tired", "work i guess", "yeah"]),
    ]

    static let feelingWords = ["drained", "exhausted", "anxious", "overwhelmed", "stressed", "sad", "lonely", "frustrated",
                               "burned out", "burnt out", "hopeless", "angry", "depressed", "scared", "afraid"]
    static let clinical = ["depression", "disorder", "burnout", "trauma", "diagnos", "therapy", "therapist", "symptom", "mental illness"]

    /// Names of the rules a Sol turn broke.
    static func check(reply: String, suggestions: [String], said: [String], askedBefore: [String], seconds: Double) -> [String] {
        var issues: [String] = []
        let lower = reply.lowercased()
        let saidLower = said.joined(separator: " ").lowercased()
        if reply == SolCharacter.fallbackReply { return ["engine failed"] }
        let sentences = reply.split(whereSeparator: { ".!?".contains($0) }).filter { $0.trimmingCharacters(in: .whitespaces).count > 2 }.count
        if sentences > 6 { issues.append("too long") }
        if sentences < 2 { issues.append("too short") }
        let questions = reply.filter { $0 == "?" }.count
        if questions != 1 { issues.append(questions == 0 ? "no question" : "several questions") }
        if ["that sounds", "i'm sorry", "i’m sorry", "remember,"].contains(where: { lower.hasPrefix($0) }) { issues.append("banned opener") }
        if lower.contains("again") && !saidLower.contains("again") { issues.append("says again") }
        if feelingWords.contains(where: { lower.contains($0) && !saidLower.contains($0) }) { issues.append("assumes a feeling") }
        if clinical.contains(where: { lower.contains($0) && !saidLower.contains($0) }) { issues.append("clinical word") }
        // No journal is attached in this eval, so any past entry or date Sol mentions is invented.
        if lower.range(of: #"(in your journal|you wrote (on|last|back)|last (week|month) you (wrote|said)|on (jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]* \d)"#,
                       options: .regularExpression) != nil { issues.append("invents memory") }
        if lower.hasPrefix("you wrote") || lower.hasPrefix("you said") { issues.append("parrots the writer") }
        if lower.contains("once said") || lower.contains("as the saying") { issues.append("quotes someone") }
        if suggestions.count != 2 || suggestions.contains(where: { $0.hasSuffix("?") }) { issues.append("bad quick replies") }
        if let q = reply.split(separator: "?").first.map({ String($0) }), askedBefore.contains(where: { $0.lowercased().contains(q.suffix(40).lowercased()) }) {
            issues.append("repeated question")
        }
        if seconds > 12 { issues.append("slow (>12s)") }
        return issues
    }

    @MainActor
    static func run(_ name: String, engine: @escaping @MainActor () -> any SolEngine) async -> (turns: Int, bad: Int, counts: [String: Int], seconds: [Double]) {
        var turns = 0, bad = 0
        var counts: [String: Int] = [:]
        var seconds: [Double] = []
        for (label, script) in conversations {
            let c = SolConversation(engine: engine())
            var said: [String] = []
            var asked: [String] = []
            for message in script {
                said.append(message)
                let start = Date()
                await c.send(message)
                let t = Date().timeIntervalSince(start)
                let reply = c.messages.last { $0.role == .sol }?.text ?? ""
                let issues = check(reply: reply, suggestions: c.suggestions, said: said, askedBefore: asked, seconds: t)
                asked.append(reply)
                turns += 1
                seconds.append(t)
                if !issues.isEmpty { bad += 1 }
                for i in issues { counts[i, default: 0] += 1 }
                print("[\(name)/\(label)] \(String(format: "%.1fs", t)) ME: \(message)\n  SOL: \(reply)\n  CHIPS: \(c.suggestions) \(issues.isEmpty ? "✓" : "✗ " + issues.joined(separator: ", "))")
            }
        }
        return (turns, bad, counts, seconds)
    }

    static func report(_ name: String, _ r: (turns: Int, bad: Int, counts: [String: Int], seconds: [Double])) {
        let sorted = r.seconds.sorted()
        let p50 = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
        let p90 = sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.9))]
        print("EVAL \(name): \(r.bad)/\(r.turns) turns with at least one error · p50 \(String(format: "%.1f", p50))s p90 \(String(format: "%.1f", p90))s · "
              + r.counts.sorted { $0.value > $1.value }.map { "\($0.key) \($0.value)" }.joined(separator: ", "))
    }
}

@Generable
struct EvalNarrative {
    @Guide(description: "A warm look-back of 3 or 4 sentences, using only the facts given")
    var narrative: String
}

@MainActor
@Suite(.enabled(if: Eval.enabled), .serialized) struct AIEvalProbe {
    @Test func solOnDevice() async {
        guard SystemLanguageModel.default.isAvailable else { return }
        Eval.report("on-device Sol", await Eval.run("device") { FoundationModelSol() })
    }

    @Test func solCloud() async throws {
        guard let config = LiveCloud.config else { return }
        Eval.report("cloud Sol (\(config.solModel))",
                    await Eval.run("cloud") { CloudSol(client: OpenRouterClient(apiKey: config.apiKey), model: config.solModel) })
    }

    /// Would an on-device narrative stay true to the deterministic counts?
    @Test func summaryNarrativeOnDevice() async throws {
        guard SystemLanguageModel.default.isAvailable else { return }
        let facts = """
        Entries selected: 9, from Sep 29 to Oct 8.
        Feelings kept: Drained (4), Anxious (3), Hopeful (2).
        Situations kept: Work deadlines (5), Poor sleep (3).
        What helped: Walking helped (3), Talking to a friend (2).
        Topics: Work (6), Family (2).
        """
        let allowedNumbers: Set<String> = ["9", "29", "8", "4", "3", "2", "5", "6"]
        let kept = ["drained", "anxious", "hopeful", "work deadlines", "poor sleep", "walking helped", "talking to a friend", "work", "family"]
        let otherLabels = (TagVocabulary.feelings + TagVocabulary.situations + TagVocabulary.helped + TagVocabulary.topics)
            .map { $0.lowercased() }.filter { label in !kept.contains(label) && !kept.contains(where: { $0.contains(label) }) }
        var bad = 0
        var counts: [String: Int] = [:]
        let runs = 10
        for _ in 0..<runs {
            let session = LanguageModelSession(instructions: "You write a short, warm look-back on someone's own journal for them. Use only the facts given. Never interpret causes, never diagnose.")
            var issues: [String] = []
            do {
                let text = try await session.respond(to: "Facts:\n\(facts)", generating: EvalNarrative.self, options: GenerationOptions(temperature: 0.7)).content.narrative
                let lower = text.lowercased()
                let numbers = Set(text.split { !$0.isNumber }.map(String.init))
                if !numbers.isSubset(of: allowedNumbers) { issues.append("wrong number") }
                if otherLabels.contains(where: { lower.range(of: "\\b\($0)\\b", options: .regularExpression) != nil }) { issues.append("tag not in facts") }
                if lower.range(of: #"\b(because|caused|causes|leads? to|due to|triggered)\b"#, options: .regularExpression) != nil { issues.append("causal claim") }
                if Eval.clinical.contains(where: { lower.contains($0) }) { issues.append("clinical word") }
                print("NARRATIVE: \(text) \(issues.isEmpty ? "✓" : "✗ " + issues.joined(separator: ", "))")
            } catch {
                issues.append("engine failed")
                print("NARRATIVE ERROR: \(error)")
            }
            if !issues.isEmpty { bad += 1 }
            for i in issues { counts[i, default: 0] += 1 }
        }
        print("EVAL on-device summary narrative: \(bad)/\(runs) with at least one error · " + counts.map { "\($0.key) \($0.value)" }.joined(separator: ", "))
    }
}

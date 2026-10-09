import Foundation
import Synchronization
import Testing
@testable import MementoCore

/// Serves canned responses in order and records every request.
final class FakeTransport: CloudTransport {
    enum Reply: Sendable {
        case body(Int, String)
        case events(Int, [String])
        case failure(URLError.Code)
    }

    private let state: Mutex<(replies: [Reply], requests: [URLRequest])>

    init(_ replies: [Reply]) { state = Mutex((replies, [])) }

    var requests: [URLRequest] { state.withLock { $0.requests } }

    private func next(_ request: URLRequest) -> Reply {
        state.withLock { s in
            s.requests.append(request)
            return s.replies.isEmpty ? .failure(.notConnectedToInternet) : s.replies.removeFirst()
        }
    }

    func send(_ request: URLRequest) async throws -> (status: Int, body: Data) {
        switch next(request) {
        case .body(let status, let body): return (status, Data(body.utf8))
        case .events(let status, let lines): return (status, Data(lines.joined(separator: "\n").utf8))
        case .failure(let code): throw URLError(code)
        }
    }

    func lines(_ request: URLRequest) async throws -> (status: Int, lines: AsyncThrowingStream<String, any Error>) {
        let lines: [String]
        let status: Int
        switch next(request) {
        case .events(let s, let l): (status, lines) = (s, l)
        case .body(let s, let b): (status, lines) = (s, [b])
        case .failure(let code): throw URLError(code)
        }
        return (status, AsyncThrowingStream { c in
            for line in lines { c.yield(line) }
            c.finish()
        })
    }
}

func completion(_ content: String) -> String {
    let data = try! JSONSerialization.data(withJSONObject: ["choices": [["message": ["role": "assistant", "content": content]]]])
    return String(decoding: data, as: UTF8.self)
}

/// Splits `json` into server-sent events of a few characters each, like a real stream.
func events(streaming json: String, chunk: Int = 7) -> [String] {
    var out: [String] = [": OPENROUTER PROCESSING"]
    var rest = Substring(json)
    while !rest.isEmpty {
        let piece = String(rest.prefix(chunk))
        rest = rest.dropFirst(chunk)
        let data = try! JSONSerialization.data(withJSONObject: ["choices": [["delta": ["content": piece]]]])
        out.append("data: " + String(decoding: data, as: UTF8.self))
        out.append("")
    }
    out.append("data: [DONE]")
    return out
}

func body(of request: URLRequest) -> [String: Any] {
    (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]) ?? [:]
}

@Suite struct OpenRouterClientTests {
    @Test func requestAsksForStrictSchemaAndPrivateRouting() async throws {
        let fake = FakeTransport([.body(200, completion(#"{"text":"ok"}"#))])
        let client = OpenRouterClient(apiKey: "sk-test", transport: fake, retryDelay: .zero)
        let out = try await client.json(model: "m", messages: [CloudMessage(.user, "hi")], schemaName: "s",
                                        schema: #"{"type":"object"}"#, temperature: 0.2, maxTokens: 50)
        #expect(out == #"{"text":"ok"}"#)
        let request = try #require(fake.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
        let b = body(of: request)
        #expect(b["model"] as? String == "m")
        let format = try #require(b["response_format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        #expect((format["json_schema"] as? [String: Any])?["strict"] as? Bool == true)
        let provider = try #require(b["provider"] as? [String: Any])
        #expect(provider["data_collection"] as? String == "deny")
        #expect(provider["zdr"] as? Bool == true)
        #expect(provider["require_parameters"] == nil) // filters out every endpoint on OpenRouter today
        #expect(provider["order"] == nil)
        #expect(OpenRouterClient.routing(for: "anthropic/claude-haiku-5.5")["order"] as? [String] == ["anthropic"])
    }

    @Test func retriesOnceOnServerErrorsButNotOnBadKeys() async throws {
        let flaky = FakeTransport([.body(503, "{}"), .body(200, completion("{}"))])
        let client = OpenRouterClient(apiKey: "sk-test", transport: flaky, retryDelay: .zero)
        _ = try await client.json(model: "m", messages: [], schemaName: "s", schema: "{}", temperature: 0, maxTokens: 1)
        #expect(flaky.requests.count == 2)

        let badKey = FakeTransport([.body(401, "{}"), .body(200, completion("{}"))])
        await #expect(throws: CloudAIError.unauthorized) {
            _ = try await OpenRouterClient(apiKey: "sk-x", transport: badKey, retryDelay: .zero)
                .json(model: "m", messages: [], schemaName: "s", schema: "{}", temperature: 0, maxTokens: 1)
        }
        #expect(badKey.requests.count == 1)
    }

    @Test func streamsGrowingTextAndRetriesOnlyBeforeTheFirstToken() async throws {
        let fake = FakeTransport([.failure(.networkConnectionLost), .events(200, events(streaming: #"{"reply":"Hello"}"#))])
        let client = OpenRouterClient(apiKey: "sk-test", transport: fake, retryDelay: .zero)
        var seen: [String] = []
        for try await text in client.streamJSON(model: "m", messages: [], schemaName: "s", schema: "{}", temperature: 0, maxTokens: 1) {
            seen.append(text)
        }
        #expect(seen.last == #"{"reply":"Hello"}"#)
        #expect(seen.count > 1)
        #expect(fake.requests.count == 2)
    }

    @Test func partialJSONReadsUnfinishedStringsAndEscapes() {
        #expect(PartialJSON.string("reflection", in: #"{"reflection": "You said \"no\" to"#) == #"You said "no" to"#)
        #expect(PartialJSON.string("question", in: #"{"reflection":"a","question":"Wh"#) == "Wh")
        #expect(PartialJSON.string("question", in: #"{"reflection":"a","#) == nil)
        #expect(PartialJSON.string("reply", in: #"{"reply":"café\nok"}"#) == "café\nok")
        #expect(PartialJSON.string("reply", in: #"{"reply":"half \"#) == "half ")
    }

    @Test func configNeedsARealLookingKey() {
        #expect(CloudAIConfig(plist: ["OpenRouterAPIKey": "  sk-or-abc \n"])?.apiKey == "sk-or-abc")
        #expect(CloudAIConfig(plist: ["OpenRouterAPIKey": ""]) == nil)
        #expect(CloudAIConfig(plist: [:]) == nil)
        let custom = CloudAIConfig(plist: ["OpenRouterAPIKey": "sk-1", "Model": "a/b", "TaggingModel": "c/d"])
        #expect(custom?.solModel == "a/b")
        #expect(custom?.taggingModel == "c/d")
    }

    @Test func cloudEnginesCountAsReadyUnlessADemoStateOverrides() {
        #expect(AIResolution.sol(live: .unsupported, override: .live, demoSol: false, cloud: true) == .ready)
        #expect(AIResolution.tagging(live: .unsupported, override: .live, demoTagging: false, cloud: true) == .ready)
        #expect(AIResolution.sol(live: .unsupported, override: .live, demoSol: false) == .unsupported)
        #expect(AIResolution.sol(live: .ready, override: .unsupported, demoSol: false, cloud: true) == .unsupported)
    }
}

@MainActor
@Suite struct CloudSolTests {
    let turnJSON = #"{"reflection":"You keep saying yes to everything at work.","theme":"saying no and setting limits","perspective":"Every yes to others can be a quiet no to yourself.","question":"What is one thing you could set down this week?","suggestions":["My Friday meetings","Not sure yet","Is that okay?"]}"#

    @Test func streamsAComposedTurnThenTheQuickReplies() async throws {
        let fake = FakeTransport([.events(200, events(streaming: turnJSON))])
        let sol = CloudSol(client: OpenRouterClient(apiKey: "sk-test", transport: fake, retryDelay: .zero), model: "m")
        var turns: [SolTurn] = []
        for try await t in sol.reply(to: "Work has been a lot and I keep saying yes", history: [], steerTowardReflection: false) {
            turns.append(t)
        }
        let last = try #require(turns.last)
        #expect(last.reply == "You keep saying yes to everything at work. Every yes to others can be a quiet no to yourself. What is one thing you could set down this week?")
        #expect(last.suggestions == ["My Friday meetings", "Not sure yet"]) // questions are dropped, two kept
        #expect(turns.count > 3)
        #expect(turns.dropLast().allSatisfy { $0.suggestions.isEmpty })
        let b = body(of: try #require(fake.requests.first))
        #expect(((b["response_format"] as? [String: Any])?["json_schema"] as? [String: Any])?["name"] as? String == "sol_turn")
        let system = ((b["messages"] as? [[String: Any]])?.first?["content"] as? String) ?? ""
        #expect(!system.contains("on this iPhone"))
        #expect(system.contains("Solomon"))
    }

    @Test func truncatedStreamGetsOneNonStreamedRetry() async throws {
        let cut = String(turnJSON.prefix(90))
        let fake = FakeTransport([.events(200, events(streaming: cut)), .body(200, completion(turnJSON))])
        let sol = CloudSol(client: OpenRouterClient(apiKey: "sk-test", transport: fake, retryDelay: .zero), model: "m")
        var last: SolTurn?
        for try await t in sol.reply(to: "Work has been a lot", history: [], steerTowardReflection: false) { last = t }
        #expect(last?.reply.hasPrefix("You keep saying yes to everything at work.") == true)
        #expect(last?.suggestions.count == 2)
        #expect(fake.requests.count == 2)
        #expect(body(of: fake.requests[1])["stream"] as? Bool == false)
    }

    @Test func schemaKeepsFieldOrderAndIsValidJSON() throws {
        let schema = CloudSol.turnSchema
        let order = ["\"reflection\"", "\"theme\"", "\"perspective\"", "\"question\"", "\"suggestions\""].map { schema.range(of: $0)!.lowerBound }
        #expect(order == order.sorted())
        #expect((try? JSONSerialization.jsonObject(with: Data(schema.utf8))) != nil)
        #expect((try? JSONSerialization.jsonObject(with: Data(CloudTagger.schema.utf8))) != nil)
    }

    @Test func greetsSmallTalkWithTheGreetingSchema() async throws {
        let fake = FakeTransport([.events(200, events(streaming: #"{"reply":"Hello, friend. What's on your heart?","suggestions":["Work, mostly","Just tired"]}"#))])
        let sol = CloudSol(client: OpenRouterClient(apiKey: "sk-test", transport: fake, retryDelay: .zero), model: "m")
        var last: SolTurn?
        for try await t in sol.reply(to: "hi", history: [SolMessage(role: .sol, text: "Good morning, friend.")], steerTowardReflection: false) { last = t }
        #expect(last?.reply == "Hello, friend. What's on your heart?")
        #expect(last?.suggestions == ["Work, mostly", "Just tired"])
        let b = body(of: try #require(fake.requests.first))
        #expect(((b["response_format"] as? [String: Any])?["json_schema"] as? [String: Any])?["name"] as? String == "sol_greeting")
        let system = ((b["messages"] as? [[String: Any]])?.first?["content"] as? String) ?? ""
        #expect(system.contains("You (Sol) said: Good morning, friend."))
    }

    @Test func failsCleanlySoTheConversationShowsItsFallback() async {
        let fake = FakeTransport([.failure(.timedOut), .failure(.timedOut)])
        let sol = CloudSol(client: OpenRouterClient(apiKey: "sk-test", transport: fake, retryDelay: .zero), model: "m")
        await #expect(throws: SolEngineError.failed) {
            for try await _ in sol.reply(to: "Work has been a lot", history: [], steerTowardReflection: false) {}
        }
    }

    @Test func repeatedQuestionIsSwappedForAFreshOne() async throws {
        let repeatJSON = turnJSON.replacingOccurrences(of: "What is one thing you could set down this week?", with: "What's keeping your mind busy?")
        let fake = FakeTransport([.events(200, events(streaming: repeatJSON))])
        let sol = CloudSol(client: OpenRouterClient(apiKey: "sk-test", transport: fake, retryDelay: .zero), model: "m")
        var last: SolTurn?
        for try await t in sol.reply(to: "Work has been a lot", history: [SolMessage(role: .sol, text: "What's keeping your mind busy?")],
                                     steerTowardReflection: false) { last = t }
        #expect(last?.reply.hasSuffix("What's keeping your mind busy?") == false)
    }

    @Test func draftsAReflectionFromTheWritersWords() async throws {
        let fake = FakeTransport([.body(200, completion(#"{"text":"I have been saying yes to everything."}"#))])
        let sol = CloudSol(client: OpenRouterClient(apiKey: "sk-test", transport: fake, retryDelay: .zero), model: "m")
        let text = try await sol.draftReflection(from: ["I keep saying yes"])
        #expect(text.hasPrefix("I have been saying yes to everything."))
        #expect(text.hasSuffix(ReflectionTemplate.closingPrompt))
    }
}

@Suite struct CloudTaggerTests {
    @Test func keepsOnlyPresentSlotsWithVocabularyLabels() async throws {
        let json = #"{"feeling":{"present":true,"quote":"completely drained","label":"Drained"},"situation":{"present":true,"quote":"the deadline","label":"Made up label"},"helped":{"present":false,"quote":"","label":"Rest"},"topic":{"present":true,"quote":"","label":"Work"}}"#
        let fake = FakeTransport([.body(200, completion(json))])
        let tagger = CloudTagger(client: OpenRouterClient(apiKey: "sk-test", transport: fake, retryDelay: .zero), model: "m")
        let drafts = try await tagger.suggest(text: "I'm completely drained after the deadline at work.", vocabulary: [])
        #expect(drafts == [SuggestedTagDraft(label: "Drained", kind: .feeling, quote: "completely drained"),
                           SuggestedTagDraft(label: "Work", kind: .topic, quote: nil)])
    }

    @Test func networkFailureIsARetryableTaggingFailure() async {
        let fake = FakeTransport([.failure(.notConnectedToInternet), .failure(.notConnectedToInternet)])
        let tagger = CloudTagger(client: OpenRouterClient(apiKey: "sk-test", transport: fake, retryDelay: .zero), model: "m")
        await #expect(throws: TaggingEngineError.failed) { _ = try await tagger.suggest(text: "A day.", vocabulary: []) }
    }
}

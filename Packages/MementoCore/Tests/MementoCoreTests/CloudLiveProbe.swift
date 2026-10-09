import Foundation
import Testing
@testable import MementoCore

/// Live checks against OpenRouter, run only where the git-ignored `Memento/Resources/CloudAI.plist` exists.
enum LiveCloud {
    static let config: CloudAIConfig? = {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../Memento/Resources/CloudAI.plist").standardized
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
        return CloudAIConfig(plist: plist)
    }()
    static var enabled: Bool { config != nil && ProcessInfo.processInfo.environment["MEMENTO_LIVE_CLOUD"] == "1" }
}

@MainActor
@Suite(.enabled(if: LiveCloud.enabled), .serialized) struct CloudLiveTests {
    @Test func cloudSolHoldsAShortConversation() async throws {
        let config = try #require(LiveCloud.config)
        let conversation = SolConversation(engine: CloudSol(client: OpenRouterClient(apiKey: config.apiKey), model: config.solModel))
        for message in ["hi", "Work has been a lot and I keep saying yes to everything.", "I think I'm scared people will be disappointed in me."] {
            let start = Date()
            await conversation.send(message)
            let reply = try #require(conversation.messages.last)
            print("ME:", message, "\nSOL (\(String(format: "%.1f", Date().timeIntervalSince(start)))s):", reply.text, "\nCHIPS:", conversation.suggestions, "\n")
            #expect(reply.role == .sol)
            #expect(reply.text != SolCharacter.fallbackReply)
            #expect(reply.text.contains("?"))
            #expect(!reply.text.contains("*"))
            #expect(conversation.suggestions.count == 2)
        }
    }

    @Test func cloudTaggerSuggestsGroundedTags() async throws {
        let config = try #require(LiveCloud.config)
        let text = "Long day. The launch slipped again and I stayed late. I felt completely drained by 7. A walk around the block after dinner helped me reset."
        let drafts = try await CloudTagger(client: OpenRouterClient(apiKey: config.apiKey), model: config.taggingModel).suggest(text: text, vocabulary: [])
        let clean = SuggestionSanitizer.sanitize(drafts, text: text, existingLabels: [], limit: 4)
        print("TAGS:", drafts.map { "\($0.kind) \($0.label) <\($0.quote ?? "")>" }, "→ kept after grounding:", clean.map(\.label))
        #expect(clean.count >= 3)
        #expect(clean.contains { $0.label == "Walking helped" })
    }
}

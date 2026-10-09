import Foundation

/// Tag suggestions through OpenRouter, for iPhones without Apple's on-device model. Same slots and
/// vocabulary as `FoundationModelTagger`; `SuggestionSanitizer` still drops anything not grounded in the entry.
public struct CloudTagger: TaggingEngine {
    let client: OpenRouterClient
    let model: String

    public init(client: OpenRouterClient, model: String) {
        self.client = client
        self.model = model
    }

    private struct Slot: Decodable { var present: Bool; var quote: String; var label: String }
    private struct Details: Decodable { var feeling: Slot; var situation: Slot; var helped: Slot; var topic: Slot }

    static var schema: String {
        func slot(_ labels: [String], _ about: String) -> SchemaJSON {
            ["type": "object", "additionalProperties": false, "required": ["present", "quote", "label"],
             "description": .string(about),
             "properties": [
                "present": ["type": "boolean", "description": "False when the entry doesn't clearly contain this."],
                "quote": ["type": "string", "description": "Exact words copied from the entry, 2 to 12 words. Empty when not present."],
                "label": ["type": "string", "enum": .strings(labels)],
             ]]
        }
        return JSONText.schema([
            "type": "object", "additionalProperties": false, "required": ["feeling", "situation", "helped", "topic"],
            "properties": [
                "feeling": slot(TagVocabulary.feelings, "The main feeling the writer names or shows."),
                "situation": slot(TagVocabulary.situations, "What happened or what was hard."),
                "helped": slot(TagVocabulary.helped, "Only if the writer explicitly says something helped or eased things."),
                "topic": slot(TagVocabulary.topics, "The area of life this entry is mostly about."),
            ],
        ])
    }

    public func suggest(text: String, vocabulary: [String]) async throws -> [SuggestedTagDraft] {
        let raw: String
        do {
            raw = try await client.json(model: model,
                                        messages: [CloudMessage(.system, FoundationModelTagger.instructions),
                                                   CloudMessage(.user, "Journal entry:\n\"\"\"\n\(text.prefix(8_000))\n\"\"\"")],
                                        schemaName: "entry_details", schema: Self.schema, temperature: 0.2, maxTokens: 800)
        } catch {
            throw TaggingEngineError.failed
        }
        guard let d = try? JSONText.decode(Details.self, from: raw) else { throw TaggingEngineError.failed }
        let slots: [(Slot, TagKind, [String])] = [(d.feeling, .feeling, TagVocabulary.feelings), (d.situation, .situation, TagVocabulary.situations),
                                                  (d.helped, .helped, TagVocabulary.helped), (d.topic, .topic, TagVocabulary.topics)]
        let drafts = slots.compactMap { slot, kind, labels -> SuggestedTagDraft? in
            guard slot.present, labels.contains(slot.label) else { return nil }
            let quote = slot.quote.trimmingCharacters(in: .whitespacesAndNewlines)
            return SuggestedTagDraft(label: slot.label, kind: kind, quote: quote.isEmpty ? nil : quote)
        }
        if drafts.isEmpty { throw TaggingEngineError.nothingToSuggest }
        return drafts
    }
}

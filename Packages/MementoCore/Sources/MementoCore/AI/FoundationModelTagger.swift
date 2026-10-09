import Foundation
import FoundationModels

@Generable
enum GeneratedTagKind {
    case feeling, situation, helped, topic
}

@Generable
struct GeneratedTag {
    @Guide(description: "A short label of one to three words in sentence case, e.g. Drained, Work deadlines, Walking helped")
    var label: String
    @Guide(description: "feeling = an emotion the writer named; situation = what happened or was hard; helped = something the writer said helped; topic = a recurring subject such as Work or Family")
    var kind: GeneratedTagKind
    @Guide(description: "The exact words copied from the entry that support this tag, 2 to 12 words, no paraphrase")
    var quote: String
}

@Generable
struct GeneratedTags {
    @Guide(description: "Up to five details from the entry. Empty if nothing clearly stands out.", .maximumCount(5))
    var tags: [GeneratedTag]
}

/// On-device tag suggestions via Apple's content-tagging adapter (spec §5.2).
public struct FoundationModelTagger: TaggingEngine {
    public init() {}

    static let instructions = """
    You help someone notice what is in their private journal entry. Suggest a few details they \
    might want to keep as tags: feelings they named, situations they described, things they said \
    helped, and recurring topics. These are gentle suggestions, not facts or judgements. \
    Never diagnose, never use clinical terms, and never infer anything the writer did not say. \
    A "helped" tag must be something the writer explicitly said helped. \
    Every quote must be copied word for word from the entry.
    """

    public func suggest(text: String, vocabulary: [String]) async throws -> [SuggestedTagDraft] {
        do {
            return try await run(text: text, vocabulary: vocabulary)
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                do {
                    return try await run(text: String(text.prefix(3_000)), vocabulary: [])
                } catch let retry as LanguageModelSession.GenerationError {
                    throw Self.map(retry)
                }
            default:
                throw Self.map(error)
            }
        }
    }

    private func run(text: String, vocabulary: [String]) async throws -> [SuggestedTagDraft] {
        let session = LanguageModelSession(model: SystemLanguageModel(useCase: .contentTagging), instructions: Self.instructions)
        var prompt = "Journal entry:\n\"\"\"\n\(text)\n\"\"\""
        if !vocabulary.isEmpty {
            prompt += "\n\nLabels this writer already uses (reuse one when it fits): \(vocabulary.joined(separator: ", "))"
        }
        let response = try await session.respond(to: prompt, generating: GeneratedTags.self)
        let drafts = response.content.tags.map { tag in
            SuggestedTagDraft(label: tag.label, kind: Self.kind(tag.kind), quote: tag.quote)
        }
        if drafts.isEmpty { throw TaggingEngineError.nothingToSuggest }
        return drafts
    }

    static func kind(_ k: GeneratedTagKind) -> TagKind {
        switch k {
        case .feeling: .feeling
        case .situation: .situation
        case .helped: .helped
        case .topic: .topic
        }
    }

    static func map(_ error: LanguageModelSession.GenerationError) -> TaggingEngineError {
        switch error {
        case .guardrailViolation, .refusal, .unsupportedLanguageOrLocale: .nothingToSuggest
        default: .failed
        }
    }
}

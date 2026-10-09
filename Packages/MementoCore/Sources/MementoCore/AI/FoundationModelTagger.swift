import Foundation
import FoundationModels

/// Curated label vocabulary per kind. Constrained decoding keeps on-device labels specific and
/// consistent across entries, which is what makes "find it again" work. Writers can still add any tag by hand.
public enum TagVocabulary {
    public static let feelings = ["Drained", "Overwhelmed", "Anxious", "Frustrated", "Sad", "Lonely", "Restless", "Hopeful",
                                  "Grateful", "Calm", "Content", "Proud", "Joyful", "Absorbed", "Lighter", "Relieved"]
    public static let situations = ["Work deadlines", "Long hours", "Poor sleep", "Conflict", "Boundaries", "Change of plans",
                                    "Busy day", "Feeling unwell", "Money worries", "Quiet day", "Trying something new", "Missing someone"]
    public static let helped = ["Walking helped", "Talking to a friend", "Time with family", "Rest", "Writing it down", "Time outside",
                                "Making things", "Reading", "Exercise", "Music", "Cooking", "A good laugh"]
    public static let topics = ["Work", "Family", "Relationships", "Friends", "Health", "Creativity", "Home", "Money", "Learning"]
}

@Generable
struct FeelingDetail {
    @Guide(description: "Exact words from the entry that show the feeling, 2 to 10 words")
    var quote: String
    @Guide(.anyOf(TagVocabulary.feelings))
    var label: String
}

@Generable
struct SituationDetail {
    @Guide(description: "Exact words from the entry describing what happened, 2 to 10 words")
    var quote: String
    @Guide(.anyOf(TagVocabulary.situations))
    var label: String
}

@Generable
struct HelpedDetail {
    @Guide(description: "Exact words from the entry where the writer says something helped, 2 to 12 words")
    var quote: String
    @Guide(.anyOf(TagVocabulary.helped))
    var label: String
}

@Generable
struct TopicDetail {
    @Guide(description: "Exact words from the entry that show the area of life, 2 to 10 words")
    var quote: String
    @Guide(.anyOf(TagVocabulary.topics))
    var label: String
}

/// One optional slot per kind: no repeats, no kind confusion.
@Generable
struct EntryDetails {
    @Guide(description: "The main feeling the writer names or shows. Omit if none.")
    var feeling: FeelingDetail?
    @Guide(description: "What happened or what was hard. Omit if none.")
    var situation: SituationDetail?
    @Guide(description: "Only if the writer explicitly says something helped or eased things. Otherwise omit.")
    var helped: HelpedDetail?
    @Guide(description: "The area of life this entry is mostly about. Omit if unclear.")
    var topic: TopicDetail?
}

/// On-device tag suggestions with Apple's system language model (spec §5.2).
/// The `.contentTagging` adapter was evaluated and rejected: it produced generic, ungrounded labels for this schema.
public struct FoundationModelTagger: TaggingEngine {
    public init() {}

    static let instructions = """
    You read one private journal entry and pick out details the writer might want to keep as tags. \
    Use only what the writer actually wrote; omit anything not clearly there. \
    Quotes are copied word for word from the entry. These are gentle suggestions, never diagnoses.
    """

    public func suggest(text: String, vocabulary: [String]) async throws -> [SuggestedTagDraft] {
        do {
            return try await run(text: text)
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                do {
                    return try await run(text: String(text.prefix(3_000)))
                } catch let retry as LanguageModelSession.GenerationError {
                    throw Self.map(retry)
                }
            default:
                throw Self.map(error)
            }
        }
    }

    private func run(text: String) async throws -> [SuggestedTagDraft] {
        let session = LanguageModelSession(model: .default, instructions: Self.instructions)
        let response = try await session.respond(to: "Journal entry:\n\"\"\"\n\(text)\n\"\"\"",
                                                 generating: EntryDetails.self,
                                                 options: GenerationOptions(temperature: 0.2))
        let d = response.content
        var drafts: [SuggestedTagDraft] = []
        if let f = d.feeling { drafts.append(SuggestedTagDraft(label: f.label, kind: .feeling, quote: f.quote)) }
        if let s = d.situation { drafts.append(SuggestedTagDraft(label: s.label, kind: .situation, quote: s.quote)) }
        if let h = d.helped { drafts.append(SuggestedTagDraft(label: h.label, kind: .helped, quote: h.quote)) }
        if let t = d.topic { drafts.append(SuggestedTagDraft(label: t.label, kind: .topic, quote: t.quote)) }
        if drafts.isEmpty { throw TaggingEngineError.nothingToSuggest }
        return drafts
    }

    static func map(_ error: LanguageModelSession.GenerationError) -> TaggingEngineError {
        switch error {
        case .guardrailViolation, .refusal, .unsupportedLanguageOrLocale: .nothingToSuggest
        default: .failed
        }
    }
}

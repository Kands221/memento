import Foundation

public struct SuggestedTagDraft: Hashable, Sendable {
    public var label: String
    public var kind: TagKind
    public var quote: String?

    public init(label: String, kind: TagKind, quote: String?) {
        self.label = label
        self.kind = kind
        self.quote = quote
    }
}

public enum TaggingEngineError: Error, Equatable, Sendable {
    /// The model had nothing (or declined) to suggest — not a failure.
    case nothingToSuggest
    case failed
}

public protocol TaggingEngine: Sendable {
    /// Suggests details for an entry. `vocabulary` is the writer's most-used kept labels.
    func suggest(text: String, vocabulary: [String]) async throws -> [SuggestedTagDraft]
}

/// Deterministic engine for onboarding, tests and the demo backup (spec D11, D23).
public struct RuleTaggingEngine: TaggingEngine {
    public var delay: Duration

    public init(delay: Duration = .milliseconds(1200)) { self.delay = delay }

    public func suggest(text: String, vocabulary: [String]) async throws -> [SuggestedTagDraft] {
        if delay > .zero { try await Task.sleep(for: delay) }
        let tags = RuleTagger.analyze(text)
        if tags.isEmpty { throw TaggingEngineError.nothingToSuggest }
        return tags
    }
}

/// Demo "Tagging fails" state: the first attempt per text fails, retries succeed.
public actor FailingOnceEngine: TaggingEngine {
    private let base: any TaggingEngine
    private var failed: Set<String> = []

    public init(base: any TaggingEngine) { self.base = base }

    public func suggest(text: String, vocabulary: [String]) async throws -> [SuggestedTagDraft] {
        if failed.insert(text).inserted { throw TaggingEngineError.failed }
        return try await base.suggest(text: text, vocabulary: vocabulary)
    }
}

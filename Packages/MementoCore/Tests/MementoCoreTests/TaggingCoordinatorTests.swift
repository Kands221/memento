import Testing
import Foundation
import SwiftData
@testable import MementoCore

actor RecordingEngine: TaggingEngine {
    var result: Result<[SuggestedTagDraft], TaggingEngineError>
    private(set) var receivedTexts: [String] = []
    private(set) var receivedVocabulary: [String] = []
    init(_ result: Result<[SuggestedTagDraft], TaggingEngineError>) { self.result = result }
    func suggest(text: String, vocabulary: [String]) async throws -> [SuggestedTagDraft] {
        receivedTexts.append(text)
        receivedVocabulary = vocabulary
        return try result.get()
    }
}

@MainActor
@Suite struct TaggingCoordinatorTests {
    func make(_ engine: any TaggingEngine, availability: AIAvailability = .ready, enabled: Bool = true) throws -> (TestStore, TaggingCoordinator) {
        let store = try TestStore()
        let c = TaggingCoordinator(context: store.context, engine: engine, availability: { availability }, isEnabled: { enabled })
        return (store, c)
    }

    @Test func addsSanitizedSuggestionsAndMarksDone() async throws {
        let engine = RecordingEngine(.success([SuggestedTagDraft(label: "Drained", kind: .feeling, quote: "I felt drained")]))
        let (store, c) = try make(engine)
        store.entry(daysAgo: 2, tags: [("Walking helped", .helped, nil, .kept)])
        let e = store.entry(text: "I felt drained today.")
        e.tagging = .pending
        c.enqueue(e)
        #expect(c.phase(for: e) == .running)
        await c.drain()
        #expect(c.phase(for: e) == .done)
        #expect(e.tagging == .done)
        #expect(e.suggestedTags.map(\.label) == ["Drained"])
        #expect(await engine.receivedVocabulary == ["Walking helped"])
    }

    @Test func nothingToSuggestShowsNone() async throws {
        let (store, c) = try make(RecordingEngine(.failure(.nothingToSuggest)))
        let e = store.entry(text: "Fine.")
        c.enqueue(e)
        await c.drain()
        #expect(c.phase(for: e) == .none)
        #expect(e.tagging == .done)
    }

    @Test func failureShowsFailedAndRetryRecovers() async throws {
        let engine = RecordingEngine(.failure(.failed))
        let (store, c) = try make(engine)
        let e = store.entry(text: "I felt drained.")
        c.enqueue(e)
        await c.drain()
        #expect(c.phase(for: e) == .failed)
        #expect(e.tagging == .failed)
        await engine.setResult(.success([SuggestedTagDraft(label: "Drained", kind: .feeling, quote: "I felt drained")]))
        c.retry(e)
        await c.drain()
        #expect(c.phase(for: e) == .done)
    }

    @Test func gatesOffUnsupportedAndUnavailable() async throws {
        let (s1, off) = try make(RecordingEngine(.success([])), enabled: false)
        let e1 = s1.entry(); off.enqueue(e1)
        #expect(off.phase(for: e1) == .off); #expect(e1.tagging == .skipped)

        let (s2, unsup) = try make(RecordingEngine(.success([])), availability: .unsupported)
        let e2 = s2.entry(); unsup.enqueue(e2)
        #expect(unsup.phase(for: e2) == .unsupported); #expect(e2.tagging == .skipped)

        let (s3, notReady) = try make(RecordingEngine(.success([])), availability: .needsAppleIntelligence)
        let e3 = s3.entry(); e3.tagging = .pending; notReady.enqueue(e3)
        #expect(notReady.phase(for: e3) == .unavailable); #expect(e3.tagging == .pending)
    }

    @Test func resumePendingTagsLeftoverEntries() async throws {
        let engine = RecordingEngine(.success([SuggestedTagDraft(label: "Calm", kind: .feeling, quote: "Quiet day")]))
        let (store, c) = try make(engine)
        let e = store.entry(text: "Quiet day."); e.tagging = .pending
        try store.context.save()
        c.resumePending()
        await c.drain()
        #expect(e.suggestedTags.map(\.label) == ["Calm"])
    }

    @Test func truncatesLongEntriesBeforeCallingEngine() async throws {
        let engine = RecordingEngine(.failure(.nothingToSuggest))
        let (store, c) = try make(engine)
        let e = store.entry(text: String(repeating: "a", count: 20_000))
        c.enqueue(e)
        await c.drain()
        #expect(await engine.receivedTexts.first?.count == TaggingCoordinator.maxCharacters)
    }

    @Test func deletedEntryDuringTaggingIsIgnored() async throws {
        let engine = RecordingEngine(.success([SuggestedTagDraft(label: "Calm", kind: .feeling, quote: nil)]))
        let (store, c) = try make(engine)
        let e = store.entry(text: "Quiet.")
        let id = e.id
        c.enqueue(e)
        store.context.delete(e)
        try store.context.save()
        await c.drain()
        #expect(try store.context.fetchCount(FetchDescriptor<TagMark>()) == 0)
        #expect(c.phases[id] == nil || c.phases[id] == TaggingPhase.none)
    }

    @Test func neverDuplicatesExistingLabels() async throws {
        let engine = RecordingEngine(.success([SuggestedTagDraft(label: "calm", kind: .feeling, quote: nil)]))
        let (store, c) = try make(engine)
        let e = store.entry(text: "Calm.", tags: [("Calm", .feeling, nil, .kept)])
        c.enqueue(e)
        await c.drain()
        #expect(e.tags.count == 1)
        #expect(c.phase(for: e) == .done)   // already tagged: don't claim "nothing stood out"
    }
}

extension RecordingEngine {
    func setResult(_ r: Result<[SuggestedTagDraft], TaggingEngineError>) { result = r }
}

/// Engine that waits until released, to exercise "in flight" paths.
actor GateEngine: TaggingEngine {
    private(set) var calls = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    let result: [SuggestedTagDraft]
    init(result: [SuggestedTagDraft]) { self.result = result }
    func suggest(text: String, vocabulary: [String]) async throws -> [SuggestedTagDraft] {
        calls += 1
        await withCheckedContinuation { waiters.append($0) }
        return result
    }
    func release() { waiters.forEach { $0.resume() }; waiters = [] }
    var waiting: Int { waiters.count }
}

@MainActor
@Suite struct TaggingCoordinatorReviewTests {
    @Test func resumeWhileInFlightDoesNotRunTwice() async throws {
        let engine = GateEngine(result: [SuggestedTagDraft(label: "Calm", kind: .feeling, quote: "Quiet day")])
        let store = try TestStore()
        let c = TaggingCoordinator(context: store.context, engine: engine, availability: { .ready }, isEnabled: { true })
        let e = store.entry(text: "Quiet day.")
        c.enqueue(e)
        while await engine.waiting == 0 { await Task.yield() }
        c.resumePending()               // app became active while tagging
        await engine.release()
        await c.drain()
        #expect(await engine.calls == 1)
        #expect(c.phase(for: e) == .done)
    }

    @Test func deletedMidRunIsIgnored() async throws {
        let engine = GateEngine(result: [SuggestedTagDraft(label: "Calm", kind: .feeling, quote: "Quiet day")])
        let store = try TestStore()
        let c = TaggingCoordinator(context: store.context, engine: engine, availability: { .ready }, isEnabled: { true })
        let e = store.entry(text: "Quiet day.")
        c.enqueue(e)
        while await engine.waiting == 0 { await Task.yield() }
        store.context.delete(e)
        try store.context.save()
        await engine.release()
        await c.drain()
        #expect(try store.context.fetchCount(FetchDescriptor<TagMark>()) == 0)
    }

    @Test func rerunWithOnlyDuplicatesKeepsDone() async throws {
        let store = try TestStore()
        let engine = RecordingEngine(.success([SuggestedTagDraft(label: "Calm", kind: .feeling, quote: "Quiet day")]))
        let c = TaggingCoordinator(context: store.context, engine: engine, availability: { .ready }, isEnabled: { true })
        let e = store.entry(text: "Quiet day.", tags: [("Calm", .feeling, "Quiet day", .suggested)])
        c.retry(e)
        await c.drain()
        #expect(c.phase(for: e) == .done)
    }

    @Test func newSuggestionsDontOverlapExistingHighlights() async throws {
        let store = try TestStore()
        let engine = RecordingEngine(.success([SuggestedTagDraft(label: "Tired", kind: .feeling, quote: "Quiet day")]))
        let c = TaggingCoordinator(context: store.context, engine: engine, availability: { .ready }, isEnabled: { true })
        let e = store.entry(text: "Quiet day.", tags: [("Calm", .feeling, "Quiet day", .kept)])
        c.retry(e)
        await c.drain()
        #expect(e.tags.count == 1)
    }
}

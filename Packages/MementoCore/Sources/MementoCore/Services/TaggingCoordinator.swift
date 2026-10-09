import Foundation
import Observation
import SwiftData

public enum TaggingPhase: Equatable, Sendable {
    case running, failed, none, unavailable, unsupported, off, done
}

/// Runs tagging after save, one entry at a time, and records each entry's phase (spec §5.2).
@MainActor
@Observable
public final class TaggingCoordinator {
    public static let maxCharacters = 6_000

    public private(set) var phases: [UUID: TaggingPhase] = [:]
    @ObservationIgnored public var engine: any TaggingEngine
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let availability: () -> AIAvailability
    @ObservationIgnored private let isEnabled: () -> Bool
    @ObservationIgnored private var queue: [UUID] = []
    @ObservationIgnored private var worker: Task<Void, Never>?
    /// The entry the model is working on right now; never queued twice.
    @ObservationIgnored private var inFlight: UUID?

    public init(context: ModelContext, engine: any TaggingEngine,
                availability: @escaping () -> AIAvailability, isEnabled: @escaping () -> Bool) {
        self.context = context
        self.engine = engine
        self.availability = availability
        self.isEnabled = isEnabled
    }

    public func phase(for entry: Entry) -> TaggingPhase {
        phases[entry.id] ?? (entry.tagging == .failed ? .failed : .done)
    }

    public func enqueue(_ entry: Entry) {
        if inFlight == entry.id || queue.contains(entry.id) { return }
        if let gate = gate() {
            phases[entry.id] = gate
            if gate == .off || gate == .unsupported { entry.tagging = .skipped }
            save()
            return
        }
        phases[entry.id] = .running
        entry.tagging = .pending
        save()
        queue.append(entry.id)
        startWorker()
    }

    public func retry(_ entry: Entry) {
        phases[entry.id] = nil
        enqueue(entry)
    }

    /// Re-queues entries saved while the app was killed or AI wasn't ready.
    public func resumePending() {
        let pending = (try? context.fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.taggingRaw == "pending" }))) ?? []
        for entry in pending { enqueue(entry) }
    }

    /// Waits until the queue is empty (tests and previews).
    public func drain() async {
        while let w = worker { await w.value }
    }

    private func gate() -> TaggingPhase? {
        guard isEnabled() else { return .off }
        switch availability() {
        case .ready: return nil
        case .unsupported: return .unsupported
        case .needsAppleIntelligence, .preparing: return .unavailable
        }
    }

    private func startWorker() {
        guard worker == nil else { return }
        worker = Task { [weak self] in
            while let self, !self.queue.isEmpty {
                let id = self.queue.removeFirst()
                self.inFlight = id
                await self.process(id)
                self.inFlight = nil
            }
            self?.worker = nil
        }
    }

    private func process(_ id: UUID) async {
        guard let entry = fetch(id) else { phases[id] = nil; return }
        let text = String(entry.text.prefix(Self.maxCharacters))
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { finish(entry, .none, .done); return }
        let vocabulary = TagIndex(entries: allEntries()).topLabels(30)
        do {
            let drafts = try await engine.suggest(text: text, vocabulary: vocabulary)
            guard let entry = fetch(id) else { phases[id] = nil; return }
            let existing = Set(entry.tags.map { $0.label.lowercased() })
            let clean = SuggestionSanitizer.sanitize(drafts, text: entry.text, existingLabels: existing,
                                                     reservedQuotes: entry.visibleTags.compactMap(\.quote))
            guard !clean.isEmpty else {
                // A re-run that only repeats what's already there isn't "nothing stood out".
                let hasModelTags = entry.visibleTags.contains { !$0.isManual }
                finish(entry, hasModelTags ? .done : .none, .done)
                return
            }
            for d in clean { entry.addTag(label: d.label, kind: d.kind, quote: d.quote, status: .suggested) }
            finish(entry, .done, .done)
        } catch TaggingEngineError.nothingToSuggest {
            if let entry = fetch(id) { finish(entry, .none, .done) } else { phases[id] = nil }
        } catch {
            if let entry = fetch(id) { finish(entry, .failed, .failed) } else { phases[id] = nil }
        }
    }

    private func finish(_ entry: Entry, _ phase: TaggingPhase, _ status: TaggingStatus) {
        phases[entry.id] = phase
        entry.tagging = status
        save()
    }

    private func fetch(_ id: UUID) -> Entry? {
        try? context.fetch(FetchDescriptor<Entry>(predicate: #Predicate { $0.id == id })).first
    }

    private func allEntries() -> [Entry] {
        (try? context.fetch(FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
    }

    private func save() { try? context.save() }
}

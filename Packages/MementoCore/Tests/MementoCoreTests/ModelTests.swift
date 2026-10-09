import Testing
import SwiftData
@testable import MementoCore

@MainActor
@Suite struct ModelTests {
    @Test func tagsKeepInsertionOrderAndFilterByStatus() throws {
        let store = try TestStore()
        let e = store.entry(text: "I felt drained. A walk helped.", tags: [
            ("Drained", .feeling, "I felt drained", .kept),
            ("Walking helped", .helped, "A walk helped", .suggested),
            ("Old", .topic, nil, .removed),
        ])
        try store.context.save()
        #expect(e.orderedTags.map(\.label) == ["Drained", "Walking helped", "Old"])
        #expect(e.keptTags.map(\.label) == ["Drained"])
        #expect(e.suggestedTags.map(\.label) == ["Walking helped"])
        #expect(e.visibleTags.count == 2)
        #expect(e.quoteMarks.map(\.quote) == ["I felt drained", "A walk helped"])
        #expect(e.hasKept(label: "drained"))
    }

    @Test func enumsRoundTripThroughRawStorage() throws {
        let store = try TestStore()
        let e = store.entry(notebook: "refl", mode: .sol)
        e.tagging = .failed
        #expect(e.mode == .sol)
        #expect(e.tagging == .failed)
        #expect(e.notebook.name == "Reflections")
        #expect(Notebook.with(id: "nope") == .daily)
    }

    @Test func deletingEntryCascadesToTags() throws {
        let store = try TestStore()
        store.entry(tags: [("Calm", .feeling, nil, .kept)])
        try store.context.save()
        try store.context.delete(model: Entry.self)
        try store.context.save()
        #expect(try store.context.fetchCount(FetchDescriptor<TagMark>()) == 0)
    }
}

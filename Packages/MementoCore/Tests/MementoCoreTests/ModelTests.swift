import Testing
import Foundation
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

    @Test func addingAnExistingLabelKeepsTheOriginal() throws {
        let store = try TestStore()
        let e = store.entry(text: "Tired.", tags: [("Drained", .feeling, "Tired", .suggested)])
        let tag = e.addOrKeepTag(label: "drained", kind: .feeling)
        #expect(e.visibleTags.count == 1)
        #expect(tag.status == .kept)
        #expect(tag.quote == "Tired")
    }

    @Test func renamingIntoAnExistingLabelMerges() throws {
        let store = try TestStore()
        let e = store.entry(text: "Tired. Walked.", tags: [("Drained", .feeling, "Tired", .kept), ("Rest", .helped, "Walked", .suggested)])
        let rest = e.orderedTags[1]
        e.applyEdit(to: rest, label: "drained", kind: .feeling)
        #expect(e.visibleTags.map(\.label) == ["Drained"])
        #expect(rest.status == .removed)
    }

    @Test func entryKeepsPaintedArt() throws {
        let store = try TestStore()
        let e = store.entry(text: "A walk.")
        #expect(e.artData == nil)
        e.artData = Data([1, 2, 3])
        try store.context.save()
        #expect(try store.all().first?.artData == Data([1, 2, 3]))
    }
}

import Foundation
import SwiftData
import MementoCore

/// Tag and entry mutations that show a toast with Undo (prototype keep/removeTag/keepAll/moveTo).
enum EntryActions {
    static func keep(_ tag: TagMark, context: ModelContext) {
        tag.status = .kept
        try? context.save()
    }

    static func remove(_ tag: TagMark, app: AppModel, context: ModelContext) {
        let previous = tag.status
        tag.status = .removed
        try? context.save()
        app.showToast("Removed “\(tag.label)”") {
            tag.status = previous
            try? context.save()
        }
    }

    static func keepAll(_ entry: Entry, app: AppModel, context: ModelContext) {
        let tags = entry.suggestedTags
        guard !tags.isEmpty else { return }
        tags.forEach { $0.status = .kept }
        try? context.save()
        app.showToast("Kept \(tags.count) \(tags.count == 1 ? "tag" : "tags")") {
            tags.forEach { $0.status = .suggested }
            try? context.save()
        }
    }

    static func move(_ entry: Entry, to notebookID: String, app: AppModel, context: ModelContext) {
        let previous = entry.notebookID
        guard previous != notebookID else { return }
        entry.notebookID = notebookID
        try? context.save()
        app.showToast("Moved to \(Notebook.with(id: notebookID).name)") {
            entry.notebookID = previous
            try? context.save()
        }
    }
}

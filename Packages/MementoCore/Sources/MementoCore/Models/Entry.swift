import Foundation
import SwiftData

@Model
public final class Entry {
    @Attribute(.unique) public var id: UUID
    public var createdAt: Date
    public var notebookID: String
    public var modeRaw: String
    /// Guided prompt shown while writing, if any.
    public var prompt: String?
    public var text: String
    @Attribute(.externalStorage) public var photoData: Data?
    /// An on-device Image Playground illustration of the entry ("Paint this day").
    @Attribute(.externalStorage) public var artData: Data?
    public var taggingRaw: String
    @Relationship(deleteRule: .cascade, inverse: \TagMark.entry)
    public var tags: [TagMark] = []

    public init(id: UUID = UUID(), createdAt: Date = .now, notebookID: String = Notebook.daily.id,
                mode: WritingMode = .free, prompt: String? = nil, text: String,
                photoData: Data? = nil, tagging: TaggingStatus = .pending) {
        self.id = id
        self.createdAt = createdAt
        self.notebookID = notebookID
        self.modeRaw = mode.rawValue
        self.prompt = prompt
        self.text = text
        self.photoData = photoData
        self.taggingRaw = tagging.rawValue
    }

    public var mode: WritingMode {
        get { WritingMode(rawValue: modeRaw) ?? .free }
        set { modeRaw = newValue.rawValue }
    }

    public var tagging: TaggingStatus {
        get { TaggingStatus(rawValue: taggingRaw) ?? .done }
        set { taggingRaw = newValue.rawValue }
    }

    public var notebook: Notebook { Notebook.with(id: notebookID) }

    public var orderedTags: [TagMark] { tags.sorted { $0.position < $1.position } }
    public var suggestedTags: [TagMark] { orderedTags.filter { $0.status == .suggested } }
    public var keptTags: [TagMark] { orderedTags.filter { $0.status == .kept } }
    public var visibleTags: [TagMark] { orderedTags.filter { $0.status != .removed } }

    public var quoteMarks: [QuoteMark] {
        visibleTags.compactMap { tag in
            tag.quote.map { QuoteMark(id: tag.id, kind: tag.kind, status: tag.status, quote: $0) }
        }
    }

    public func hasKept(label: String) -> Bool {
        keptTags.contains { $0.label.caseInsensitiveCompare(label) == .orderedSame }
    }

    /// Adds a writer's tag, or keeps the existing one with the same label (never two identical chips).
    @discardableResult
    public func addOrKeepTag(label: String, kind: TagKind) -> TagMark {
        if let existing = tags.first(where: { $0.label.caseInsensitiveCompare(label) == .orderedSame }) {
            if existing.status == .removed { existing.kind = kind; existing.isManual = true }
            existing.status = .kept
            return existing
        }
        return addTag(label: label, kind: kind, status: .kept, isManual: true)
    }

    /// Applies a rename/re-kind; renaming into another visible tag's label merges into that tag.
    public func applyEdit(to tag: TagMark, label: String, kind: TagKind) {
        if let other = visibleTags.first(where: { $0.id != tag.id && $0.label.caseInsensitiveCompare(label) == .orderedSame }) {
            other.status = .kept
            tag.status = .removed
            return
        }
        tag.label = label
        tag.kind = kind
        tag.status = .kept
        tag.isEdited = true
    }

    @discardableResult
    public func addTag(label: String, kind: TagKind, quote: String? = nil,
                       status: TagStatus = .kept, isManual: Bool = false) -> TagMark {
        let position = (tags.map(\.position).max() ?? -1) + 1
        let tag = TagMark(label: label, kind: kind, quote: quote, status: status, isManual: isManual, position: position)
        modelContext?.insert(tag)
        tags.append(tag)
        return tag
    }
}

/// A tag's quote located for highlighting, decoupled from SwiftData.
public struct QuoteMark: Hashable, Sendable {
    public let id: UUID
    public let kind: TagKind
    public let status: TagStatus
    public let quote: String

    public init(id: UUID, kind: TagKind, status: TagStatus, quote: String) {
        self.id = id
        self.kind = kind
        self.status = status
        self.quote = quote
    }
}

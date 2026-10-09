import Foundation
import SwiftData

@Model
public final class TagMark {
    @Attribute(.unique) public var id: UUID
    public var label: String
    public var kindRaw: String
    /// Verbatim substring of the entry text, or nil for tags without a quote.
    public var quote: String?
    public var statusRaw: String
    public var isManual: Bool
    /// Renamed or re-kinded by the writer; never overwritten by suggestions.
    public var isEdited: Bool
    /// Stable display order within the entry.
    public var position: Int
    public var entry: Entry?

    public init(id: UUID = UUID(), label: String, kind: TagKind, quote: String? = nil,
                status: TagStatus = .kept, isManual: Bool = false, isEdited: Bool = false, position: Int = 0) {
        self.id = id
        self.label = label
        self.kindRaw = kind.rawValue
        self.quote = quote
        self.statusRaw = status.rawValue
        self.isManual = isManual
        self.isEdited = isEdited
        self.position = position
    }

    public var kind: TagKind {
        get { TagKind(rawValue: kindRaw) ?? .topic }
        set { kindRaw = newValue.rawValue }
    }

    public var status: TagStatus {
        get { TagStatus(rawValue: statusRaw) ?? .suggested }
        set { statusRaw = newValue.rawValue }
    }
}

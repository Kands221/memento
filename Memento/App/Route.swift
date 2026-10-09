import Foundation
import MementoCore

enum AppTab: Hashable, CaseIterable {
    case journal, discover, notebooks, you
}

/// Selected entries for a new summary; nil means "last two weeks".
struct SummarySeed: Hashable {
    var ids: [UUID]?
}

enum Route: Hashable {
    case entry(UUID)
    case tag(String)
    case notebook(String)
    case reminders
    case onDeviceAI
    case summary(SummarySeed)
}

enum ActiveSheet: Identifiable, Hashable {
    case write
    case addTag(UUID)
    case editTag(entry: UUID, tag: UUID)
    case move(UUID)

    var id: Self { self }
}

extension WritingMode: @retroactive Identifiable {
    public var id: String { rawValue }
}

import Foundation

public enum TagKind: String, Codable, CaseIterable, Sendable {
    case feeling, situation, helped, topic

    /// Label under a suggestion row ("Feeling", "What helped").
    public var singular: String {
        switch self {
        case .feeling: "Feeling"
        case .situation: "Situation"
        case .helped: "What helped"
        case .topic: "Topic"
        }
    }

    /// Discover group titles, tag-detail eyebrow and summary sections.
    public var plural: String {
        switch self {
        case .feeling: "Feelings"
        case .situation: "Situations"
        case .helped: "What helped"
        case .topic: "Topics"
        }
    }

    /// Segmented control in the tag form sheet.
    public var shortLabel: String {
        switch self {
        case .feeling: "Feeling"
        case .situation: "Situation"
        case .helped: "Helped"
        case .topic: "Topic"
        }
    }
}

public enum TagStatus: String, Codable, Sendable {
    case suggested, kept, removed
}

public enum WritingMode: String, Codable, CaseIterable, Sendable {
    case free, dump, guided, photo, sol

    public var title: String {
        switch self {
        case .free: "Write freely"
        case .dump: "Brain dump"
        case .guided: "Guided reflection"
        case .photo: "Photo journal"
        case .sol: "Sol reflection"
        }
    }
}

public enum TaggingStatus: String, Codable, Sendable {
    case pending, done, failed, skipped
}

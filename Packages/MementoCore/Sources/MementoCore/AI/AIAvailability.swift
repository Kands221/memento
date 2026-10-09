import FoundationModels

/// The system model's state, mapped onto the prototype's AI states (spec §5.1).
public enum AIAvailability: String, CaseIterable, Sendable {
    case ready, needsAppleIntelligence, preparing, unsupported

    public var isSupported: Bool { self != .unsupported }

    public static func live() -> AIAvailability {
        switch SystemLanguageModel.default.availability {
        case .available: .ready
        case .unavailable(.appleIntelligenceNotEnabled): .needsAppleIntelligence
        case .unavailable(.modelNotReady): .preparing
        case .unavailable: .unsupported
        }
    }
}

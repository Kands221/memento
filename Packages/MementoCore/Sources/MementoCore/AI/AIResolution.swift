import Foundation

/// Demo override for on-stage previews of every AI state (spec D23).
public enum DemoAIState: String, CaseIterable, Sendable {
    case live, needsAppleIntelligence, preparing, unsupported, failing

    public var title: String {
        switch self {
        case .live: "Live"
        case .needsAppleIntelligence: "Not set up"
        case .preparing: "Getting ready"
        case .unsupported: "Unsupported"
        case .failing: "Tagging fails"
        }
    }
}

/// Resolves what each AI feature can do, given the live model, the demo override and the selected engine.
/// Tagging and Sol resolve separately: a backup engine for one must not unlock the other.
public enum AIResolution {
    static func overridden(_ override: DemoAIState) -> AIAvailability? {
        switch override {
        case .live: nil
        case .needsAppleIntelligence: .needsAppleIntelligence
        case .preparing: .preparing
        case .unsupported: .unsupported
        case .failing: .ready
        }
    }

    /// `cloud`: the cloud fallback engine is in use, so no on-device model is needed.
    public static func tagging(live: AIAvailability, override: DemoAIState, demoTagging: Bool, cloud: Bool = false) -> AIAvailability {
        overridden(override) ?? (demoTagging || cloud ? .ready : live)
    }

    public static func sol(live: AIAvailability, override: DemoAIState, demoSol: Bool, cloud: Bool = false) -> AIAvailability {
        overridden(override) ?? (demoSol || cloud ? .ready : live)
    }
}

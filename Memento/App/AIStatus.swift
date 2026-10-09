import Foundation
import Observation
import MementoCore

/// Live Apple Intelligence state with the Demo override layered on top (spec D23).
@Observable
final class AIStatus {
    private(set) var live: AIAvailability = AIStatus.probe()

    /// `-simulateNoOnDeviceAI` makes this device behave like one without Apple Intelligence (e.g. iPhone 12),
    /// to exercise the cloud fallback in the simulator.
    private static func probe() -> AIAvailability {
        ProcessInfo.processInfo.arguments.contains("-simulateNoOnDeviceAI") ? .unsupported : AIAvailability.live()
    }
    var demoState: DemoAIState {
        didSet {
            UserDefaults.standard.set(demoState.rawValue, forKey: SettingsKey.demoAIState)
            onChange?()
        }
    }
    /// True when the deterministic demo engines are selected; they need no model.
    @ObservationIgnored var isDemoEngine: () -> Bool = { false }
    /// True when tagging runs on the cloud fallback; it needs no on-device model either.
    @ObservationIgnored var isCloudEngine: () -> Bool = { false }
    /// Bumped when engine choices change so views re-read `availability`.
    var revision = 0
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var poll: Task<Void, Never>?

    init(override: DemoAIState?) {
        demoState = override
            ?? DemoAIState(rawValue: UserDefaults.standard.string(forKey: SettingsKey.demoAIState) ?? "")
            ?? .live
    }

    /// What tagging can do (the demo rules engine needs no model).
    var availability: AIAvailability {
        _ = revision
        return AIResolution.tagging(live: live, override: demoState, demoTagging: isDemoEngine(), cloud: isCloudEngine())
    }

    var label: String {
        switch availability {
        case .ready: "Ready"
        case .needsAppleIntelligence: "Not set up"
        case .preparing: "Getting ready"
        case .unsupported: "Not available"
        }
    }

    func refresh() {
        let previous = availability
        live = Self.probe()
        if availability != previous { onChange?() }
        poll?.cancel()
        guard live == .preparing else { return }
        poll = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }
}

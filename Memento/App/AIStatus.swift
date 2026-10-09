import Foundation
import Observation
import MementoCore

/// Live Apple Intelligence state with the Demo override layered on top (spec D23).
@Observable
final class AIStatus {
    private(set) var live: AIAvailability = AIAvailability.live()
    var demoState: DemoAIState {
        didSet {
            UserDefaults.standard.set(demoState.rawValue, forKey: SettingsKey.demoAIState)
            onChange?()
        }
    }
    /// True when the deterministic demo engines are selected; they need no model.
    @ObservationIgnored var isDemoEngine: () -> Bool = { false }
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var poll: Task<Void, Never>?

    init(override: DemoAIState?) {
        demoState = override
            ?? DemoAIState(rawValue: UserDefaults.standard.string(forKey: SettingsKey.demoAIState) ?? "")
            ?? .live
    }

    var availability: AIAvailability {
        switch demoState {
        case .live: live != .ready && isDemoEngine() ? .ready : live
        case .needsAppleIntelligence: .needsAppleIntelligence
        case .preparing: .preparing
        case .unsupported: .unsupported
        case .failing: .ready
        }
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
        live = AIAvailability.live()
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

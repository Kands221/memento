import SwiftUI

enum SettingsKey {
    static let hasOnboarded = "hasOnboarded"
    static let suggestTags = "suggestTags"
    static let solEnabled = "solEnabled"
    static let appearance = "appearance"
    static let reminderOn = "reminderOn"
    static let reminderMinutes = "reminderMinutes"
    static let preparedBy = "preparedBy"
    static let demoAIState = "demoAIState"
    static let demoTaggingEngine = "demoTaggingEngine"
    static let demoSolEngine = "demoSolEngine"
    /// Use cloud AI (OpenRouter) when this iPhone can't run on-device AI.
    static let cloudFallback = "cloudFallback"
}

enum Appearance: String, CaseIterable {
    case system, light, dark

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

import Foundation

/// Fallback reflection built only from the writer's words (prototype makeReflection).
public enum ReflectionTemplate {
    public static let closingPrompt = "One thing I'd like to try this week: "

    public static func make(userMessages: [String]) -> String {
        let cleaned = userMessages.map { lowerFirst($0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))) }
        var text = "Tonight I talked through \(cleaned.first ?? "my day")."
        if cleaned.count > 1 {
            text += "\n\nWhat came up after that: \(cleaned.dropFirst().joined(separator: "; "))."
        }
        return text + "\n\n" + closingPrompt
    }

    static func lowerFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        if s.hasPrefix("I ") || s.hasPrefix("I'") || s == "I" { return s }
        return first.lowercased() + s.dropFirst()
    }
}

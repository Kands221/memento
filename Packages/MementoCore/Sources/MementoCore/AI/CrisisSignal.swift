import Foundation

/// Offline safety net for Sol (spec D17): crisis language shows the Support card instead of a model reply.
public enum CrisisSignal {
    static let patterns = [
        #"\bkill(?:ing)? myself\b"#, #"\bsuicid"#, #"\bend (?:it all|my life)\b"#, #"\bself[- ]?harm"#,
        #"\bhurt(?:ing)? myself\b"#, #"\bwant(?:ed)? to die\b"#, #"\bdon'?t want to (?:be alive|live|be here)\b"#,
        #"\bcut(?:ting)? myself\b"#,
    ]

    public static let supportMessage = "It sounds like you’re carrying something really heavy, and you deserve support from a person right now. If you might act on these thoughts, call your local emergency number. In the US you can call or text 988, any time."

    public static func matches(_ text: String) -> Bool {
        patterns.contains { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }
}

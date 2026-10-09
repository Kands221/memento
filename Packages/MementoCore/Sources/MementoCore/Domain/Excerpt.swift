import Foundation

public enum Excerpt {
    /// Single-line preview: newlines flattened, cut at a word boundary with an ellipsis.
    public static func make(_ text: String, limit: Int = 110) -> String {
        let flat = text.replacingOccurrences(of: "\\n+", with: " ", options: .regularExpression)
        guard flat.count > limit else { return flat }
        var cut = String(flat.prefix(limit - 2))
        if let r = cut.range(of: "\\s+\\S*$", options: .regularExpression) { cut.removeSubrange(r) }
        return cut + "…"
    }
}

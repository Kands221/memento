import SwiftUI
import UIKit

/// Variable-font helpers: Newsreader with optical sizing, JetBrains Mono, and SF for UI text.
/// All sizes scale with Dynamic Type through `UIFontMetrics`.
extension Font {
    private static let weightAxis = 0x7767_6874 // 'wght'
    private static let opticalAxis = 0x6F70_737A // 'opsz'

    private static func variable(_ postScriptName: String, size: CGFloat, style: UIFont.TextStyle, axes: [Int: CGFloat]) -> Font {
        let base = UIFont(name: postScriptName, size: size) ?? .systemFont(ofSize: size)
        let key = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let font = UIFont(descriptor: base.fontDescriptor.addingAttributes([key: axes]), size: size)
        return Font(UIFontMetrics(forTextStyle: style).scaledFont(for: font))
    }

    /// Newsreader, optical size matched to the point size (6–72).
    static func serif(_ size: CGFloat, relativeTo style: UIFont.TextStyle = .body, italic: Bool = false, weight: CGFloat = 400) -> Font {
        variable(italic ? "Newsreader16pt-Italic" : "Newsreader16pt-Regular", size: size, style: style,
                 axes: [weightAxis: weight, opticalAxis: min(max(size, 6), 72)])
    }

    /// SF Pro for interface text.
    static func ui(_ size: CGFloat, relativeTo style: UIFont.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        .system(size: UIFontMetrics(forTextStyle: style).scaledValue(for: size), weight: weight)
    }

    /// JetBrains Mono for eyebrows that need it and the brain-dump timer.
    static func mono(_ size: CGFloat, relativeTo style: UIFont.TextStyle = .body, weight: CGFloat = 500) -> Font {
        variable("JetBrainsMono-Regular", size: size, style: style, axes: [weightAxis: weight])
    }
}

/// Uppercase tracked label ("TONIGHT", "SUGGESTED · 3").
struct Eyebrow: View {
    let text: String
    var color: Color = .mMut

    init(_ text: String, color: Color = .mMut) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.ui(12, relativeTo: .caption1, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(color)
    }
}

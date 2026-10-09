import SwiftUI
import MementoCore

/// Dashed = suggested, filled = kept (prototype chipSt).
struct TagChip: View {
    enum Size { case small, regular }

    let label: String
    let kind: TagKind
    var status: TagStatus = .kept
    var size: Size = .regular
    /// Shown after the label at 0.7 opacity ("Walking helped 3").
    var count: String?

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
            if let count { Text(count).fontWeight(.regular).opacity(0.7) }
        }
        .font(.ui(size == .small ? 12 : 14, relativeTo: .footnote, weight: .medium))
        .lineLimit(1)
        .padding(.vertical, size == .small ? 4 : 7)
        .padding(.horizontal, size == .small ? 9 : 12)
        .foregroundStyle(kind.color)
        .background {
            if status == .suggested {
                Capsule().strokeBorder(kind.color, style: StrokeStyle(lineWidth: 1, dash: [3, 2.5]))
            } else {
                Capsule().fill(kind.tint)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(status == .suggested ? "suggested" : "kept")
    }
}

/// Neutral filter / preset chip (prototype fchip).
struct FilterChip: View {
    let label: String
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.ui(14, relativeTo: .subheadline, weight: .medium))
                .lineLimit(1)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .foregroundStyle(isOn ? Color.mBg : Color.mInk)
                .background(Capsule().fill(isOn ? Color.mInk : Color.mCard))
                .overlay(Capsule().strokeBorder(isOn ? Color.mInk : Color.mLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

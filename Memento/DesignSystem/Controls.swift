import SwiftUI

/// iOS-style segmented control drawn like the prototype (segSt).
struct SegmentedPill<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let on = option.value == selection
                Button { selection = option.value } label: {
                    Text(option.label)
                        .font(.ui(13, relativeTo: .footnote, weight: on ? .semibold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .foregroundStyle(Color.mInk)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 9).fill(Color.mCard)
                                    .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.mLine))
    }
}

/// Sage switch (prototype sw): 51×31 track, 27 pt knob.
struct SageToggleStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 12)
            Capsule()
                .fill(configuration.isOn ? Color.mSage : Color.mLine)
                .frame(width: 51, height: 31)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle().fill(.white).frame(width: 27, height: 27).padding(2)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 2)
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: configuration.isOn)
                .onTapGesture { configuration.isOn.toggle() }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .accessibilityAction { configuration.isOn.toggle() }
    }
}

/// Terracotta full-width primary action (54 pt, radius 16).
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(17, relativeTo: .headline, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(isEnabled ? Color.mOnTer : Color.mMut)
            .background(RoundedRectangle(cornerRadius: 16).fill(isEnabled ? Color.mTer : Color.mLine))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Ink-filled action (download, retry, gate CTAs).
struct InkButtonStyle: ButtonStyle {
    var height: CGFloat = 46
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(15, relativeTo: .subheadline, weight: .semibold))
            .padding(.horizontal, 18)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: height)
            .foregroundStyle(Color.mBg)
            .background(RoundedRectangle(cornerRadius: 13).fill(Color.mInk))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Outlined action (1.5 pt border) used for "Find the details" and "Summarize these…".
struct OutlineButtonStyle: ButtonStyle {
    var color: Color = .mInk
    var height: CGFloat = 52

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(16, relativeTo: .callout, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(color)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(color, lineWidth: 1.5))
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Small rounded pill (Keep, Write freely, Start timer).
struct PillButtonStyle: ButtonStyle {
    var fill: Color = .mCard
    var foreground: Color = .mInk
    var border: Color? = .mLine
    var dashed = false
    var height: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(15, relativeTo: .subheadline, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 16)
            .frame(minHeight: height)
            .foregroundStyle(foreground)
            .background(Capsule().fill(fill))
            .overlay {
                if let border {
                    Capsule().strokeBorder(border, style: StrokeStyle(lineWidth: 1, dash: dashed ? [4, 3] : []))
                }
            }
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Text-only terracotta action ("+ Add a tag", "Another prompt").
struct LinkButtonStyle: ButtonStyle {
    var color: Color = .mTer
    var size: CGFloat = 15

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(size, relativeTo: .subheadline, weight: .semibold))
            .foregroundStyle(color)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Indeterminate sage progress bar ("Getting ready…"). Static under Reduce Motion.
struct IndeterminateBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -0.4

    var body: some View {
        GeometryReader { geo in
            Capsule().fill(Color.mLine)
                .overlay(alignment: .leading) {
                    Capsule().fill(Color.mSage)
                        .frame(width: geo.size.width * 0.4)
                        .offset(x: reduceMotion ? 0 : geo.size.width * phase)
                }
                .clipShape(Capsule())
        }
        .frame(height: 6)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { phase = 1 }
        }
        .accessibilityLabel("In progress")
    }
}

/// Small coloured dot used for "Reading the entry…" and bullet lists.
struct Dot: View {
    var color: Color = .mSage
    var size: CGFloat = 8
    var body: some View { Circle().fill(color).frame(width: size, height: size) }
}

/// 44 pt circular icon button (✕ on suggestion rows).
struct CircleIconButtonStyle: ButtonStyle {
    var size: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.mMut)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.mCard))
            .overlay(Circle().strokeBorder(Color.mLine, lineWidth: 1))
            .contentShape(Circle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

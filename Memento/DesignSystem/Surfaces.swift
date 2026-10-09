import SwiftUI

extension View {
    /// Cream card with a hairline border (prototype card surfaces).
    func paperCard(radius: CGFloat = 20, padding: CGFloat = 16, fill: Color = .mCard) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color.mLine, lineWidth: 1))
    }

    /// Dashed outline for "unreviewed" rows and empty-ish states.
    func dashedBorder(radius: CGFloat = 18, color: Color = .mMut) -> some View {
        overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(color, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }
}

/// Grouped settings list card (You, Reminders, On-device AI).
struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { subviews in
                ForEach(Array(subviews.enumerated()), id: \.offset) { index, subview in
                    if index > 0 { Rectangle().fill(Color.mLine).frame(height: 1).padding(.leading, 16) }
                    subview
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.mCard))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.mLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// A tappable settings row with optional trailing value and chevron.
struct SettingsRow: View {
    let title: String
    var subtitle: String?
    var value: String?
    var showsChevron = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.ui(17)).foregroundStyle(Color.mInk)
                    if let subtitle { Text(subtitle).font(.ui(13, relativeTo: .footnote)).foregroundStyle(Color.mMut) }
                }
                Spacer(minLength: 8)
                if let value { Text(value).font(.ui(16)).foregroundStyle(Color.mMut) }
                if showsChevron { Image(systemName: "chevron.right").font(.ui(14, weight: .semibold)).foregroundStyle(Color.mMut) }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Scrolling page body: bg colour, 20 pt gutter, room for the tab bar.
struct Screen<Content: View>: View {
    var spacing: CGFloat = 18
    var horizontalPadding: CGFloat = 20
    var bottomPadding: CGFloat = 130
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) { content }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 6)
                .padding(.bottom, bottomPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(Color.mBg.ignoresSafeArea())
    }
}

/// Serif page title (36 pt, -0.015em).
struct PageTitle: View {
    let text: String
    var size: CGFloat = 36

    init(_ text: String, size: CGFloat = 36) {
        self.text = text
        self.size = size
    }

    var body: some View {
        Text(text).font(.serif(size, relativeTo: .largeTitle)).tracking(-0.5).foregroundStyle(Color.mInk)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Wrapping row for chips: lays children left to right, wrapping at the container width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for (index, size) in row.items {
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row { var items: [(Int, CGSize)] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for (index, subview) in subviews.enumerated() {
            var size = subview.sizeThatFits(.unspecified)
            size.width = min(size.width, width)
            let needed = rows[rows.count - 1].items.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].items.isEmpty {
                rows.append(Row())
            }
            var row = rows.removeLast()
            row.width = row.items.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.items.append((index, size))
            rows.append(row)
        }
        return rows.filter { !$0.items.isEmpty }
    }
}

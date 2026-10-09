import SwiftUI
import MementoCore

struct TagMarkAttribute: TextAttribute {
    let kind: TagKind
    let status: TagStatus
    let isActive: Bool
}

struct TagMarkRenderer: TextRenderer {
    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        for line in layout {
            for run in line {
                if let mark = run[TagMarkAttribute.self] {
                    let bounds = run.typographicBounds
                    let r = bounds.rect
                    if mark.isActive {
                        ctx.fill(Path(roundedRect: r.insetBy(dx: -3, dy: -1), cornerRadius: 3), with: .color(mark.kind.tint))
                    } else if mark.status == .kept {
                        let h = r.height * 0.38
                        ctx.fill(Path(CGRect(x: r.minX, y: r.maxY - h, width: r.width, height: h)), with: .color(mark.kind.tint))
                    } else {
                        var p = Path()
                        let y = bounds.origin.y + max(2, bounds.descent * 0.6)
                        p.move(to: CGPoint(x: r.minX, y: y))
                        p.addLine(to: CGPoint(x: r.maxX, y: y))
                        ctx.stroke(p, with: .color(mark.kind.color), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                }
                ctx.draw(run)
            }
        }
    }
}

/// Entry text with tappable, highlighted quotes. Taps report the tag id.
struct AnnotatedText: View {
    let segments: [TextSegment]
    var activeID: UUID?
    var font: Font = .serif(21, relativeTo: .body)
    var lineSpacing: CGFloat = 8
    var onTap: (UUID) -> Void = { _ in }

    var body: some View {
        segments.reduce(Text(verbatim: "")) { acc, seg in
            guard let mark = seg.mark else { return Text("\(acc)\(Text(verbatim: seg.text))") }
            var s = AttributedString(seg.text)
            s.link = URL(string: "memento://tag/\(mark.id.uuidString)")
            let piece = Text(s).customAttribute(TagMarkAttribute(kind: mark.kind, status: mark.status, isActive: mark.id == activeID))
            return Text("\(acc)\(piece)")
        }
        .font(font)
        .lineSpacing(lineSpacing)
        .foregroundStyle(Color.mInk)
        .tint(Color.mInk)
        .textRenderer(TagMarkRenderer())
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme == "memento", url.host() == "tag", let id = UUID(uuidString: url.lastPathComponent) { onTap(id) }
            return .handled
        })
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

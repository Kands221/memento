import CoreText
import UIKit
import MementoCore

/// Paginated PDFs for summaries and journal export (spec D15). Files stay local until shared.
enum PDFComposer {
    static let page = CGRect(x: 0, y: 0, width: 612, height: 792)
    static let margin: CGFloat = 54

    static func render(_ text: NSAttributedString) -> Data {
        UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            let framesetter = CTFramesetterCreateWithAttributedString(text as CFAttributedString)
            let box = CGRect(x: margin, y: margin, width: page.width - margin * 2, height: page.height - margin * 2)
            var location = 0
            repeat {
                context.beginPage()
                let cg = context.cgContext
                cg.saveGState()
                cg.textMatrix = .identity
                cg.translateBy(x: 0, y: page.height)
                cg.scaleBy(x: 1, y: -1)
                let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: location, length: 0), CGPath(rect: box, transform: nil), nil)
                CTFrameDraw(frame, cg)
                cg.restoreGState()
                let visible = CTFrameGetVisibleStringRange(frame)
                if visible.length == 0 { break }
                location += visible.length
            } while location < text.length
        }
    }

    static func pageCount(_ data: Data) -> Int {
        guard let provider = CGDataProvider(data: data as CFData), let doc = CGPDFDocument(provider) else { return 1 }
        return doc.numberOfPages
    }

    static func write(_ data: Data, name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: Documents

    static func journal(_ entries: [Entry]) -> NSAttributedString {
        let labels = DateLabels()
        let out = NSMutableAttributedString()
        out.append(line("Memento — journal export", .serif(24), ink, after: 4))
        out.append(line("\(entries.count) \(entries.count == 1 ? "entry" : "entries") · exported \(labels.fullDate(.now))", .ui(10), muted, after: 22))
        for entry in entries.sorted(by: { $0.createdAt > $1.createdAt }) {
            out.append(line("\(labels.longDay(entry.createdAt)), \(labels.time(entry.createdAt)) · \(entry.notebook.name) · \(entry.mode.title)",
                            .ui(9.5, weight: .semibold), muted, after: 4))
            if let prompt = entry.prompt { out.append(line(prompt, .serif(12, italic: true), muted, after: 4)) }
            out.append(line(entry.text, .serif(12.5), ink, after: 6, lineSpacing: 3))
            let kept = entry.keptTags.map(\.label)
            if !kept.isEmpty { out.append(line("Kept: " + kept.joined(separator: ", "), .ui(9.5), muted, after: 4)) }
            out.append(line(" ", .ui(6), ink, after: 12))
        }
        return out
    }

    static func summary(_ doc: SummaryDocument) -> NSAttributedString {
        let out = NSMutableAttributedString()
        out.append(line(doc.title, .serif(21), ink, after: 4))
        out.append(line(doc.who, .ui(10), muted, after: 2))
        out.append(line([doc.range, doc.countLine].filter { !$0.isEmpty }.joined(separator: " · "), .ui(10), muted, after: 14))
        out.append(line(doc.narrative, .ui(11), ink, after: doc.narrativeCredit == nil ? 14 : 4, lineSpacing: 3))
        if let credit = doc.narrativeCredit { out.append(line(credit, .ui(9), muted, after: 14)) }
        for group in doc.groups {
            out.append(line(group.name.uppercased(), .ui(8.5, weight: .semibold), muted, after: 2, kern: 0.7))
            out.append(line(group.items, .ui(11), ink, after: 10, lineSpacing: 2))
        }
        if doc.showQuotes, !doc.quotes.isEmpty {
            out.append(line("IN MY WORDS", .ui(8.5, weight: .semibold), muted, after: 4, kern: 0.7))
            for quote in doc.quotes {
                let row = NSMutableAttributedString(attributedString: line("\(quote.date)\t", .ui(10), muted, after: 0, newline: false))
                row.append(line("“\(quote.text)”", .serif(11.5, italic: true), ink, after: 6))
                out.append(row)
            }
            out.append(line(" ", .ui(4), ink, after: 6))
        }
        if let note = doc.note {
            out.append(line("I’D LIKE TO TALK ABOUT", .ui(8.5, weight: .semibold), muted, after: 2, kern: 0.7))
            out.append(line(note, .ui(11), ink, after: 14, lineSpacing: 2))
        }
        out.append(line(doc.footer, .ui(9), muted, after: 0, lineSpacing: 2))
        return out
    }

    // MARK: Styling

    private static let ink = UIColor(red: 0x2B / 255, green: 0x27 / 255, blue: 0x23 / 255, alpha: 1)
    private static let muted = UIColor(red: 0x6F / 255, green: 0x67 / 255, blue: 0x5D / 255, alpha: 1)

    private enum Face {
        case serif(CGFloat, italic: Bool = false)
        case ui(CGFloat, weight: UIFont.Weight = .regular)

        var font: UIFont {
            switch self {
            case let .serif(size, italic):
                UIFont(name: italic ? "Newsreader16pt-Italic" : "Newsreader16pt-Regular", size: size) ?? .systemFont(ofSize: size)
            case let .ui(size, weight):
                .systemFont(ofSize: size, weight: weight)
            }
        }
    }

    private static func line(_ text: String, _ face: Face, _ color: UIColor, after: CGFloat, lineSpacing: CGFloat = 1,
                             kern: CGFloat = 0, newline: Bool = true) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = after
        style.lineSpacing = lineSpacing
        style.tabStops = [NSTextTab(textAlignment: .left, location: 52)]
        style.headIndent = 0
        return NSAttributedString(string: text + (newline ? "\n" : ""), attributes: [
            .font: face.font, .foregroundColor: color, .paragraphStyle: style, .kern: kern,
        ])
    }
}

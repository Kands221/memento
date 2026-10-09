import SwiftUI
import MementoCore

/// The paper page shown before export (prototype L570–576). Always light: it's a printed page.
struct SummaryPaper: View {
    let doc: SummaryDocument
    private let ink = Color(hex: 0x2B2723), muted = Color(hex: 0x6F675D), rule = Color(hex: 0xE6DDCE)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.title).font(.serif(21, relativeTo: .title3)).foregroundStyle(ink)
                Text(doc.who).font(.ui(12, relativeTo: .caption1)).foregroundStyle(muted)
                Text([doc.range, doc.countLine].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.ui(12, relativeTo: .caption1)).foregroundStyle(muted)
            }
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) { Rectangle().fill(rule).frame(height: 1) }
            VStack(alignment: .leading, spacing: 6) {
                Text(doc.narrative).font(.ui(13)).foregroundStyle(ink).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                if let credit = doc.narrativeCredit {
                    Text(credit).font(.ui(11, relativeTo: .caption2).italic()).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                }
            }
            ForEach(doc.groups, id: \.name) { group in
                VStack(alignment: .leading, spacing: 2) {
                    label(group.name)
                    Text(group.items).font(.ui(13)).foregroundStyle(ink).fixedSize(horizontal: false, vertical: true)
                }
            }
            if doc.showQuotes, !doc.quotes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    label("In my words")
                    ForEach(Array(doc.quotes.enumerated()), id: \.offset) { _, quote in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(quote.date).font(.ui(12.5)).foregroundStyle(muted).frame(width: 48, alignment: .leading)
                            Text("“\(quote.text)”").font(.serif(14, italic: true)).foregroundStyle(ink).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if let note = doc.note {
                VStack(alignment: .leading, spacing: 2) {
                    label("I’d like to talk about")
                    Text(note).font(.ui(13)).foregroundStyle(ink)
                }
            }
            Text(doc.footer).font(.ui(11, relativeTo: .caption2)).foregroundStyle(muted).lineSpacing(2)
                .padding(.top, 10)
                .overlay(alignment: .top) { Rectangle().fill(rule).frame(height: 1) }
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0xFFFDF8)))
        .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
        .shadow(color: Color(red: 40 / 255, green: 25 / 255, blue: 10 / 255).opacity(0.35), radius: 15, y: 14)
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased()).font(.ui(11, relativeTo: .caption2, weight: .semibold)).tracking(0.9).foregroundStyle(muted)
    }
}

import SwiftUI
import UIKit
import MementoCore

/// Recent-entry card (prototype card()): meta, photo, excerpt, kept chips, review count.
struct EntryCard: View {
    let entry: Entry
    var showsMove = false
    @Environment(AppModel.self) private var app

    var body: some View {
        let kept = entry.keptTags
        let pending = entry.suggestedTags.count
        Button { app.openEntry(entry.id) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(DateLabels().relativeDay(entry.createdAt)) · \(entry.notebook.name)")
                    Spacer()
                    if !showsMove { Text(entry.mode.title) }
                }
                .font(.ui(12.5, relativeTo: .caption1))
                .foregroundStyle(Color.mMut)
                .padding(.trailing, showsMove ? 64 : 0)
                if let data = entry.photoData, let image = UIImage(data: data) {
                    Color.clear.frame(height: 120)
                        .overlay { Image(uiImage: image).resizable().scaledToFill() }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Text(Excerpt.make(entry.text))
                    .font(.serif(18, relativeTo: .body))
                    .foregroundStyle(Color.mInk)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                if !kept.isEmpty || pending > 0 {
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(kept.prefix(3)) { TagChip(label: $0.label, kind: $0.kind, size: .small) }
                        if kept.count > 3 {
                            Text("+\(kept.count - 3)").font(.ui(12)).foregroundStyle(Color.mMut).frame(minHeight: 22)
                        }
                        if pending > 0 {
                            Text(pending == 1 ? "1 to review" : "\(pending) to review")
                                .font(.ui(12, relativeTo: .caption1))
                                .foregroundStyle(Color.mMut)
                                .padding(.vertical, 4).padding(.horizontal, 9)
                                .overlay(Capsule().strokeBorder(Color.mMut, style: StrokeStyle(lineWidth: 1, dash: [3, 2.5])))
                        }
                    }
                }
            }
            .paperCard(radius: 20, padding: 16)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if showsMove {
                Button("Move") { app.sheet = .move(entry.id) }
                    .buttonStyle(PillButtonStyle(fill: .clear, foreground: .mInk, height: 30))
                    .font(.ui(12.5))
                    .padding(10)
            }
        }
    }
}

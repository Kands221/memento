import SwiftUI
import SwiftData
import MementoCore

/// One notebook: cover band, search, kept-tag filters and moving entries (prototype L387–404).
struct NotebookDetailView: View {
    let notebookID: String
    @Query(sort: \Entry.createdAt, order: .reverse) private var all: [Entry]
    @State private var query = ""
    @State private var filter: String?

    var body: some View {
        let notebook = Notebook.with(id: notebookID)
        let inNotebook = all.filter { $0.notebookID == notebookID }
        let labels = keptLabels(inNotebook)
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let list = inNotebook.filter { entry in
            (filter.map(entry.hasKept(label:)) ?? true)
                && (q.isEmpty || entry.text.lowercased().contains(q) || entry.tags.contains { $0.label.lowercased().contains(q) })
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Color(hex: notebook.coverHex)
                    if let image = UIImage(named: notebook.coverAsset) {
                        Image(uiImage: image).resizable().scaledToFill()
                    }
                    LabelPlate(name: notebook.name, size: 22)
                }
                .frame(height: 160)
                .clipped()
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 14) {
                    Text("\(inNotebook.count) \(inNotebook.count == 1 ? "entry" : "entries")" + (filter.map { " · \(list.count) tagged \($0)" } ?? ""))
                        .font(.ui(14)).foregroundStyle(Color.mMut)
                    SearchField(placeholder: "Search this notebook", text: $query)
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            FilterChip(label: "All", isOn: filter == nil) { filter = nil }
                            ForEach(labels, id: \.self) { label in
                                FilterChip(label: label, isOn: filter == label) { filter = filter == label ? nil : label }
                                    .accessibilityIdentifier("filter.\(label)")
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .scrollIndicators(.hidden)
                    .padding(.horizontal, -20)
                    .accessibilityIdentifier("notebook.filters")
                    ForEach(list) { EntryCard(entry: $0, showsMove: true) }
                    if list.isEmpty {
                        VStack(spacing: 12) {
                            PaperArt(name: "empty-search", height: 140)
                            Text("No entries match. Try another tag or search.").font(.ui(15)).foregroundStyle(Color.mMut)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 130)
            }
        }
        .scrollIndicators(.hidden)
        .background(Color.mBg.ignoresSafeArea())
    }

    private func keptLabels(_ entries: [Entry]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for entry in entries {
            for tag in entry.keptTags where seen.insert(tag.label.lowercased()).inserted { out.append(tag.label) }
        }
        return out
    }
}

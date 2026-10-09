import SwiftUI
import SwiftData
import MementoCore

/// Every kept tag, grouped by kind, plus search and summaries (prototype L348–370).
struct DiscoverView: View {
    @Environment(AppModel.self) private var app
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @State private var query = ""

    var body: some View {
        let index = TagIndex(entries: entries)
        let q = query.trimmingCharacters(in: .whitespaces)
        let tagged = entries.filter { !$0.keptTags.isEmpty }.count
        let pending = JournalInsights.pending(entries)
        let results = q.count >= 2 ? entries.filter { $0.text.localizedCaseInsensitiveContains(q) } : []
        Screen {
            PageTitle("Discover").padding(.top, 4)
            SearchField(placeholder: "Search entries and tags", text: $query)
            Text("From \(tagged) of your \(entries.count) entries with kept tags. Numbers show how many entries mention each.")
                .font(.ui(14)).foregroundStyle(Color.mMut)
            if !pending.isEmpty {
                Button {
                    if let id = pending.firstEntryID { app.openEntry(id) }
                } label: {
                    HStack {
                        Text(pending.label).foregroundStyle(Color.mInk)
                        Spacer()
                        Text("Review ›").foregroundStyle(Color.mMut)
                    }
                    .font(.ui(14))
                    .padding(.vertical, 12).padding(.horizontal, 14)
                    .dashedBorder(radius: 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if index.summaries.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    PaperArt(name: "empty-discover", height: 170)
                    Text("Tags you keep will gather here.").font(.serif(21, relativeTo: .title3)).foregroundStyle(Color.mInk)
                }
            }
            ForEach(TagKind.allCases, id: \.self) { kind in
                let items = index.byKind(kind, matching: q)
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            PaperIcon(name: kind.emblem, size: 24).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 4 }
                            Text(kind.plural).font(.serif(23, relativeTo: .title2)).foregroundStyle(Color.mInk)
                            Spacer()
                            Text("\(items.count) \(items.count == 1 ? "tag" : "tags")").font(.ui(13)).foregroundStyle(Color.mMut)
                        }
                        FlowLayout(spacing: 8) {
                            ForEach(items) { item in
                                Button { app.openTag(item.label) } label: {
                                    TagChip(label: item.label, kind: kind, count: "\(item.count)")
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("chip.\(item.label)")
                            }
                        }
                    }
                    .padding(.top, 6)
                }
            }
            if !results.isEmpty {
                Eyebrow("Entries mentioning “\(q)”").padding(.top, 6)
                ForEach(results) { EntryCard(entry: $0) }
            }
            Button { app.push(.summary(SummarySeed(ids: nil))) } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Make a summary").font(.serif(20, relativeTo: .title3)).foregroundStyle(Color.mInk)
                        Text("For yourself, or to bring to an appointment.").font(.ui(13.5)).foregroundStyle(Color.mMut)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Color.mMut)
                }
                .paperCard(radius: 20, padding: 18)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .accessibilityIdentifier("discover.summary")
        }
    }
}

/// Filled search field (prototype input on --line).
struct SearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.mMut)
            TextField(placeholder, text: $text).font(.ui(16)).foregroundStyle(Color.mInk)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.mMut) }
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.mLine))
    }
}

import SwiftUI
import SwiftData
import MementoCore

/// Add or edit a tag (prototype L626–634). Edits are the writer's and are never overwritten.
struct TagFormSheet: View {
    let entryID: UUID
    let tagID: UUID?
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var matches: [Entry]
    @Query(sort: \Entry.createdAt, order: .reverse) private var all: [Entry]
    @State private var label = ""
    @State private var kind: TagKind = .feeling
    @State private var loaded = false

    init(entryID: UUID, tagID: UUID?) {
        self.entryID = entryID
        self.tagID = tagID
        _matches = Query(filter: #Predicate<Entry> { $0.id == entryID })
    }

    private var entry: Entry? { matches.first }
    private var tag: TagMark? { tagID.flatMap { id in entry?.tags.first { $0.id == id } } }
    private var trimmed: String { label.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button("Cancel") { dismiss() }.buttonStyle(LinkButtonStyle(size: 16)).fontWeight(.regular)
                    Spacer()
                    Text(tag == nil ? "Add a tag" : "Edit tag").font(.ui(17, weight: .semibold)).foregroundStyle(Color.mInk)
                    Spacer()
                    Button(tag == nil ? "Add" : "Save", action: save).buttonStyle(LinkButtonStyle(size: 16)).fontWeight(.bold)
                        .disabled(trimmed.isEmpty)
                }
                TextField("e.g. Hopeful, poor sleep, cooking", text: $label)
                    .font(.ui(18))
                    .padding(.horizontal, 16).frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.mCard))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mLine, lineWidth: 1))
                    .submitLabel(.done)
                    .onSubmit(save)
                    .accessibilityIdentifier("tagForm.label")
                VStack(alignment: .leading, spacing: 8) {
                    Text("KIND").font(.ui(13, weight: .semibold)).foregroundStyle(Color.mMut)
                    SegmentedPill(options: TagKind.allCases.map { ($0, $0.shortLabel) }, selection: $kind)
                }
                if let quote = tag?.quote {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("BASED ON YOUR WORDS").font(.ui(13, weight: .semibold)).foregroundStyle(Color.mMut)
                        Text("“\(quote)”").font(.serif(17, italic: true)).foregroundStyle(Color.mInk).paperCard(radius: 14, padding: 14)
                    }
                }
                if tag == nil, !quickPicks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR TAGS").font(.ui(13, weight: .semibold)).foregroundStyle(Color.mMut)
                        FlowLayout(spacing: 8) {
                            ForEach(quickPicks) { pick in
                                Button { label = pick.label; kind = pick.kind } label: { TagChip(label: pick.label, kind: pick.kind) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                if let tag {
                    Button("Remove tag") {
                        dismiss()
                        EntryActions.remove(tag, app: app, context: context)
                    }
                    .font(.ui(16)).foregroundStyle(Color.mDanger)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mLine, lineWidth: 1))
                }
                Text("Your edits are saved as your own and won’t be overwritten by later suggestions.")
                    .font(.ui(13)).foregroundStyle(Color.mMut)
            }
            .padding(20)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Color.mSheet)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let tag { label = tag.label; kind = tag.kind }
        }
    }

    private var quickPicks: [TagSummary] {
        let onEntry = Set((entry?.visibleTags ?? []).map { $0.label.lowercased() })
        return Array(TagIndex.byCount(TagIndex(entries: all).summaries).filter { !onEntry.contains($0.key) }.prefix(8))
    }

    private func save() {
        guard !trimmed.isEmpty, let entry else { return }
        if let tag {
            tag.label = trimmed
            tag.kind = kind
            tag.status = .kept
            tag.isEdited = true
        } else {
            entry.addTag(label: trimmed, kind: kind, status: .kept, isManual: true)
        }
        try? context.save()
        dismiss()
    }
}

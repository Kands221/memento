import SwiftUI
import SwiftData
import UIKit
import MementoCore

/// An entry with its words, on-device suggestions and kept tags (prototype L269–314).
struct EntryDetailView: View {
    let entryID: UUID
    @Environment(AppModel.self) private var app
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @Query private var matches: [Entry]
    @Query(sort: \Entry.createdAt, order: .reverse) private var all: [Entry]
    @State private var activeID: UUID?
    @State private var editingKept = false
    @State private var painting = false
    @State private var paintError: String?

    init(entryID: UUID) {
        self.entryID = entryID
        _matches = Query(filter: #Predicate<Entry> { $0.id == entryID })
    }

    var body: some View {
        Group {
            if let entry = matches.first {
                content(entry)
            } else {
                Text("This entry is no longer here.").font(.ui(16)).foregroundStyle(Color.mMut)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.mBg)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    if app.justSavedID == entryID {
                        Text("Saved ✓").font(.ui(13, weight: .semibold)).foregroundStyle(Color.mSage)
                            .padding(.vertical, 6).padding(.horizontal, 12).background(Capsule().fill(Color.mSageT))
                    }
                    Button("Move") { app.sheet = .move(entryID) }.font(.ui(14))
                }
            }
        }
        .onDisappear { if app.justSavedID == entryID { app.justSavedID = nil } }
    }

    private func content(_ entry: Entry) -> some View {
        let labels = DateLabels()
        return Screen(spacing: 12, horizontalPadding: 22) {
            Text("\(labels.relativeDay(entry.createdAt)), \(labels.time(entry.createdAt)) · \(entry.notebook.name) · \(entry.mode.title)")
                .font(.ui(13, relativeTo: .footnote)).foregroundStyle(Color.mMut)
            if let prompt = entry.prompt {
                Text(prompt).font(.serif(17, relativeTo: .body, italic: true)).foregroundStyle(Color.mMut)
            }
            if let data = entry.photoData, let image = UIImage(data: data) {
                Color.clear.frame(height: 200)
                    .overlay { Image(uiImage: image).resizable().scaledToFill() }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            paintedArt(entry)
            AnnotatedText(segments: TextSegments.build(text: entry.text, marks: entry.quoteMarks), activeID: activeID,
                          font: .serif(21, relativeTo: .body), lineSpacing: 12) { id in
                activeID = activeID == id ? nil : id
            }
            details(entry)
                .padding(.top, 14)
                .overlay(alignment: .top) { Rectangle().fill(Color.mLine).frame(height: 1).padding(.horizontal, -6) }
                .padding(.top, 12)
        }
    }

    // MARK: Paint this day

    @ViewBuilder
    private func paintedArt(_ entry: Entry) -> some View {
        if let data = entry.artData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
                .frame(height: 240).frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.mLine, lineWidth: 1))
                .overlay(alignment: .topTrailing) {
                    Menu {
                        Button("Paint again", systemImage: "paintbrush.pointed") { paint(entry) }
                        Button("Remove painting", systemImage: "trash", role: .destructive) {
                            entry.artData = nil
                            try? context.save()
                        }
                    } label: {
                        Image(systemName: "ellipsis").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.mInk)
                            .frame(width: 34, height: 34).background(Circle().fill(.ultraThinMaterial))
                    }
                    .padding(10)
                    .accessibilityLabel("Painting options")
                }
                .accessibilityLabel("A painting of this day, made on this iPhone")
        } else if painting {
            HStack(spacing: 10) {
                ProgressView().tint(Color.mTer)
                Text("Painting this day on this iPhone…").font(.ui(14).italic()).foregroundStyle(Color.mMut)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .dashedBorder(radius: 18, color: .mLine)
        } else if services.canPaint && entry.photoData == nil && !entry.text.isEmpty {
            Button { paint(entry) } label: {
                Label("Paint this day", systemImage: "paintbrush.pointed")
                    .font(.ui(15, weight: .semibold)).foregroundStyle(Color.mTer)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mTer.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Makes an illustration from your words, on this iPhone")
            .accessibilityIdentifier("entry.paint")
        }
        if let paintError {
            Text(paintError).font(.ui(13)).foregroundStyle(Color.mDanger)
        }
    }

    private func paint(_ entry: Entry) {
        painting = true
        paintError = nil
        let text = entry.text
        Task {
            do {
                let data = try await EntryArtist.paint(text)
                entry.artData = data
                try? context.save()
            } catch {
                paintError = "Couldn’t paint this one. Try again in a moment."
            }
            painting = false
        }
    }

    // MARK: Details

    private func details(_ entry: Entry) -> some View {
        let suggested = entry.suggestedTags
        let kept = entry.keptTags
        let index = TagIndex(entries: all)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Details").font(.serif(22, relativeTo: .title3)).foregroundStyle(Color.mInk)
                Spacer()
                Button("+ Add a tag") { app.sheet = .addTag(entry.id) }.buttonStyle(LinkButtonStyle())
            }
            phaseCard(entry)
            if !suggested.isEmpty {
                HStack {
                    Text("SUGGESTED · \(suggested.count)").font(.ui(13, weight: .semibold)).foregroundStyle(Color.mMut)
                    Spacer()
                    Button("Keep all") { EntryActions.keepAll(entry, app: app, context: context) }
                        .buttonStyle(LinkButtonStyle(color: .mSage, size: 14))
                }
                ForEach(suggested) { suggestionRow($0, entry: entry) }
            }
            if !kept.isEmpty {
                HStack {
                    Text("KEPT").font(.ui(13, weight: .semibold)).foregroundStyle(Color.mMut)
                    Spacer()
                    Button(editingKept ? "Done" : "Edit") { editingKept.toggle() }.buttonStyle(LinkButtonStyle(size: 14))
                }
                .padding(.top, 4)
                FlowLayout(spacing: 8) {
                    ForEach(kept) { tag in
                        let n = index.count(for: tag.label)
                        Button {
                            if editingKept { app.sheet = .editTag(entry: entry.id, tag: tag.id) } else { app.openTag(tag.label) }
                        } label: {
                            TagChip(label: tag.label, kind: tag.kind, count: n > 1 ? "· \(n)" : nil)
                                .overlay { if editingKept { Capsule().strokeBorder(tag.kind.color, lineWidth: 1.5) } }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("kept.\(tag.label)")
                    }
                }
                Text(editingKept ? "Tap a tag to rename, change its kind, or remove it." : "Tap a tag to see every entry it appears in. The number shows how many.")
                    .font(.ui(13, relativeTo: .footnote)).foregroundStyle(Color.mMut)
            }
            Text("Dashed tags are suggestions from your words and aren’t counted anywhere until you keep them. Your edits are saved as yours.")
                .font(.ui(12.5, relativeTo: .caption1)).foregroundStyle(Color.mMut).padding(.top, 6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func phaseCard(_ entry: Entry) -> some View {
        switch services.tagging.phase(for: entry) {
        case .running:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Dot()
                    Text(services.taggingUsesCloud ? "Finding details with cloud AI…" : "Finding details on this iPhone…").font(.ui(15, weight: .semibold)).foregroundStyle(Color.mInk)
                }
                Text("Your entry is already saved. You can leave — suggestions will be waiting.")
                    .font(.ui(13.5)).foregroundStyle(Color.mMut)
            }
            .paperCard(radius: 16, padding: 16)
        case .failed:
            VStack(alignment: .leading, spacing: 10) {
                Text("Couldn’t finish finding details.").font(.ui(15, weight: .semibold)).foregroundStyle(Color.mInk)
                Text("Your entry is saved exactly as written. This sometimes happens when the phone is low on memory.")
                    .font(.ui(13.5)).foregroundStyle(Color.mMut)
                Button("Try again") { services.tagging.retry(entry) }
                    .buttonStyle(InkButtonStyle(height: 40, fullWidth: false))
            }
            .paperCard(radius: 16, padding: 16)
        case .none:
            note("Nothing stood out to tag this time — that doesn’t mean nothing happened. Add your own if you like.")
        case .unavailable, .off:
            VStack(alignment: .leading, spacing: 10) {
                Text("On-device tagging isn’t set up yet, so nothing was suggested. Your entry is saved.")
                    .font(.ui(14.5)).foregroundStyle(Color.mInk)
                Button("Set up on-device AI ›") { app.push(.onDeviceAI) }.buttonStyle(LinkButtonStyle(size: 14))
            }
            .paperCard(radius: 16, padding: 16)
        case .unsupported:
            note("Suggestions aren’t available on this iPhone. Tags you add work everywhere — in Discover, notebooks and summaries.")
        case .done:
            EmptyView()
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.ui(14.5)).foregroundStyle(Color.mMut)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.mLine, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }

    private func suggestionRow(_ tag: TagMark, entry: Entry) -> some View {
        let active = activeID == tag.id
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Button { app.sheet = .editTag(entry: entry.id, tag: tag.id) } label: {
                        TagChip(label: tag.label, kind: tag.kind, status: .suggested)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit \(tag.label)")
                    Text(tag.kind.singular).font(.ui(12)).foregroundStyle(Color.mMut)
                }
                if let quote = tag.quote {
                    Text("“\(quote)”").font(.serif(15, italic: true)).foregroundStyle(Color.mMut)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { EntryActions.remove(tag, app: app, context: context) } label: { Image(systemName: "xmark").font(.ui(14)) }
                .buttonStyle(CircleIconButtonStyle())
                .accessibilityLabel("Remove \(tag.label)")
            Button("Keep") { EntryActions.keep(tag, context: context) }
                .buttonStyle(PillButtonStyle(fill: .mSageT, foreground: .mSage, border: nil))
                .accessibilityLabel("Keep \(tag.label)")
        }
        .padding(.vertical, 12)
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .background(RoundedRectangle(cornerRadius: 16).fill(active ? Color.mCard : .clear))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(active ? Color.mLine : .clear, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { activeID = active ? nil : tag.id }
    }
}

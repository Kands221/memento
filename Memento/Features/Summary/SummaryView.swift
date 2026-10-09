import SwiftUI
import SwiftData
import MementoCore

/// Build a summary from chosen entries, preview it as paper, export a PDF (prototype L538–583, spec D14).
struct SummaryView: View {
    let seed: SummarySeed
    @Environment(AppModel.self) private var app
    @Environment(AppServices.self) private var services
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @AppStorage(SettingsKey.preparedBy) private var preparedBy = ""
    @State private var purpose: SummaryPurpose = .me
    @State private var selected: Set<UUID> = []
    @State private var includeQuotes = true
    @State private var note = ""
    @State private var step = 0
    @State private var initialized = false
    @State private var pdfURL: URL?
    @State private var pages = 1
    /// Sol's look-back paragraph ("For me" only), drafted on device and editable before export.
    @State private var letSolWrite = true
    @State private var lookBack: String?
    @State private var drafting = false
    @State private var editingLookBack = false

    var body: some View {
        Group {
            if step == 0 { builder } else { preview }
        }
        .navigationBarBackButtonHidden(step == 1)
        .toolbar {
            if step == 1 {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        lookBack = nil
                        step = 0
                    } label: { Label("Edit selection", systemImage: "chevron.left").labelStyle(.titleAndIcon) }
                }
            }
        }
        .sheet(isPresented: $editingLookBack, onDismiss: makePreview) {
            NavigationStack {
                TextEditor(text: Binding(get: { lookBack ?? "" }, set: { lookBack = $0 }))
                    .font(.ui(16))
                    .padding(12)
                    .navigationTitle("Look-back")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("Done") { editingLookBack = false } }
                    }
            }
        }
        .onAppear {
            guard !initialized else { return }
            initialized = true
            selected = Set(seed.ids ?? lastTwoWeeks)
        }
    }

    private var lastTwoWeeks: [UUID] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Calendar.current.startOfDay(for: .now)) ?? .now
        return entries.filter { $0.createdAt >= cutoff }.map(\.id)
    }

    private var chosen: [Entry] { entries.filter { selected.contains($0.id) } }

    private var document: SummaryDocument {
        SummaryComposer.compose(entries: chosen, options: SummaryOptions(purpose: purpose, includeQuotes: includeQuotes,
                                                                        note: note, preparedBy: preparedBy, today: .now,
                                                                        narrative: purpose == .me ? lookBack : nil))
    }

    /// Only Apple's on-device model writes the look-back; cloud and demo engines never do.
    private var canDraft: Bool {
        purpose == .me && services.ai.live == .ready && services.ai.availability == .ready && !services.taggingUsesCloud
            && (!services.options.uiTesting || ProcessInfo.processInfo.arguments.contains("-liveSummary"))
    }

    // MARK: Step 0

    private var builder: some View {
        Screen(spacing: 18, horizontalPadding: 16) {
            PageTitle("New summary", size: 34).padding(.horizontal, 4)
            VStack(spacing: 10) {
                purposeCard(.me, "For me", "Look back, notice patterns, remember what helped.")
                purposeCard(.clinician, "For my psychologist or psychiatrist", "A plain, factual page to bring to an appointment.")
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Entries").font(.serif(21, relativeTo: .title3)).foregroundStyle(Color.mInk)
                Spacer()
                Text("\(selected.count) selected").font(.ui(14)).foregroundStyle(Color.mMut)
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    FilterChip(label: "Last 2 weeks") { selected = Set(lastTwoWeeks) }
                    FilterChip(label: "All entries") { selected = Set(entries.map(\.id)) }
                    ForEach(TagIndex(entries: entries).topLabels(2), id: \.self) { label in
                        FilterChip(label: label) { selected = Set(entries.filter { $0.hasKept(label: label) }.map(\.id)) }
                    }
                    FilterChip(label: "Clear") { selected = [] }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -16)
            .padding(.top, -6)
            VStack(spacing: 0) {
                ForEach(entries) { entry in entryRow(entry) }
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.mCard))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.mLine, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            SettingsGroup {
                Toggle(isOn: $includeQuotes) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Include my original words").font(.ui(16)).foregroundStyle(Color.mInk)
                        Text("Short quotes behind each tag").font(.ui(13)).foregroundStyle(Color.mMut)
                    }
                }
                .toggleStyle(SageToggleStyle())
                .padding(.horizontal, 16).padding(.vertical, 8)
                if canDraft {
                    Toggle(isOn: $letSolWrite) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Let Sol write the look-back").font(.ui(16)).foregroundStyle(Color.mInk)
                            Text("Drafted on this iPhone from your kept tags. You can edit it.").font(.ui(13)).foregroundStyle(Color.mMut)
                        }
                    }
                    .toggleStyle(SageToggleStyle())
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .accessibilityIdentifier("summary.lookBack")
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Only tags I’ve kept").font(.ui(16)).foregroundStyle(Color.mInk)
                        Text("Unreviewed suggestions are never included").font(.ui(13)).foregroundStyle(Color.mMut)
                    }
                    Spacer()
                    Text("Always").font(.ui(14, weight: .semibold)).foregroundStyle(Color.mSage)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
            if purpose == .clinician {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ANYTHING YOU WANT TO RAISE? (OPTIONAL)").font(.ui(13, weight: .semibold)).foregroundStyle(Color.mMut).padding(.horizontal, 4)
                    TextField("e.g. Sleep has been worse since the launch moved.", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.ui(15))
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.mCard))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mLine, lineWidth: 1))
                    Text("PREPARED BY (OPTIONAL)").font(.ui(13, weight: .semibold)).foregroundStyle(Color.mMut).padding(.horizontal, 4).padding(.top, 6)
                    TextField("Your name", text: $preparedBy)
                        .font(.ui(15))
                        .textContentType(.name)
                        .padding(.horizontal, 14).frame(height: 46)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.mCard))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mLine, lineWidth: 1))
                }
            }
            Button(drafting ? "Sol is writing on this iPhone…" : "Preview summary") { startPreview() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selected.isEmpty || drafting)
                .accessibilityIdentifier("summary.preview")
        }
    }

    private func purposeCard(_ value: SummaryPurpose, _ title: String, _ detail: String) -> some View {
        let on = purpose == value
        return Button { purpose = value } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.ui(16, weight: .semibold)).foregroundStyle(Color.mInk)
                Text(detail).font(.ui(14)).foregroundStyle(Color.mMut).multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.mCard))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(on ? Color.mTer : Color.mLine, lineWidth: on ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("purpose.\(value == .me ? "me" : "clinician")")
    }

    private func entryRow(_ entry: Entry) -> some View {
        let on = selected.contains(entry.id)
        let tags = entry.keptTags.prefix(3).map(\.label)
        return Button {
            if on { selected.remove(entry.id) } else { selected.insert(entry.id) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(on ? Color.mTer : .clear)
                    Circle().strokeBorder(on ? Color.clear : Color.mMut, lineWidth: 1.5)
                    if on { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.mOnTer) }
                }
                .frame(width: 24, height: 24)
                .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(DateLabels().relativeDay(entry.createdAt)) · \(tags.isEmpty ? "No kept tags" : tags.joined(separator: ", "))")
                        .font(.ui(12.5, relativeTo: .caption1)).foregroundStyle(Color.mMut)
                    Text(Excerpt.make(entry.text)).font(.ui(15)).foregroundStyle(Color.mInk).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.mLine).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Step 1

    private var preview: some View {
        Screen(spacing: 14, horizontalPadding: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Preview").font(.serif(24, relativeTo: .title2)).foregroundStyle(Color.mInk)
                Spacer()
                Text("PDF · \(pages) \(pages == 1 ? "page" : "pages")").font(.ui(13)).foregroundStyle(Color.mMut)
            }
            .padding(.horizontal, 4)
            if lookBack != nil {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Drafted by Sol on this iPhone from your kept tags. Edit anything.")
                        .font(.ui(13.5)).foregroundStyle(Color.mMut).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button { editingLookBack = true } label: {
                        Text("Edit").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                        .buttonStyle(LinkButtonStyle(size: 15))
                        .accessibilityLabel("Edit the look-back")
                        .accessibilityIdentifier("summary.editLookBack")
                }
                .padding(.horizontal, 4)
            }
            SummaryPaper(doc: document)
            Text("Nothing is shared until you choose where it goes.").font(.ui(13.5)).foregroundStyle(Color.mMut).padding(.horizontal, 4)
            if let pdfURL {
                ShareLink(item: pdfURL, preview: SharePreview(pdfURL.lastPathComponent)) {
                    Text("Export PDF…").font(.ui(17, weight: .semibold)).foregroundStyle(Color.mOnTer)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.mTer))
                }
                .accessibilityLabel("Export PDF…")
            }
        }
    }

    /// "For me" with Sol on: draft the look-back first; if it can't be trusted, the deterministic paragraph stays.
    private func startPreview() {
        guard canDraft, letSolWrite else {
            lookBack = nil
            makePreview()
            return
        }
        drafting = true
        let facts = SummaryFacts.make(entries: chosen)
        Task {
            lookBack = await SummaryNarrator.narrate(facts)?.text
            drafting = false
            makePreview()
        }
    }

    private func makePreview() {
        let doc = document
        let data = PDFComposer.render(PDFComposer.summary(doc))
        pages = PDFComposer.pageCount(data)
        let name = purpose == .clinician ? "Memento – appointment summary.pdf" : "Memento – a look back.pdf"
        do {
            pdfURL = try PDFComposer.write(data, name: name)
        } catch {
            pdfURL = nil
            app.showToast("Couldn’t make the PDF.")
        }
        step = 1
    }
}

import SwiftUI
import PhotosUI
import MementoCore

/// The writing surface for every mode (prototype L223–267). Saving never waits for AI.
struct EditorView: View {
    @Environment(AppModel.self) private var app
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @State private var dictation = DictationService()
    @State private var dictationBase = ""
    @State private var showNotebookPicker = false
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var saveError: String?
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var app = app
        VStack(spacing: 0) {
            topBar
            SegmentedPill(options: [(WritingMode.free, "Free"), (.dump, "Brain dump"), (.guided, "Guided"), (.photo, "Photo")],
                          selection: $app.draft.mode)
                .padding(.horizontal, 16)
                .padding(.top, 4)
            modeHeader
            textArea
            if dictation.isListening {
                Text("Listening… speak naturally.")
                    .font(.ui(15, weight: .medium)).foregroundStyle(Color.mTer)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12).padding(.horizontal, 16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.mTerT))
                    .padding(.horizontal, 16).padding(.bottom, 10)
            }
            if let note = saveError ?? dictation.errorText {
                Text(note).font(.ui(14)).foregroundStyle(Color.mDanger)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.bottom, 8)
            }
            bottomBar
        }
        .background(Color.mBg.ignoresSafeArea())
        .sheet(isPresented: $showNotebookPicker) {
            NotebookList(title: "Save to notebook", current: app.draft.notebookID) { id in
                app.draft.notebookID = id
                showNotebookPicker = false
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { app.draft.photo = PhotoProcessing.jpegData(from: $0) }.ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    app.draft.photo = PhotoProcessing.jpegData(from: image)
                }
                photoItem = nil
            }
        }
        .onDisappear { dictation.stop() }
    }

    private var topBar: some View {
        HStack {
            Button("Cancel") { app.editorMode = nil }.buttonStyle(LinkButtonStyle(size: 17)).fontWeight(.regular)
            Spacer()
            Button { showNotebookPicker = true } label: {
                Text("\(Notebook.with(id: app.draft.notebookID).name) ▾").font(.ui(14)).foregroundStyle(Color.mInk)
                    .padding(.horizontal, 12).frame(height: 34)
                    .background(Capsule().fill(Color.mCard)).overlay(Capsule().strokeBorder(Color.mLine, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Notebook: \(Notebook.with(id: app.draft.notebookID).name)")
            Spacer()
            Button("Save", action: save)
                .font(.ui(17, weight: .bold))
                .foregroundStyle(app.draft.canSave ? Color.mTer : Color.mMut)
                .opacity(app.draft.canSave ? 1 : 0.5)
                .frame(minHeight: 44)
                .disabled(!app.draft.canSave)
                .accessibilityIdentifier("editor.save")
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    @ViewBuilder
    private var modeHeader: some View {
        @Bindable var app = app
        switch app.draft.mode {
        case .dump:
            BrainDumpTimer().padding(.horizontal, 20).padding(.top, 16)
        case .guided:
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(PromptCategory.allCases, id: \.self) { category in
                            FilterChip(label: category.title, isOn: app.draft.promptCategory == category) {
                                app.draft.promptCategory = category
                                app.draft.promptIndex = 0
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                Text(app.draft.prompt).font(.serif(21, relativeTo: .title3, italic: true)).foregroundStyle(Color.mInk)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Another prompt") { app.draft.promptIndex += 1 }.buttonStyle(LinkButtonStyle(size: 14))
            }
            .paperCard(radius: 18, padding: 16)
            .padding(.horizontal, 16).padding(.top, 14)
        case .photo:
            photoHeader.padding(.horizontal, 16).padding(.top, 14)
        case .free, .sol:
            EmptyView()
        }
    }

    @ViewBuilder
    private var photoHeader: some View {
        if let data = app.draft.photo, let image = UIImage(data: data) {
            Color.clear.frame(height: 210)
                .overlay { Image(uiImage: image).resizable().scaledToFill() }
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(alignment: .bottomTrailing) {
                    Button("Replace") { app.draft.photo = nil }
                        .buttonStyle(PillButtonStyle(fill: .mBg, border: nil, height: 32, horizontalPadding: 12))
                        .font(.ui(13)).padding(12)
                }
        } else {
            HStack(spacing: 10) {
                if CameraPicker.isAvailable {
                    Button("Camera") { showCamera = true }.buttonStyle(PillButtonStyle(fill: .mInk, foreground: .mBg, border: nil))
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text("Photo library").font(.ui(15, weight: .semibold)).foregroundStyle(Color.mInk)
                        .padding(.horizontal, 18).frame(minHeight: 44)
                        .background(Capsule().fill(Color.mCard)).overlay(Capsule().strokeBorder(Color.mLine, lineWidth: 1))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 170)
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.mLine, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        }
    }

    private var textArea: some View {
        @Bindable var app = app
        return TextEditor(text: $app.draft.text)
            .font(.serif(21, relativeTo: .body))
            .lineSpacing(10)
            .foregroundStyle(Color.mInk)
            .scrollContentBackground(.hidden)
            .focused($focused)
            .padding(.horizontal, 15)
            .padding(.top, 10)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                if app.draft.text.isEmpty {
                    Text(placeholder).font(.serif(21, relativeTo: .body)).foregroundStyle(Color.mMut.opacity(0.8))
                        .padding(.horizontal, 20).padding(.top, 18).allowsHitTesting(false)
                }
            }
            .accessibilityIdentifier("editor.text")
    }

    private var placeholder: String {
        switch app.draft.mode {
        case .dump: "Just keep going…"
        case .guided: "Write your answer…"
        case .photo: "Add a few words, if you like…"
        case .free, .sol: "Start anywhere…"
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            if dictation.isAvailable {
                Button {
                    if dictation.isListening { dictation.stop(); return }
                    dictationBase = app.draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task {
                        await dictation.start { transcript in
                            app.draft.text = dictationBase.isEmpty ? transcript : dictationBase + " " + transcript
                        }
                    }
                } label: {
                    Label(dictation.isListening ? "Stop" : "Speak", systemImage: dictation.isListening ? "stop.fill" : "mic")
                }
                .buttonStyle(PillButtonStyle(fill: dictation.isListening ? .mTerT : .mCard, foreground: dictation.isListening ? .mTer : .mInk))
            }
            Button("Use example") { app.draft.text = EditorExamples.text(for: app.draft.mode) }
                .buttonStyle(PillButtonStyle(fill: .clear, foreground: .mMut, dashed: true, horizontalPadding: 14))
                .font(.ui(14))
                .accessibilityIdentifier("editor.example")
            Spacer()
            Text(wordCount).font(.ui(13)).foregroundStyle(Color.mMut)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .overlay(alignment: .top) { Rectangle().fill(Color.mLine).frame(height: 1) }
    }

    private var wordCount: String {
        let n = app.draft.text.split(whereSeparator: \.isWhitespace).count
        return n == 0 ? "" : "\(n) \(n == 1 ? "word" : "words")"
    }

    private func save() {
        let draft = app.draft
        guard draft.canSave else { return }
        dictation.stop()
        let entry = Entry(notebookID: draft.notebookID, mode: draft.mode,
                          prompt: draft.mode == .guided ? draft.prompt : nil,
                          text: draft.text.trimmingCharacters(in: .whitespacesAndNewlines),
                          photoData: draft.mode == .photo ? draft.photo : nil, tagging: .pending)
        context.insert(entry)
        do {
            try context.save()
        } catch {
            context.delete(entry)
            saveError = "Couldn’t save — your words are still here."
            return
        }
        services.tagging.enqueue(entry)
        app.didSave(entryID: entry.id)
    }
}

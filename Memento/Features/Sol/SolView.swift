import SwiftUI
import SwiftData
import MementoCore

/// Sol: an on-device conversation that ends in a reflection you edit and keep (prototype L492–521, spec §5.3, D27).
struct SolView: View {
    @Environment(AppModel.self) private var app
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(SettingsKey.solEnabled) private var solEnabled = true
    @State private var conversation: SolConversation?
    @State private var engine: (any SolEngine)?
    @State private var draft = ""
    @State private var drafting = false
    @State private var showDraft = false
    @State private var voice = SolVoice()
    @State private var listener = SpeechInput()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if let conversation, isOpen {
                    chat(conversation)
                } else {
                    gate
                }
            }
            .background(Color.mBg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showDraft) {
                SolDraftView(text: $draft, onBack: { showDraft = false }, onSave: saveReflection, onDiscard: discard)
            }
        }
        .task {
            guard conversation == nil else { return }
            await services.refreshJournal()
            let engine = services.makeSolEngine()
            self.engine = engine
            let conversation = SolConversation(engine: engine)
            self.conversation = conversation
            if isOpen { conversation.prewarm() }
        }
    }

    private var isOpen: Bool { solEnabled && services.solAvailability == .ready }

    // MARK: Header

    private var header: some View {
        HStack {
            Button("Close") { close() }.buttonStyle(LinkButtonStyle(size: 17)).fontWeight(.regular)
                .lineLimit(1).minimumScaleFactor(0.6).frame(width: 56, alignment: .leading)
            Spacer(minLength: 4)
            VStack(spacing: 1) {
                HStack(spacing: 6) {
                    avatar(size: 24)
                    Text("Sol").font(.serif(19, relativeTo: .headline)).foregroundStyle(Color.mInk)
                }
                Text(services.solUsesCloud ? "Cloud AI · not saved unless you choose" : "On this iPhone · not saved unless you choose").font(.ui(11, relativeTo: .caption2)).foregroundStyle(Color.mMut)
                    .lineLimit(2).minimumScaleFactor(0.8).multilineTextAlignment(.center)
            }
            Spacer(minLength: 4)
            Button { voice.isEnabled.toggle() } label: {
                Image(systemName: voice.isEnabled ? "speaker.wave.2.fill" : "speaker.slash")
                    .font(.system(size: 17)).foregroundStyle(voice.isEnabled ? Color.mTer : Color.mMut)
                    .frame(width: 56, height: 44, alignment: .trailing)
            }
            .accessibilityLabel(voice.isEnabled ? "Sol's voice is on" : "Sol's voice is off")
            .accessibilityHint("Sol reads his replies aloud")
            .accessibilityIdentifier("sol.voiceToggle")
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.mLine).frame(height: 1) }
    }

    private func avatar(size: CGFloat) -> some View {
        let mood = conversation?.mood ?? .hello
        return SolCharacterView(mood: mood == .hello ? .speaking : mood, size: size, showsEffects: false, reactsToTap: false)
            .accessibilityHidden(true)
    }

    // MARK: Gate

    private var gate: some View {
        let availability = services.solAvailability
        let (title, body, cta): (String, String, String) =
            availability == .unsupported
            ? ("Sol isn’t available on this iPhone", "Sol needs on-device AI this iPhone can’t run, and it won’t use the cloud instead. Guided reflection offers prompts to think things through.", "Try Guided reflection")
            : !solEnabled
            ? ("Sol is turned off", "You can turn Sol back on in On-device AI settings.", "Open On-device AI")
            : ("Sol needs on-device AI", "Set up the on-device model first. Your conversation would stay on this iPhone.", "Open On-device AI")
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SolCharacterView(mood: .resting, size: 160).frame(maxWidth: .infinity)
                Text(title).font(.serif(26, relativeTo: .title2)).foregroundStyle(Color.mInk)
                Text(body).font(.ui(15.5)).foregroundStyle(Color.mMut).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                Button(cta) {
                    if availability == .unsupported {
                        app.isSolPresented = false
                        Task { try? await Task.sleep(for: .milliseconds(450)); app.openEditor(.guided) }
                    } else {
                        app.isSolPresented = false
                        app.select(.you)
                        app.push(.onDeviceAI)
                    }
                }
                .buttonStyle(InkButtonStyle(height: 50))
            }
            .padding(24)
        }
    }

    // MARK: Chat

    private func chat(_ c: SolConversation) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if c.userTurns == 0 {
                        SolCharacterView(mood: c.input.isEmpty ? .hello : .listening, size: 160, nudge: c.input.split(separator: " ").count)
                            .frame(maxWidth: .infinity).padding(.top, 4)
                    }
                    Text(services.solUsesCloud ? SolCharacter.cloudDisclaimer : SolCharacter.disclaimer)
                        .font(.ui(13)).foregroundStyle(Color.mMut).lineSpacing(2)
                        .paperCard(radius: 14, padding: 14)
                    ForEach(c.messages) { message in messageView(message, isLatest: message.id == c.messages.last?.id && c.userTurns > 0, c: c) }
                    if c.isAwaitingFirstToken {
                        HStack(spacing: 8) {
                            SolCharacterView(mood: .thinking, size: 56, reactsToTap: false)
                            Text("Sol is thinking…").font(.ui(14).italic()).foregroundStyle(Color.mMut)
                                .accessibilityIdentifier("sol.thinking")
                        }
                    }
                    if drafting {
                        HStack(spacing: 10) {
                            SolCharacterView(mood: .reflect, size: 48, showsEffects: false, reactsToTap: false)
                            Text(SolCharacter.drafting).font(.ui(14).italic()).foregroundStyle(Color.mMut)
                        }
                    } else if c.canMakeReflection {
                        Button("Turn this into a reflection") { makeReflection(c) }
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.top, 6)
                            .accessibilityIdentifier("sol.makeReflection")
                    }
                    if c.reachedCap {
                        HStack(alignment: .top, spacing: 10) {
                            SolCharacterView(mood: .resting, size: 56, reactsToTap: false)
                            Text(SolCharacter.windDown).font(.ui(14)).foregroundStyle(Color.mMut)
                        }
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: c.messages.last?.text) { _, text in
                proxy.scrollTo("bottom", anchor: .bottom)
                if c.isResponding, c.messages.last?.role == .sol, let text { voice.feed(text, final: false) }
            }
            .onChange(of: c.isResponding) { _, responding in
                if !responding, let last = c.messages.last, last.role == .sol { voice.feed(last.text, final: true) }
            }
            .onChange(of: c.suggestions) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: c.isAwaitingFirstToken) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            .safeAreaInset(edge: .bottom) { composer(c) }
        }
    }

    @ViewBuilder
    private func messageView(_ message: SolMessage, isLatest: Bool, c: SolConversation) -> some View {
        switch message.role {
        case .sol:
            HStack(alignment: .top, spacing: 10) {
                Group {
                    if isLatest {
                        // The latest reply's avatar nods along as words stream in.
                        SolCharacterView(mood: .speaking, size: 40,
                                         nudge: voice.wordTick + (c.isResponding ? message.text.split(separator: " ").count / 4 : 0),
                                         showsEffects: false)
                    } else {
                        SolArt(name: "sol-mark", size: 22).padding(.top, 3)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(message.text).font(.serif(20, relativeTo: .body)).foregroundStyle(Color.mInk).lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .accessibilityLabel("Sol: \(message.text)")
                    ForEach(message.citations, id: \.self) { citation in
                        Button { openCitation(citation) } label: {
                            Label("From your journal · \(citation.label)", systemImage: "book.closed")
                                .font(.ui(13, weight: .medium)).foregroundStyle(Color.mSage)
                                .padding(.vertical, 6).padding(.horizontal, 11)
                                .background(Capsule().fill(Color.mSageT))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens that entry")
                    }
                }
            }
        case .me:
            HStack {
                Spacer(minLength: 60)
                Text(message.text).font(.ui(16)).foregroundStyle(Color.mInk)
                    .padding(.vertical, 11).padding(.horizontal, 15)
                    .background(UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20, bottomTrailingRadius: 6, topTrailingRadius: 20).fill(Color.mTerT))
            }
        case .support:
            SupportCard(message: message.text)
        }
    }

    private func composer(_ c: SolConversation) -> some View {
        @Bindable var c = c
        return VStack(alignment: .leading, spacing: 10) {
            if !c.suggestions.isEmpty && c.canSend {
                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView(.horizontal) { HStack(spacing: 8) { chips(c) } }.scrollIndicators(.hidden)
                } else {
                    FlowLayout(spacing: 8) { chips(c) }
                }
            }
            if let note = listener.errorText {
                Text(note).font(.ui(13)).foregroundStyle(Color.mDanger)
            }
            if !c.reachedCap {
                HStack(spacing: 8) {
                    if listener.isAvailable {
                        Button { toggleListening(c) } label: {
                            Image(systemName: listener.isListening ? "stop.fill" : (listener.isPreparing ? "ellipsis" : "mic.fill"))
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(listener.isListening ? Color.mOnTer : Color.mTer)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(listener.isListening ? Color.mTer : Color.mTerT))
                        }
                        .buttonStyle(.plain)
                        .disabled(c.isResponding || listener.isPreparing)
                        .accessibilityLabel(listener.isListening ? "Stop and send" : "Talk to Sol")
                        .accessibilityIdentifier("sol.mic")
                    }
                    TextField(listener.isListening ? "Listening…" : "Reply to Sol…", text: $c.input, axis: .vertical)
                        .font(.ui(16))
                        .lineLimit(1...4)
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 22).fill(Color.mCard))
                        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.mLine, lineWidth: 1))
                        .submitLabel(.send)
                        .onSubmit { send(c) }
                        .accessibilityIdentifier("sol.input")
                    Button("Send") { send(c) }
                        .buttonStyle(PillButtonStyle(fill: .mInk, foreground: .mBg, border: nil))
                        .disabled(!c.canSend || c.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityValue(c.isResponding ? "Sol is replying" : "Ready")
                        .accessibilityIdentifier("sol.send")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color.mBg)
    }

    private func chips(_ c: SolConversation) -> some View {
        ForEach(c.suggestions, id: \.self) { suggestion in
            Button(suggestion) { send(c, suggestion) }
                .buttonStyle(PillButtonStyle(fill: .mCard, height: 38, horizontalPadding: 14))
                .font(.ui(14, weight: .regular))
        }
    }

    // MARK: Actions

    private func send(_ c: SolConversation, _ text: String? = nil) {
        voice.stop()
        Task { await c.send(text) }
    }

    /// Voice mode: talking to Sol turns his voice on so he answers aloud.
    private func toggleListening(_ c: SolConversation) {
        Task {
            if listener.isListening {
                await listener.stop()
                if !c.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { send(c) }
            } else {
                voice.stop()
                voice.isEnabled = true
                c.input = ""
                await listener.start { c.input = $0 }
            }
        }
    }

    private func openCitation(_ citation: SolCitation) {
        voice.stop()
        app.isSolPresented = false
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            app.openEntry(citation.entryID)
        }
    }

    private func makeReflection(_ c: SolConversation) {
        guard let engine else { return }
        drafting = true
        Task {
            let words = c.userMessages
            let text = (try? await engine.draftReflection(from: words)) ?? ReflectionTemplate.make(userMessages: words)
            draft = text
            drafting = false
            showDraft = true
        }
    }

    private func saveReflection() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let entry = Entry(notebookID: Notebook.reflections.id, mode: .sol, text: text, tagging: .pending)
        context.insert(entry)
        guard (try? context.save()) != nil else { return }
        services.tagging.enqueue(entry)
        conversation?.reset()
        app.didSave(entryID: entry.id)
    }

    private func discard() {
        voice.stop()
        conversation?.reset()
        app.isSolPresented = false
        app.select(.you)
    }

    private func close() {
        voice.stop()
        Task { await listener.stop() }
        conversation?.reset()
        app.isSolPresented = false
    }
}

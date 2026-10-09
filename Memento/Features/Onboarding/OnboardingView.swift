import SwiftUI
import MementoCore

/// Four-step welcome with a live tagging demo (prototype L62–173).
struct OnboardingView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = false
    @State private var step = 0
    @State private var demoPhase = 0
    @State private var demoTags: [DemoTag] = []
    @State private var activeID: UUID?

    static let demoText = "I felt drained after back-to-back deadlines today.\nA short walk helped me settle."

    struct DemoTag: Identifiable {
        let id = UUID()
        let draft: SuggestedTagDraft
        var status: TagStatus = .suggested
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch step {
                case 0: welcome
                case 1: example
                case 2: findAgain
                default: privacy
                }
            }
            .id(step)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) { footer }
        .background(Color.mBg.ignoresSafeArea())
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: step)
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaperArt(name: "onb-hero", height: 320, radius: 28)
            Text("MEMENTO").font(.ui(12, relativeTo: .caption1, weight: .semibold)).tracking(1.9).foregroundStyle(Color.mTer)
                .padding(.top, 30)
            Text("A journal that helps you notice.").font(.serif(40, relativeTo: .largeTitle)).tracking(-0.8)
                .foregroundStyle(Color.mInk).padding(.top, 12).fixedSize(horizontal: false, vertical: true)
            Text("Write the way you talk to yourself. Memento suggests what’s in there — how you felt, what was hard, what helped — so you can find those moments again.")
                .font(.ui(17)).foregroundStyle(Color.mMut).lineSpacing(4).padding(.top, 14)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var example: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Eyebrow("An example")
                Spacer()
                Button("Skip") { step = 3 }
                    .buttonStyle(LinkButtonStyle(color: .mMut))
                    .accessibilityIdentifier("onb.skip")
            }
            HStack(alignment: .center) {
                Text("Write naturally.").font(.serif(34, relativeTo: .largeTitle)).foregroundStyle(Color.mInk)
                Spacer()
                PaperIcon(name: "onb-notice", size: 56)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Today, 9:12 PM · Daily").font(.ui(12.5, relativeTo: .caption1)).foregroundStyle(Color.mMut)
                AnnotatedText(segments: TextSegments.build(text: Self.demoText, marks: demoPhase == 2 ? demoMarks : []),
                              activeID: activeID, font: .serif(22, relativeTo: .title3), lineSpacing: 10) { id in
                    activeID = activeID == id ? nil : id
                }
            }
            .paperCard(radius: 22, padding: 20)

            switch demoPhase {
            case 0:
                Button("Find the details", action: findDetails)
                    .buttonStyle(OutlineButtonStyle(color: .mTer, height: 50))
                    .accessibilityIdentifier("onb.findDetails")
                Text("After setup, this happens on your iPhone. Your entry isn’t sent to a server to be tagged.")
                    .font(.ui(14)).foregroundStyle(Color.mMut).fixedSize(horizontal: false, vertical: true)
            case 1:
                HStack(spacing: 10) {
                    Dot()
                    Text("Reading the entry…").font(.ui(15)).foregroundStyle(Color.mMut)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 4)
            default:
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("Memento noticed").padding(.bottom, 4)
                    ForEach($demoTags) { $tag in demoRow($tag) }
                    Text("Suggestions, not facts. Each points to the words behind it — tap one to see them. Keep only what feels true.")
                        .font(.ui(14)).foregroundStyle(Color.mMut).padding(.top, 6).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func demoRow(_ tag: Binding<DemoTag>) -> some View {
        let t = tag.wrappedValue
        let active = activeID == t.id
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                TagChip(label: t.draft.label, kind: t.draft.kind, status: t.status == .kept ? .kept : .suggested)
                if let quote = t.draft.quote {
                    Text("“\(quote)”").font(.serif(15, italic: true)).foregroundStyle(Color.mMut)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            switch t.status {
            case .suggested:
                Button { tag.wrappedValue.status = .removed } label: { Image(systemName: "xmark").font(.ui(14)) }
                    .buttonStyle(CircleIconButtonStyle())
                    .accessibilityLabel("Remove \(t.draft.label)")
                Button("Keep") { tag.wrappedValue.status = .kept }
                    .buttonStyle(PillButtonStyle(fill: .mSageT, foreground: .mSage, border: nil))
                    .accessibilityLabel("Keep \(t.draft.label)")
            case .kept:
                Text("Kept ✓").font(.ui(14, weight: .semibold)).foregroundStyle(Color.mSage)
            case .removed:
                Button("Undo") { tag.wrappedValue.status = .suggested }.buttonStyle(LinkButtonStyle(size: 14))
            }
        }
        .padding(.vertical, 12)
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .background(RoundedRectangle(cornerRadius: 16).fill(active ? Color.mCard : .clear))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(active ? Color.mLine : .clear, lineWidth: 1))
        .opacity(t.status == .removed ? 0.5 : 1)
        .contentShape(Rectangle())
        .onTapGesture { activeID = active ? nil : t.id }
    }

    private var findAgain: some View {
        let walkKept = demoTags.contains { $0.draft.label == "Walking helped" && $0.status == .kept }
        let finds = [("Today", "A short walk helped me settle"), ("Tue, Oct 6", "Took the long way home through the park"),
                     ("Thu, Sep 24", "Walked to the corner shop just to get out of the flat"), ("Sat, Sep 12", "Long walk with Priya after work")]
        return VStack(alignment: .leading, spacing: 16) {
            PaperIcon(name: "onb-find", size: 56).padding(.top, 8)
            Text("…and find that part of your life again.").font(.serif(34, relativeTo: .largeTitle))
                .foregroundStyle(Color.mInk).fixedSize(horizontal: false, vertical: true)
            Text("Tap any kept tag to see every moment it appears, across all your notebooks.")
                .font(.ui(16)).foregroundStyle(Color.mMut).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    TagChip(label: "Walking helped", kind: .helped)
                    Spacer()
                    Text(walkKept ? "in 4 entries" : "in 3 earlier entries").font(.ui(13)).foregroundStyle(Color.mMut)
                }
                ForEach(Array(finds.dropFirst(walkKept ? 0 : 1)), id: \.1) { date, quote in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(date).font(.ui(12, relativeTo: .caption1)).foregroundStyle(Color.mMut)
                        AnnotatedText(segments: [TextSegment(text: quote, mark: QuoteMark(id: UUID(), kind: .helped, status: .kept, quote: quote))],
                                      font: .serif(17, relativeTo: .body), lineSpacing: 4)
                    }
                    .padding(.top, 12)
                    .overlay(alignment: .top) { Rectangle().fill(Color.mLine).frame(height: 1) }
                }
            }
            .paperCard(radius: 22, padding: 18)
            Text("Memento counts how often you’ve written about something. It won’t tell you what causes what.")
                .font(.ui(14)).foregroundStyle(Color.mMut).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 18) {
            PaperArt(name: "onb-private", height: 160, radius: 22).padding(.top, 8)
            Text("Private by design.").font(.serif(34, relativeTo: .largeTitle)).foregroundStyle(Color.mInk)
            VStack(alignment: .leading, spacing: 14) {
                if services.taggingUsesCloud {
                    bullet("This iPhone can’t run on-device AI, so tagging and Sol use cloud AI. Entry text is sent to get suggestions and isn’t kept by the AI provider.")
                    bullet("You can turn cloud AI off in You → On-device AI and tag by hand.")
                    bullet("Otherwise, writing only leaves your phone when you export or share it yourself.")
                } else {
                    bullet("Tagging runs on this iPhone. Your journal text isn’t sent to Memento or any server to be tagged.")
                    bullet("If on-device AI isn’t available, nothing switches to the cloud. You can always tag by hand.")
                    bullet("Writing only leaves your phone when you export or share it yourself.")
                }
            }
            AIStateCard(availability: services.ai.availability, cloud: services.taggingUsesCloud)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Dot().alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
            Text(text).font(.ui(15.5)).foregroundStyle(Color.mInk).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 18) {
            HStack(spacing: 6) {
                ForEach(0..<4) { i in
                    Capsule().fill(i == step ? Color.mTer : Color.mLine).frame(width: i == step ? 20 : 6, height: 6)
                }
            }
            .accessibilityHidden(true)
            Button(primaryLabel, action: primaryAction)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(step == 1 && demoPhase < 2)
                .accessibilityIdentifier("onb.primary")
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Color.mBg)
    }

    private var primaryLabel: String {
        switch step {
        case 0: "See how it works"
        case 1, 2: "Continue"
        default:
            switch services.ai.availability {
            case .preparing: "Start journaling while it gets ready"
            case .needsAppleIntelligence: "Set up later, start journaling"
            default: "Start journaling"
            }
        }
    }

    private func primaryAction() {
        if step < 3 { step += 1 } else { hasOnboarded = true }
    }

    // MARK: Demo

    private var demoMarks: [QuoteMark] {
        demoTags.compactMap { t in
            guard t.status != .removed, let q = t.draft.quote else { return nil }
            return QuoteMark(id: t.id, kind: t.draft.kind, status: t.status, quote: q)
        }
    }

    private func findDetails() {
        demoTags = RuleTagger.analyze(Self.demoText).map { DemoTag(draft: $0) }
        demoPhase = 1
        Task {
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.4 : 1.5))
            demoPhase = 2
        }
    }
}

import SwiftUI
import MementoCore

/// Pick the voice Sol speaks with, by ear. Lists the voices installed on this iPhone.
struct SolVoiceView: View {
    @AppStorage(SolVoice.choiceKey) private var choice = ""
    @State private var voice = SolVoice()
    @State private var options: [SolVoiceOption] = []

    var body: some View {
        Screen(spacing: 18, horizontalPadding: 16) {
            PageTitle("Sol’s voice", size: 34).padding(.horizontal, 4)
            Text("Tap a voice to hear Sol and choose it. Voices run on this iPhone.")
                .font(.ui(15)).foregroundStyle(Color.mMut).padding(.horizontal, 4)
            if !options.contains(where: { $0.tier >= .enhanced }) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Want a warmer, more natural Sol?").font(.ui(15, weight: .semibold)).foregroundStyle(Color.mInk)
                    Text("Download an Enhanced or Premium voice in Settings → Accessibility → Spoken Content → Voices → English. It shows up here, and Sol uses it automatically.")
                        .font(.ui(14)).foregroundStyle(Color.mMut).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .paperCard(radius: 16, padding: 14)
            }
            SettingsGroup {
                row(id: "", title: "Automatic", subtitle: automaticLabel)
            }
            ForEach(tiers, id: \.self) { tier in
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(tier.title).padding(.leading, 4)
                    SettingsGroup {
                        ForEach(options.filter { $0.tier == tier }) { option in
                            row(id: option.id, title: option.name, subtitle: option.accent)
                        }
                    }
                }
            }
        }
        .onAppear { options = SolVoice.options() }
        .onDisappear { voice.stop() }
    }

    private var tiers: [SolVoiceOption.Tier] {
        [.premium, .enhanced, .standard, .classic].filter { tier in options.contains { $0.tier == tier } }
    }

    private var automaticLabel: String {
        guard let best = options.first else { return "Best voice on this iPhone" }
        return "Best on this iPhone: \(best.name) (\(best.tier.title.lowercased()))"
    }

    private func row(id: String, title: String, subtitle: String) -> some View {
        Button {
            choice = id
            voice.preview(id.isEmpty ? nil : id)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.ui(17)).foregroundStyle(Color.mInk)
                    Text(subtitle).font(.ui(13)).foregroundStyle(Color.mMut)
                }
                Spacer()
                Image(systemName: "play.circle").font(.system(size: 20)).foregroundStyle(Color.mTer)
                    .accessibilityHidden(true)
                Image(systemName: "checkmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.mTer)
                    .opacity(choice == id ? 1 : 0)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityHint("Plays a sample and chooses this voice")
        .accessibilityAddTraits(choice == id ? .isSelected : [])
        .accessibilityIdentifier(id.isEmpty ? "voice.automatic" : "voice.\(title)")
    }
}

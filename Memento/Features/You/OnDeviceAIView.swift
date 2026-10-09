import SwiftUI
import MementoCore

/// Apple Intelligence status, toggles and what happens to your writing (prototype L460–490, spec §5.1).
struct OnDeviceAIView: View {
    @Environment(AppServices.self) private var services
    @AppStorage(SettingsKey.suggestTags) private var suggestTags = true
    @AppStorage(SettingsKey.solEnabled) private var solEnabled = true
    @AppStorage(SettingsKey.cloudFallback) private var cloudFallback = true

    var body: some View {
        Screen(spacing: 20, horizontalPadding: 16) {
            PageTitle("On-device AI", size: 34).padding(.horizontal, 4)
            AIStateCard(availability: services.ai.availability, style: .settings, cloud: services.taggingUsesCloud)
            if services.cloud != nil && services.ai.live == .unsupported {
                SettingsGroup {
                    toggleRow("Use cloud AI", "This iPhone can’t run on-device AI. Off keeps everything on this iPhone.", $cloudFallback)
                        .accessibilityIdentifier("ai.cloudFallback")
                }
                .onChange(of: cloudFallback) { services.setEngine() }
            }
            if services.ai.availability.isSupported {
                SettingsGroup {
                    toggleRow("Suggest tags after saving", "Feelings, situations, what helped, topics", $suggestTags)
                    toggleRow("Sol conversations", "Early — quality varies by device", $solEnabled)
                    SettingsRow(title: services.taggingUsesCloud ? "Cloud model" : "On-device model",
                                subtitle: services.taggingUsesCloud ? "Through OpenRouter" : "Managed by Apple Intelligence", showsChevron: false) {}
                        .allowsHitTesting(false)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("What happens to your writing").font(.serif(20, relativeTo: .title3)).foregroundStyle(Color.mInk)
                if services.taggingUsesCloud || services.solUsesCloud {
                    Text("This iPhone can’t run on-device AI, so entries you save and what you tell Sol are sent to OpenRouter to make suggestions and replies, routed only to providers with zero-data-retention policies. Memento has no server and keeps no copy. Turn off Use cloud AI to keep everything on this iPhone.")
                } else {
                    Text("Entries are read by the model on this iPhone to make suggestions. Journal text isn’t sent to Memento or third parties for tagging, and there is no cloud fallback if on-device processing fails.")
                }
                Text("Content leaves your phone only when you choose to — for example, exporting a summary PDF. Suggestions can be wrong; they take time and use some battery.")
            }
            .font(.ui(14))
            .foregroundStyle(Color.mMut)
            .lineSpacing(3)
            .padding(.horizontal, 4)
        }
        .onAppear { services.ai.refresh() }
    }

    private func toggleRow(_ title: String, _ subtitle: String, _ isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.ui(17)).foregroundStyle(Color.mInk)
                Text(subtitle).font(.ui(13)).foregroundStyle(Color.mMut)
            }
        }
        .toggleStyle(SageToggleStyle())
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 60)
    }
}

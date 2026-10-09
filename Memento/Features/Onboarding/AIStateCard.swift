import SwiftUI
import MementoCore

/// On-device AI status card shared by onboarding and the On-device AI screen (spec §5.1).
struct AIStateCard: View {
    enum Style { case onboarding, settings }

    let availability: AIAvailability
    var style: Style = .onboarding
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch availability {
            case .ready:
                heading(style == .settings ? "READY · WORKS OFFLINE" : "Ready on this iPhone", .mSage)
                body(style == .settings ? "Tag suggestions run on this iPhone, even in airplane mode." : "Tagging is set up and works offline.")
            case .needsAppleIntelligence:
                heading(style == .settings ? "TURN ON APPLE INTELLIGENCE" : "One-time setup", .mTer)
                body("Turn on Apple Intelligence in Settings to get on-device suggestions. Nothing is sent to the cloud.")
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(InkButtonStyle())
            case .preparing:
                heading(style == .settings ? "GETTING READY" : "Getting ready…", .mSage)
                IndeterminateBar()
                body("Apple Intelligence is downloading its on-device model. You can start writing meanwhile.")
            case .unsupported:
                if style == .settings { PaperArt(name: "ai-unavailable", height: 120, radius: 16) }
                heading(style == .settings ? "NOT AVAILABLE ON THIS IPHONE" : "Not available on this iPhone", .mUmb)
                body(style == .settings
                     ? "On-device tagging needs a newer iPhone. Memento won’t send your entries elsewhere instead. Manual tags power Discover, notebooks and summaries just the same."
                     : "This model can’t run on-device tagging. Journaling, notebooks, reminders and tags you add yourself all work fully.")
            }
        }
        .paperCard(radius: 20, padding: 18)
    }

    private func heading(_ text: String, _ color: Color) -> some View {
        Text(text).font(.ui(13, relativeTo: .footnote, weight: .semibold)).foregroundStyle(color)
    }

    private func body(_ text: String) -> some View {
        Text(text).font(.ui(15.5)).foregroundStyle(Color.mInk).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
    }
}

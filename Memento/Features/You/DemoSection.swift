import SwiftUI
import SwiftData
import MementoCore

/// Stage controls (spec D23): sample journal, clear, AI-state override and backup engines.
struct DemoSection: View {
    @Environment(AppModel.self) private var app
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var context
    @State private var confirmClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Demo").padding(.leading, 4)
            SettingsGroup {
                SettingsRow(title: "Load sample journal", showsChevron: false) {
                    let added = (try? SampleJournal.load(into: context, photo: SamplePhoto.data)) ?? 0
                    app.showToast(added == 0 ? "The sample journal is already here" : "Loaded \(added) sample entries")
                }
                .accessibilityIdentifier("demo.load")
                SettingsRow(title: "Clear journal", showsChevron: false) { confirmClear = true }
                    .accessibilityIdentifier("demo.clear")
                menuRow("AI state", value: services.ai.demoState.title, id: "demo.aiState") {
                    ForEach(DemoAIState.allCases, id: \.self) { state in
                        Button(state.title) { services.ai.demoState = state }
                    }
                }
                menuRow("Suggestion engine", value: services.taggingChoice == .demo ? "Built-in rules" : "On-device model", id: "demo.taggingEngine") {
                    Button("On-device model") { services.setEngine(tagging: .onDevice) }
                    Button("Built-in rules (backup)") { services.setEngine(tagging: .demo) }
                }
                menuRow("Sol engine", value: services.solChoice == .demo ? "Scripted" : "On-device model", id: "demo.solEngine") {
                    Button("On-device model") { services.setEngine(sol: .onDevice) }
                    Button("Scripted (backup)") { services.setEngine(sol: .demo) }
                }
            }
            Text("For demos: preview every AI state and switch to backup engines. Nothing here sends data anywhere.")
                .font(.ui(13)).foregroundStyle(Color.mMut).padding(.horizontal, 4)
        }
        .confirmationDialog("Delete every entry on this iPhone?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Delete all entries", role: .destructive) {
                try? SampleJournal.clear(from: context)
                app.showToast("Journal cleared")
            }
        }
    }

    private func menuRow<Items: View>(_ title: String, value: String, id: String, @ViewBuilder items: () -> Items) -> some View {
        Menu {
            items()
        } label: {
            HStack(spacing: 12) {
                Text(title).font(.ui(17)).foregroundStyle(Color.mInk)
                Spacer()
                Text(value).font(.ui(16)).foregroundStyle(Color.mMut)
                Image(systemName: "chevron.up.chevron.down").font(.ui(12)).foregroundStyle(Color.mMut)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

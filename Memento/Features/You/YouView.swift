import SwiftUI
import SwiftData
import MementoCore

/// Reminders and streak, summaries, Sol, on-device AI, appearance and export (prototype L406–427).
struct YouView: View {
    @Environment(AppModel.self) private var app
    @Environment(AppServices.self) private var services
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @AppStorage(SettingsKey.reminderOn) private var reminderOn = false
    @AppStorage(SettingsKey.reminderMinutes) private var reminderMinutes = 1230
    @AppStorage(SettingsKey.appearance) private var appearance = Appearance.system
    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = true
    @State private var exportURL: URL?

    var body: some View {
        let streak = Streak.compute(entryDates: entries.map(\.createdAt), today: .now)
        Screen(spacing: 22, horizontalPadding: 16) {
            PageTitle("You").padding(.horizontal, 4).padding(.top, 4)
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(streak.count)-day streak").font(.serif(24, relativeTo: .title2)).foregroundStyle(Color.mTer)
                    Text("Saved entries and Sol reflections both count. Missed days never erase what you’ve written.")
                        .font(.ui(14)).foregroundStyle(Color.mInk).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                PaperIcon(name: "streak-sprout", size: 48)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.mTerT))
            SettingsGroup {
                SettingsRow(title: "Daily reminder", value: reminderOn ? ReminderScheduler.label(minutes: reminderMinutes) : "Off") { app.push(.reminders) }
                    .accessibilityIdentifier("row.reminders")
                SettingsRow(title: "Summaries") { app.push(.summary(SummarySeed(ids: nil))) }
                SettingsRow(title: "Reflect with Sol") { app.openSol() }
                    .accessibilityIdentifier("row.sol")
            }
            SettingsGroup {
                SettingsRow(title: "On-device AI", value: services.ai.label) { app.push(.onDeviceAI) }
                    .accessibilityIdentifier("row.onDeviceAI")
                HStack {
                    Text("Appearance").font(.ui(17)).foregroundStyle(Color.mInk)
                    Spacer()
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.mMut)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                if let exportURL {
                    ShareLink(item: exportURL, preview: SharePreview("Memento – journal export.pdf")) {
                        HStack {
                            Text("Export journal").font(.ui(17)).foregroundStyle(Color.mInk)
                            Spacer()
                            Image(systemName: "square.and.arrow.up").foregroundStyle(Color.mMut)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    SettingsRow(title: "Export journal", value: "No entries yet", showsChevron: false) {}
                        .disabled(true)
                }
                SettingsRow(title: "Replay welcome") { hasOnboarded = false }
            }
            DemoSection()
        }
        .task(id: entries.count) { exportURL = makeExport() }
    }

    private func makeExport() -> URL? {
        guard !entries.isEmpty else { return nil }
        return try? PDFComposer.write(PDFComposer.render(PDFComposer.journal(entries)), name: "Memento – journal export.pdf")
    }
}

import SwiftUI
import SwiftData
import MementoCore

struct RootView: View {
    @Environment(AppServices.self) private var services
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = false
    @AppStorage(SettingsKey.appearance) private var appearance = Appearance.system

    var body: some View {
        @Bindable var app = app
        Group {
            if hasOnboarded {
                TabView(selection: $app.tab) {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        NavigationStack(path: app.binding(for: tab)) {
                            tabRoot(tab)
                                .toolbar(.hidden, for: .navigationBar)
                                .navigationDestination(for: Route.self) { destination($0) }
                        }
                        .toolbarVisibility(.hidden, for: .tabBar)
                        .tag(tab)
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { MementoTabBar() }
            } else {
                OnboardingView()
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = app.toast {
                ToastView(toast: toast) { app.dismissToast() }
                    .padding(.horizontal, 16)
                    .padding(.bottom, hasOnboarded ? 76 : 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: app.toast?.id)
        .sheet(item: $app.sheet) { sheetView($0) }
        .fullScreenCover(item: $app.editorMode) { _ in EditorView() }
        .fullScreenCover(isPresented: $app.isSolPresented) { SolView() }
        .tint(.mTer)
        .preferredColorScheme(appearance.colorScheme)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            services.ai.refresh()
            services.tagging.resumePending()
        }
        .task { await services.checkPainting() }
    }

    @ViewBuilder
    private func tabRoot(_ tab: AppTab) -> some View {
        switch tab {
        case .journal: JournalView()
        case .discover: DiscoverView()
        case .notebooks: NotebooksView()
        case .you: YouView()
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        Group {
            switch route {
            case .entry(let id): EntryDetailView(entryID: id)
            case .tag(let label): TagDetailView(label: label)
            case .notebook(let id): NotebookDetailView(notebookID: id)
            case .reminders: RemindersView()
            case .onDeviceAI: OnDeviceAIView()
            case .solVoice: SolVoiceView()
            case .summary(let seed): SummaryView(seed: seed)
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Color.mBg, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func sheetView(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .write: WriteSheet()
        case .addTag(let id): TagFormSheet(entryID: id, tagID: nil)
        case .editTag(let entry, let tag): TagFormSheet(entryID: entry, tagID: tag)
        case .move(let id): MoveSheet(entryID: id)
        }
    }
}

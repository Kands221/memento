import SwiftUI
import Observation
import MementoCore

/// The writer's in-progress entry; survives mode switches and Cancel (prototype draft).
struct Draft {
    var mode: WritingMode = .free
    var text = ""
    var promptCategory: PromptCategory = .mind
    var promptIndex = 0
    var photo: Data?
    var notebookID = Notebook.daily.id

    var prompt: String { promptCategory.prompts[promptIndex % promptCategory.prompts.count] }
    var canSave: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (mode == .photo && photo != nil) }
}

/// Navigation, presentation and transient UI state.
@Observable
final class AppModel {
    var tab: AppTab = .journal
    var paths: [AppTab: [Route]] = [:]
    var sheet: ActiveSheet?
    var editorMode: WritingMode?
    var isSolPresented = false
    var toast: Toast?
    var justSavedID: UUID?
    var draft = Draft()
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    func binding(for tab: AppTab) -> Binding<[Route]> {
        Binding(get: { self.paths[tab] ?? [] }, set: { self.paths[tab] = $0 })
    }

    func push(_ route: Route) { paths[tab, default: []].append(route) }

    /// Switching tabs returns that tab to its root (prototype tabTo).
    func select(_ newTab: AppTab) {
        paths[newTab] = []
        tab = newTab
    }

    func openEntry(_ id: UUID) { push(.entry(id)) }
    func openTag(_ label: String) { push(.tag(label)) }

    func openEditor(_ mode: WritingMode) {
        draft.mode = mode
        afterSheetDismiss { self.editorMode = mode }
    }

    func openSol() {
        afterSheetDismiss { self.isSolPresented = true }
    }

    /// Full-screen covers can't present while a sheet is still animating away.
    private func afterSheetDismiss(_ present: @escaping () -> Void) {
        guard sheet != nil else { return present() }
        sheet = nil
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            present()
        }
    }

    func showToast(_ text: String, undo: (() -> Void)? = nil) {
        let toast = Toast(text: text, undo: undo)
        self.toast = toast
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4.5))
            guard !Task.isCancelled, self?.toast?.id == toast.id else { return }
            self?.toast = nil
        }
    }

    func dismissToast() { toast = nil }

    /// After a save from the editor or Sol: close covers and show the new entry.
    func didSave(entryID: UUID) {
        editorMode = nil
        isSolPresented = false
        sheet = nil
        justSavedID = entryID
        draft = Draft()
        push(.entry(entryID))
    }
}

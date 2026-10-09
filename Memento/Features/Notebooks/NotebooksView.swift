import SwiftUI
import SwiftData
import MementoCore

/// Cloth-cover grid of the four notebooks (prototype L372–385).
struct NotebooksView: View {
    @Environment(AppModel.self) private var app
    @Query private var entries: [Entry]

    var body: some View {
        Screen(spacing: 6) {
            PageTitle("Notebooks").padding(.top, 4)
            Text("\(Notebook.all.count) notebooks · \(entries.count) \(entries.count == 1 ? "entry" : "entries")")
                .font(.ui(14)).foregroundStyle(Color.mMut)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)], spacing: 22) {
                ForEach(Notebook.all) { notebook in
                    let count = entries.filter { $0.notebookID == notebook.id }.count
                    Button { app.push(.notebook(notebook.id)) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            NotebookCover(notebook: notebook)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(notebook.name).font(.ui(15, weight: .semibold)).foregroundStyle(Color.mInk)
                                Text("\(count) \(count == 1 ? "entry" : "entries")").font(.ui(13)).foregroundStyle(Color.mMut)
                            }
                            .padding(.leading, 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("notebook.\(notebook.id)")
                }
            }
            .padding(.top, 18)
        }
    }
}

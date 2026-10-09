import SwiftUI
import SwiftData
import MementoCore

/// Notebook list with cover swatches and a check on the current one.
struct NotebookList: View {
    let title: String
    let current: String
    let onPick: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.serif(24, relativeTo: .title2)).foregroundStyle(Color.mInk)
            VStack(spacing: 0) {
                ForEach(Notebook.all) { notebook in
                    Button { onPick(notebook.id) } label: {
                        HStack(spacing: 12) {
                            UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 2, bottomTrailingRadius: 5, topTrailingRadius: 5)
                                .fill(Color(hex: notebook.coverHex)).frame(width: 22, height: 28)
                            Text(notebook.name).font(.ui(17)).foregroundStyle(Color.mInk)
                            Spacer()
                            if notebook.id == current {
                                Image(systemName: "checkmark").font(.ui(17, weight: .bold)).foregroundStyle(Color.mTer)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 54)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("notebook.option.\(notebook.id)")
                    .accessibilityAddTraits(notebook.id == current ? .isSelected : [])
                    if notebook.id != Notebook.all.last?.id { Rectangle().fill(Color.mLine).frame(height: 1) }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.mCard))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.mLine, lineWidth: 1))
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Color.mSheet)
    }
}

/// Move an entry to another notebook, with Undo (prototype moveTo).
struct MoveSheet: View {
    let entryID: UUID
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [Entry]

    init(entryID: UUID) {
        self.entryID = entryID
        _entries = Query(filter: #Predicate<Entry> { $0.id == entryID })
    }

    var body: some View {
        NotebookList(title: "Move to notebook", current: entries.first?.notebookID ?? "") { id in
            if let entry = entries.first { EntryActions.move(entry, to: id, app: app, context: context) }
            dismiss()
        }
    }
}

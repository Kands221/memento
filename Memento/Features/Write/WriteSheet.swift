import SwiftUI
import MementoCore

/// One sheet for every writing mode, with Sol below as an option (prototype L612–624).
struct WriteSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    private let modes: [(WritingMode, String, String)] = [
        (.free, "Write freely", "An open page."),
        (.dump, "Brain dump", "Three gentle minutes. Don’t stop to fix."),
        (.guided, "Guided reflection", "Gratitude, your day, or what’s on your mind."),
        (.photo, "Photo journal", "Start with a picture. Words optional."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Start writing").font(.serif(26, relativeTo: .title1)).foregroundStyle(Color.mInk)
                    Spacer()
                    Button("Cancel") { dismiss() }.buttonStyle(LinkButtonStyle(size: 16))
                }
                ForEach(modes, id: \.0) { mode, title, detail in
                    row(icon: "mode-\(mode.rawValue)", title: title, detail: detail, dashed: false) { app.openEditor(mode) }
                        .accessibilityIdentifier("write.mode.\(mode.rawValue)")
                }
                row(icon: "sol-mark", title: "Reflect with Sol", detail: "Talk it through, then save a reflection. Optional.", dashed: true) { app.openSol() }
                    .padding(.top, 4)
                    .accessibilityIdentifier("write.sol")
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 30)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.fraction(0.8), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Color.mSheet)
    }

    private func row(icon: String, title: String, detail: String, dashed: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                PaperIcon(name: icon, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.ui(16.5, weight: .semibold)).foregroundStyle(Color.mInk)
                    Text(detail).font(.ui(14)).foregroundStyle(Color.mMut).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background { if !dashed { RoundedRectangle(cornerRadius: 18).fill(Color.mCard) } }
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.mLine, style: StrokeStyle(lineWidth: 1, dash: dashed ? [4, 3] : []))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI
import MementoCore

/// Edit the reflection Sol drafted from the writer's own words (prototype L523–536).
struct SolDraftView: View {
    @Binding var text: String
    var onBack: () -> Void
    var onSave: () -> Void
    var onDiscard: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Back", action: onBack).buttonStyle(LinkButtonStyle(size: 17)).fontWeight(.regular)
                Spacer()
                Button("Save to journal", action: onSave).buttonStyle(LinkButtonStyle(size: 17))
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 12) {
                        Text("Your reflection").font(.serif(32, relativeTo: .largeTitle)).foregroundStyle(Color.mInk)
                        Spacer()
                        PaperIcon(name: "sol-reflect", size: 64, disc: false)
                    }
                    Text("Drafted on this iPhone from your own words. Change anything — what you save is yours. Saves to Reflections and counts toward your streak.")
                        .font(.ui(14)).foregroundStyle(Color.mMut).fixedSize(horizontal: false, vertical: true)
                    TextEditor(text: $text)
                        .font(.serif(20, relativeTo: .body))
                        .lineSpacing(9)
                        .foregroundStyle(Color.mInk)
                        .scrollContentBackground(.hidden)
                        .padding(14)
                        .frame(minHeight: 380)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.mCard))
                        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.mLine, lineWidth: 1))
                        .padding(.top, 10)
                        .accessibilityIdentifier("solDraft.text")
                    Button("Discard conversation", action: onDiscard)
                        .buttonStyle(LinkButtonStyle(color: .mMut, size: 15)).fontWeight(.regular)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
            }
        }
        .background(Color.mBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

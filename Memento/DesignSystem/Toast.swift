import SwiftUI

/// A transient confirmation with optional Undo (prototype toast, 4.5 s).
struct Toast: Identifiable {
    let id = UUID()
    let text: String
    var undo: (() -> Void)?
}

struct ToastView: View {
    let toast: Toast
    var dismiss: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            Text(toast.text).font(.ui(15)).frame(maxWidth: .infinity, alignment: .leading)
            if let undo = toast.undo {
                Button("Undo") { undo(); dismiss() }
                    .font(.ui(15, weight: .bold))
                    .foregroundStyle(Color.mTerT)
                    .accessibilityIdentifier("toast.undo")
            }
        }
        .foregroundStyle(Color.mBg)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.mInk))
        .shadow(color: .black.opacity(0.4), radius: 15, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("toast")
    }
}

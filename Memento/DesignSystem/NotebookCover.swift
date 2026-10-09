import SwiftUI
import MementoCore

/// Cloth notebook cover with a label plate (prototype coverSt).
struct NotebookCover: View {
    let notebook: Notebook
    var showsLabel = true

    var body: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 5, bottomTrailingRadius: 14, topTrailingRadius: 14)
        ZStack {
            Color(hex: notebook.coverHex)
            if let image = UIImage(named: notebook.coverAsset) {
                Image(uiImage: image).resizable().scaledToFill()
            }
            if showsLabel { LabelPlate(name: notebook.name).offset(y: -24) }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(shape)
        .overlay(alignment: .leading) { Rectangle().fill(.black.opacity(0.13)).frame(width: 9).clipShape(shape) }
        .shadow(color: Color(red: 40 / 255, green: 25 / 255, blue: 10 / 255).opacity(0.45), radius: 11, y: 12)
        .accessibilityHidden(true)
    }
}

/// Cream label plate with a rule, used on covers and the notebook band.
struct LabelPlate: View {
    let name: String
    var size: CGFloat = 18

    var body: some View {
        VStack(spacing: 6) {
            Text(name).font(.serif(size, relativeTo: .headline)).foregroundStyle(Color(hex: 0x2B2723))
            Rectangle().fill(Color(hex: 0xC9BBA5)).frame(width: 40, height: 1)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(minWidth: 84)
        .background(RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0xF7F1E6)))
        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
    }
}

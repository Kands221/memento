import SwiftUI
import UIKit

/// A generated paper-cut illustration inside a cream paper card (spec D19).
/// Falls back to the prototype's hatched placeholder when the asset is missing,
/// so the app never depends on image generation having finished.
struct PaperArt: View {
    let name: String
    var height: CGFloat = 200
    var radius: CGFloat = 24
    var contentMode: ContentMode = .fit

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius).fill(Color(hex: 0xFFFCF6))
            if let image = UIImage(named: name) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                HatchedPlaceholder(label: name)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color.mLine, lineWidth: 1))
        .accessibilityHidden(true)
    }
}

/// A small generated icon or emblem on a card-coloured disc.
struct PaperIcon: View {
    let name: String
    var size: CGFloat = 40
    var disc = true

    var body: some View {
        Group {
            if let image = UIImage(named: name) {
                Image(uiImage: image).resizable().scaledToFit()
                    .padding(disc ? size * 0.06 : 0)
            } else {
                Circle().fill(Color.mTerT).padding(size * 0.2)
            }
        }
        .frame(width: size, height: size)
        .background { if disc { Circle().fill(Color(hex: 0xFFFCF6)) } }
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

/// Diagonal hatching with a mono caption, as in the prototype's placeholders.
struct HatchedPlaceholder: View {
    var label: String

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            var x: CGFloat = -size.height
            while x < size.width {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += 9
            }
            ctx.stroke(path, with: .color(.mLine), lineWidth: 1)
        }
        .overlay(alignment: .bottomLeading) {
            Text(label).font(.mono(11, relativeTo: .caption2)).foregroundStyle(Color.mMut).padding(12)
        }
    }
}

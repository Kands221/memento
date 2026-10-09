import UIKit

enum PhotoProcessing {
    /// Downscales to at most 2048 px on the long side and encodes JPEG at 0.85 (spec §9).
    static func jpegData(from image: UIImage, maxDimension: CGFloat = 2048) -> Data? {
        let longSide = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / max(longSide, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.85)
    }
}

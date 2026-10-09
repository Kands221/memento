import Foundation
import ImagePlayground
import UIKit

/// "Paint this day": an on-device Image Playground illustration made from the entry's words.
/// Only on-device styles are ever used — never `.externalProvider`, which leaves the device.
enum EntryArtist {
    private static let onDeviceStyles: [ImagePlaygroundStyle] = [.illustration, .sketch, .animation]

    static func isAvailable() async -> Bool {
        guard let creator = try? await ImageCreator() else { return false }
        return creator.availableStyles.contains { onDeviceStyles.contains($0) }
    }

    static func paint(_ text: String) async throws -> Data {
        let creator = try await ImageCreator()
        guard let style = onDeviceStyles.first(where: { creator.availableStyles.contains($0) }) else {
            throw CocoaError(.featureUnsupported)
        }
        let concept = ImagePlaygroundConcept.extracted(from: String(text.prefix(1_200)), title: nil)
        for try await image in creator.images(for: [concept], style: style, limit: 1) {
            if let data = UIImage(cgImage: image.cgImage).jpegData(compressionQuality: 0.85) { return data }
        }
        throw CocoaError(.fileWriteUnknown)
    }
}

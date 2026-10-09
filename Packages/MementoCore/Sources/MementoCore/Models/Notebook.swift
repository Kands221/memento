import Foundation

/// The four fixed notebooks from the design (spec D20).
public struct Notebook: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    /// 0xRRGGBB cloth colour from the prototype.
    public let coverHex: UInt32
    /// Asset-catalog name of the generated cover.
    public let coverAsset: String

    public static let daily = Notebook(id: "daily", name: "Daily", coverHex: 0xB4633F, coverAsset: "cover-daily")
    public static let work = Notebook(id: "work", name: "Work", coverHex: 0x3B3733, coverAsset: "cover-work")
    public static let gratitude = Notebook(id: "grat", name: "Gratitude", coverHex: 0x7F9679, coverAsset: "cover-gratitude")
    public static let reflections = Notebook(id: "refl", name: "Reflections", coverHex: 0xC8B186, coverAsset: "cover-reflections")

    public static let all: [Notebook] = [.daily, .work, .gratitude, .reflections]

    public static func with(id: String) -> Notebook {
        all.first { $0.id == id } ?? .daily
    }
}

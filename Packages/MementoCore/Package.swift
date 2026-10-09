// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MementoCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "MementoCore", targets: ["MementoCore"])],
    targets: [
        .target(name: "MementoCore"),
        .testTarget(name: "MementoCoreTests", dependencies: ["MementoCore"]),
    ]
)

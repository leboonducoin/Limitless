// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Limitless",
    platforms: [.macOS(.v26)],
    products: [.library(name: "LimitlessCore", targets: ["LimitlessCore"])],
    targets: [
        .target(name: "LimitlessCore"),
        .testTarget(name: "LimitlessCoreTests", dependencies: ["LimitlessCore"]),
    ],
    swiftLanguageModes: [.v6]
)

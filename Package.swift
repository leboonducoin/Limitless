// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Limitless",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "LimitlessCore", targets: ["LimitlessCore"]),
        .library(name: "LimitlessSystem", targets: ["LimitlessSystem"]),
        .executable(name: "LimitlessHelper", targets: ["LimitlessHelper"]),
    ],
    targets: [
        .target(name: "LimitlessCore"),
        .target(name: "LimitlessSystem", dependencies: ["LimitlessCore"]),
        .executableTarget(
            name: "LimitlessHelper", dependencies: ["LimitlessSystem", "LimitlessCore"]),
        .testTarget(name: "LimitlessCoreTests", dependencies: ["LimitlessCore"]),
        .testTarget(name: "LimitlessSystemTests", dependencies: ["LimitlessSystem"]),
    ],
    swiftLanguageModes: [.v6]
)

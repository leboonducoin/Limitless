// swift-tools-version: 6.2

import Foundation
import PackageDescription

func metadataLinkerSettings(_ environment: String) -> [LinkerSetting] {
    ProcessInfo.processInfo.environment[environment].map { directory in
        [
            .unsafeFlags([
                "-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist",
                "-Xlinker", directory + "/HelperInfo.plist",
                "-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__launchd_plist",
                "-Xlinker", directory + "/HelperLaunchd.plist",
            ])
        ]
    } ?? []
}

let package = Package(
    name: "Limitless",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LimitlessCore", targets: ["LimitlessCore"]),
        .library(name: "LimitlessSystem", targets: ["LimitlessSystem"]),
        .executable(name: "LimitlessHelper", targets: ["LimitlessHelper"]),
        .executable(name: "limitless", targets: ["LimitlessCLI"]),
        .executable(name: "LimitlessApp", targets: ["LimitlessApp"]),
        .executable(name: "LimitlessSudo", targets: ["LimitlessSudo"]),
        .executable(name: "LimitlessSudoHelper", targets: ["LimitlessSudoHelper"]),
    ],
    targets: [
        .target(name: "LimitlessCore"),
        .target(name: "LimitlessSystem", dependencies: ["LimitlessCore"]),
        .executableTarget(
            name: "LimitlessHelper", dependencies: ["LimitlessSystem", "LimitlessCore"],
            linkerSettings: metadataLinkerSettings("LIMITLESS_HELPER_METADATA")),
        .testTarget(name: "LimitlessCoreTests", dependencies: ["LimitlessCore"]),
        .executableTarget(
            name: "LimitlessCLI", dependencies: ["LimitlessSystem", "LimitlessCore"]),
        .testTarget(name: "LimitlessCLITests", dependencies: ["LimitlessCLI"]),
        .executableTarget(
            name: "LimitlessApp", dependencies: ["LimitlessSystem", "LimitlessCore"]),
        .testTarget(name: "LimitlessAppTests", dependencies: ["LimitlessApp"]),
        .testTarget(name: "LimitlessSystemTests", dependencies: ["LimitlessSystem"]),
        .executableTarget(name: "LimitlessSudo", dependencies: ["LimitlessSystem"]),
        .executableTarget(
            name: "LimitlessSudoHelper", dependencies: ["LimitlessSystem", "LimitlessCore"],
            linkerSettings: metadataLinkerSettings("LIMITLESS_SUDO_METADATA")),
    ],
    swiftLanguageModes: [.v6]
)

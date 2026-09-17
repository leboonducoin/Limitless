// swift-tools-version: 6.2

import Foundation
import PackageDescription

// Set only by the community bundle recipe; no privileged service is installed by a build.
let helperLinkerSettings: [LinkerSetting] =
    ProcessInfo.processInfo.environment["LIMITLESS_HELPER_METADATA"].map { directory in
        [
            .unsafeFlags([
                "-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist",
                "-Xlinker", directory + "/HelperInfo.plist",
                "-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__launchd_plist",
                "-Xlinker", directory + "/HelperLaunchd.plist",
            ])
        ]
    } ?? []

let package = Package(
    name: "Limitless",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "LimitlessCore", targets: ["LimitlessCore"]),
        .library(name: "LimitlessSystem", targets: ["LimitlessSystem"]),
        .executable(name: "LimitlessHelper", targets: ["LimitlessHelper"]),
        .executable(name: "limitless", targets: ["LimitlessCLI"]),
        .executable(name: "LimitlessApp", targets: ["LimitlessApp"]),
    ],
    targets: [
        .target(name: "LimitlessCore"),
        .target(name: "LimitlessSystem", dependencies: ["LimitlessCore"]),
        .executableTarget(
            name: "LimitlessHelper", dependencies: ["LimitlessSystem", "LimitlessCore"],
            linkerSettings: helperLinkerSettings),
        .testTarget(name: "LimitlessCoreTests", dependencies: ["LimitlessCore"]),
        .executableTarget(
            name: "LimitlessCLI", dependencies: ["LimitlessSystem", "LimitlessCore"]),
        .testTarget(name: "LimitlessCLITests", dependencies: ["LimitlessCLI"]),
        .executableTarget(
            name: "LimitlessApp", dependencies: ["LimitlessSystem", "LimitlessCore"]),
        .testTarget(name: "LimitlessAppTests", dependencies: ["LimitlessApp"]),
        .testTarget(name: "LimitlessSystemTests", dependencies: ["LimitlessSystem"]),
    ],
    swiftLanguageModes: [.v6]
)

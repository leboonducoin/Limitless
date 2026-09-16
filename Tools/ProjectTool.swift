import Foundation

// Run from the repository root: swift Tools/ProjectTool.swift check
func run(_ executable: String, _ arguments: [String], capture: Bool = false) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let pipe = capture ? Pipe() : nil
    if let pipe { process.standardOutput = pipe }
    if !capture { print("\(executable) \(arguments.joined(separator: " "))") }
    try process.run()
    let data = pipe?.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationReason == .exit, process.terminationStatus == 0 else {
        throw NSError(
            domain: "Limitless.ProjectTool", code: Int(process.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: "Check failed: \(executable)"])
    }
    return data.map {
        String(decoding: $0, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
        ?? ""
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    let sanitizer = ["asan": "address", "tsan": "thread"][arguments.first ?? ""]
    let bundle = arguments == ["bundle"]
    guard arguments.count == 1, arguments == ["check"] || sanitizer != nil || bundle else {
        throw NSError(
            domain: "Limitless.ProjectTool", code: 64,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Usage: swift Tools/ProjectTool.swift check | asan | tsan | bundle"
            ])
    }
    _ = try run("/usr/bin/git", ["diff", "--check"])
    _ = try run(
        "/usr/bin/xcrun",
        [
            "swift-format", "lint", "--strict", "--recursive", "Package.swift", "Sources", "Tests",
            "Tools",
        ])
    let developer =
        try ProcessInfo.processInfo.environment["DEVELOPER_DIR"]
        ?? run("/usr/bin/xcode-select", ["-p"], capture: true)
    let plugin = developer + "/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
    var compilerFlags = ["-Xswiftc", "-warnings-as-errors"]
    let buildPath =
        ProcessInfo.processInfo.environment["LIMITLESS_BUILD_PATH"]
        .map { ["--scratch-path", $0] } ?? []
    // CLT 6.4 ships the macro but SwiftPM does not discover its nested directory.
    // Load only the Apple-supplied plugin; no download or toolchain modification.
    if URL(fileURLWithPath: developer).lastPathComponent == "CommandLineTools",
        FileManager.default.fileExists(atPath: plugin)
    {
        compilerFlags += ["-Xswiftc", "-load-plugin-library", "-Xswiftc", plugin]
    }
    if bundle {
        let configuration =
            ProcessInfo.processInfo.environment["LIMITLESS_CONFIGURATION"] ?? "debug"
        guard ["debug", "release"].contains(configuration) else {
            throw NSError(
                domain: "Limitless.ProjectTool", code: 64,
                userInfo: [
                    NSLocalizedDescriptionKey: "LIMITLESS_CONFIGURATION must be debug or release."
                ])
        }
        _ = try run(
            "/usr/bin/xcrun", ["swift", "build", "-c", configuration] + buildPath + compilerFlags)
        let binaryPath = try run(
            "/usr/bin/xcrun",
            ["swift", "build", "-c", configuration, "--show-bin-path"] + buildPath, capture: true)
        let manager = FileManager.default
        let output =
            ProcessInfo.processInfo.environment["LIMITLESS_OUTPUT_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? manager.temporaryDirectory.appendingPathComponent(
                "Limitless-\(UUID().uuidString)", isDirectory: true)
        let app = output.appendingPathComponent("Limitless.app", isDirectory: true)
        guard !manager.fileExists(atPath: app.path) else { throw CocoaError(.fileWriteFileExists) }
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        for directory in ["MacOS", "Resources", "Library/LaunchDaemons", "Library/HelperTools"] {
            try manager.createDirectory(
                at: contents.appendingPathComponent(directory), withIntermediateDirectories: true)
        }
        for (source, destination) in [
            ("LimitlessApp", "MacOS/LimitlessApp"), ("limitless", "MacOS/limitless"),
            ("LimitlessHelper", "Library/HelperTools/LimitlessHelper"),
        ] {
            try manager.copyItem(
                at: URL(fileURLWithPath: binaryPath).appendingPathComponent(source),
                to: contents.appendingPathComponent(destination))
        }
        try manager.copyItem(
            at: URL(fileURLWithPath: "Packaging/Info.plist"),
            to: contents.appendingPathComponent("Info.plist"))
        let daemon = "io.github.leboonducoin.Limitless.helper.plist"
        try manager.copyItem(
            at: URL(fileURLWithPath: "Packaging/" + daemon),
            to: contents.appendingPathComponent("Library/LaunchDaemons/" + daemon))
        try manager.copyItem(
            at: URL(fileURLWithPath: "LICENSE"),
            to: contents.appendingPathComponent("Resources/LICENSE"))
        try manager.copyItem(
            at: URL(fileURLWithPath: "skills/limitless"),
            to: contents.appendingPathComponent("Resources/limitless-skill"))
        let iconTool = output.appendingPathComponent("export-icon")
        _ = try run(
            "/usr/bin/xcrun",
            [
                "swiftc", "-swift-version", "6", "-warnings-as-errors",
                "Sources/LimitlessApp/BrandArt.swift", "Tools/ExportIcon.swift", "-o",
                iconTool.path,
            ])
        let iconset = output.appendingPathComponent("Limitless.iconset")
        _ = try run(iconTool.path, [iconset.path])
        _ = try run(
            "/usr/bin/iconutil",
            [
                "-c", "icns", iconset.path, "-o",
                contents.appendingPathComponent("Resources/Limitless.icns").path,
            ])
        // Ad-hoc signatures permit local inspection, never privileged authentication or publication.
        for (path, identifier) in [
            ("MacOS/limitless", "io.github.leboonducoin.Limitless.cli"),
            ("Library/HelperTools/LimitlessHelper", "io.github.leboonducoin.Limitless.helper"),
        ] {
            _ = try run(
                "/usr/bin/codesign",
                [
                    "--force", "--sign", "-", "--identifier", identifier,
                    contents.appendingPathComponent(path).path,
                ])
        }
        _ = try run("/usr/bin/codesign", ["--force", "--sign", "-", app.path])
        _ = try run("/usr/bin/codesign", ["--verify", "--strict", "--deep", app.path])
        _ = try run(
            "/usr/bin/plutil",
            [
                "-lint", contents.appendingPathComponent("Info.plist").path,
                contents.appendingPathComponent("Library/LaunchDaemons/" + daemon).path,
            ])
        print(
            "Development bundle: \(app.path)\nNot installed, not notarized; privileged controls remain unavailable."
        )
    } else if let sanitizer {
        _ = try run(
            "/usr/bin/xcrun",
            ["swift", "test", "--sanitize", sanitizer] + buildPath + compilerFlags)
    } else {
        _ = try run(
            "/usr/bin/xcrun", ["swift", "build", "-c", "release"] + buildPath + compilerFlags)
        _ = try run(
            "/usr/bin/xcrun",
            ["swift", "test", "--enable-code-coverage"] + buildPath + compilerFlags)
    }
    if !bundle {
        print(
            "All current local checks passed. Signed integration and physical Mac checks are separate."
        )
    }
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
    exit(1)
}

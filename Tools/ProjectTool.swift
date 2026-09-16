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
    guard arguments.count == 1, arguments == ["check"] || sanitizer != nil else {
        throw NSError(
            domain: "Limitless.ProjectTool", code: 64,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Usage: swift Tools/ProjectTool.swift check | asan | tsan"
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
    if let sanitizer {
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
    print(
        "All current local checks passed. Signed integration and physical Mac checks are separate.")
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
    exit(1)
}

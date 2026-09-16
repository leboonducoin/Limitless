import CryptoKit
import Foundation
import Security

// Run from the repository root: swift Tools/ProjectTool.swift check
func run(_ executable: String, _ arguments: [String], capture: Bool = false, saveOutput: URL? = nil)
    throws -> String
{
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let pipe = capture ? Pipe() : nil
    if let pipe { process.standardOutput = pipe }
    if !capture { print("\(executable) \(arguments.joined(separator: " "))") }
    try process.run()
    let data = pipe?.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    if let saveOutput, let data { try data.write(to: saveOutput, options: .withoutOverwriting) }
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

func require(_ condition: Bool, _ message: String) throws {
    guard condition else {
        throw NSError(
            domain: "Limitless.ProjectTool", code: 1,
            userInfo: [NSLocalizedDescriptionKey: message])
    }
}

func matches(_ value: String, _ pattern: String) -> Bool {
    value.range(of: "\\A(?:" + pattern + ")\\z", options: .regularExpression) != nil
}

func propertyList(_ path: URL) throws -> [String: Any] {
    let value = try PropertyListSerialization.propertyList(
        from: Data(contentsOf: path), format: nil)
    guard let dictionary = value as? [String: Any] else {
        throw CocoaError(.propertyListReadCorrupt)
    }
    return dictionary
}

func cleanRevision() throws -> String {
    try require(
        try run("/usr/bin/git", ["status", "--porcelain", "--untracked-files=all"], capture: true)
            .isEmpty,
        "Release signing requires a clean, committed worktree.")
    let revision = try run("/usr/bin/git", ["rev-parse", "--verify", "HEAD"], capture: true)
    try require(matches(revision, "[0-9a-f]{40}"), "Expected a full Git source revision.")
    return revision
}

struct BuildRecord: Codable, Equatable {
    let sourceRevision: String
    let configuration: String
    let sourceClean: Bool
}

func developerRequirement(identifier: String, team: String) throws -> SecRequirement {
    try require(matches(team, "[A-Z0-9]{10}"), "Expected a ten-character Apple Team ID.")
    let value =
        "anchor apple generic and identifier \"\(identifier)\" "
        + "and certificate 1[field.1.2.840.113635.100.6.2.6] exists "
        + "and certificate leaf[field.1.2.840.113635.100.6.1.13] exists "
        + "and certificate leaf[subject.OU] = \"\(team)\""
    var requirement: SecRequirement?
    try require(
        SecRequirementCreateWithString(value as CFString, [], &requirement) == errSecSuccess,
        "Could not parse the Developer ID requirement.")
    guard let requirement else { throw CocoaError(.coderValueNotFound) }
    return requirement
}

func verifyCode(_ path: URL, identifier: String, team: String) throws {
    let requirement = try developerRequirement(identifier: identifier, team: team)
    var code: SecStaticCode?
    try require(
        SecStaticCodeCreateWithPath(path as CFURL, [], &code) == errSecSuccess,
        "Cannot read code signature: \(path.path)")
    guard let code else { throw CocoaError(.coderValueNotFound) }
    try require(
        SecStaticCodeCheckValidity(
            code,
            SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures),
            requirement) == errSecSuccess,
        "Developer ID, Team ID or code integrity check failed: \(path.path)")
    var information: CFDictionary?
    try require(
        SecCodeCopySigningInformation(
            code, SecCSFlags(rawValue: kSecCSSigningInformation),
            &information) == errSecSuccess,
        "Cannot inspect signing information: \(path.path)")
    try verifySigningInformation(information as? [String: Any] ?? [:])
}

func verifySigningInformation(_ details: [String: Any]) throws {
    let flags = (details[kSecCodeInfoFlags as String] as? NSNumber)?.uint32Value ?? 0
    try require(
        SecCodeSignatureFlags(rawValue: flags).contains(.runtime)
            && details[kSecCodeInfoTimestamp as String] is Date
            && details[kSecCodeInfoEntitlements as String] == nil
            && details[kSecCodeInfoEntitlementsDict as String] == nil,
        "Release code must have hardened runtime, a secure timestamp and no entitlements.")
}

func verifyRelease(_ app: URL, team: String, notarized: Bool) throws -> (String, BuildRecord) {
    try require(app.lastPathComponent == "Limitless.app", "Expected a Limitless.app bundle.")
    let identifier = "io.github.leboonducoin.Limitless"
    try verifyCode(app, identifier: identifier, team: team)
    for (relative, suffix) in [
        ("MacOS/limitless", ".cli"),
        ("Library/HelperTools/LimitlessHelper", ".helper"),
    ] {
        try verifyCode(
            app.appendingPathComponent("Contents/" + relative),
            identifier: identifier + suffix, team: team)
    }
    _ = try run("/usr/bin/codesign", ["--verify", "--strict", "--deep", app.path])
    let contents = app.appendingPathComponent("Contents")
    let info = try propertyList(contents.appendingPathComponent("Info.plist"))
    let version = info["CFBundleShortVersionString"] as? String ?? ""
    try require(
        matches(version, "(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)")
            && info["CFBundleIdentifier"] as? String == identifier
            && info["CFBundleExecutable"] as? String == "LimitlessApp"
            && info["LSMinimumSystemVersion"] as? String == "26.0",
        "Unexpected release bundle identity, version or macOS minimum.")
    for relative in [
        "MacOS/LimitlessApp", "MacOS/limitless", "Library/HelperTools/LimitlessHelper",
    ] {
        let architectures = try run(
            "/usr/bin/lipo", ["-archs", contents.appendingPathComponent(relative).path],
            capture: true)
        try require(architectures == "arm64", "This release recipe requires arm64-only binaries.")
    }
    let record = try JSONDecoder().decode(
        BuildRecord.self,
        from: Data(contentsOf: contents.appendingPathComponent("Resources/Build.json")))
    try require(
        record.configuration == "release" && record.sourceClean
            && matches(record.sourceRevision, "[0-9a-f]{40}"),
        "Release requires recorded, clean, committed Release sources.")
    if notarized {
        _ = try run("/usr/bin/xcrun", ["stapler", "validate", app.path])
        _ = try run("/usr/sbin/spctl", ["--assess", "--type", "execute", "--verbose=2", app.path])
    }
    return (version, record)
}

func cask(version: String, digest: String) throws -> String {
    try require(
        matches(version, "(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)")
            && matches(digest, "[0-9a-f]{64}"), "Invalid cask version or SHA-256.")
    return try String(contentsOfFile: "Packaging/limitless.rb.in", encoding: .utf8)
        .replacingOccurrences(of: "@VERSION@", with: version)
        .replacingOccurrences(of: "@SHA256@", with: digest)
}

func archive(_ app: URL, to destination: URL) throws {
    try require(
        !FileManager.default.fileExists(atPath: destination.path), "Archive already exists.")
    _ = try run(
        "/usr/bin/ditto",
        ["-c", "-k", "--sequesterRsrc", "--keepParent", app.path, destination.path])
}

func selfTest(developmentApp: URL? = nil) throws {
    func rejects(_ operation: () throws -> Void) throws {
        var accepted = false
        do {
            try operation()
            accepted = true
        } catch {}
        try require(!accepted, "Self-test accepted an invalid release input.")
    }
    let digest = SHA256.hash(data: Data("abc".utf8)).map { String(format: "%02x", $0) }.joined()
    try require(
        digest == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
        "SHA-256 self-test failed.")
    _ = try developerRequirement(identifier: "io.github.leboonducoin.Limitless", team: "0123456789")
    let signingInformation: [String: Any] = [
        kSecCodeInfoFlags as String: NSNumber(value: SecCodeSignatureFlags.runtime.rawValue),
        kSecCodeInfoTimestamp as String: Date(timeIntervalSince1970: 0),
    ]
    try verifySigningInformation(signingInformation)
    for key in [kSecCodeInfoFlags, kSecCodeInfoTimestamp] {
        var incomplete = signingInformation
        incomplete.removeValue(forKey: key as String)
        try rejects { try verifySigningInformation(incomplete) }
    }
    for (key, value) in [
        (kSecCodeInfoFlags, NSNumber(value: 0) as Any),
        (kSecCodeInfoTimestamp, "not a secure date" as Any),
        (kSecCodeInfoEntitlements, Data() as Any),
        (kSecCodeInfoEntitlementsDict, ["com.apple.security.get-task-allow": true] as Any),
    ] {
        var unsafe = signingInformation
        unsafe[key as String] = value
        try rejects { try verifySigningInformation(unsafe) }
    }
    for team in ["", "012345678", "01234567890", "012345678a", "0123456789\n", "\" or true"] {
        try rejects {
            _ = try developerRequirement(identifier: "io.github.leboonducoin.Limitless", team: team)
        }
    }
    for version in ["", "1.0", "01.0.0", "1.0.0-dev", "1.0.0\n", "#{system('false')}"] {
        try rejects { _ = try cask(version: version, digest: digest) }
    }
    try rejects { _ = try cask(version: "0.1.0", digest: digest + "\n") }
    let recipe = try cask(version: "0.1.0", digest: digest)
    try require(
        !recipe.contains("@VERSION@") && !recipe.contains("@SHA256@")
            && recipe.contains("--prepare-uninstall") && recipe.contains("must_succeed: true")
            && !recipe.contains("/Library/Application Support/Limitless"),
        "Cask must preserve guarded removal and substitute both release values.")
    _ = try run("/usr/bin/ruby", ["-c", "Packaging/limitless.rb.in"])
    if let developmentApp {
        try rejects { _ = try verifyRelease(developmentApp, team: "0123456789", notarized: false) }
    }
    print("Release input, cask and optional development-signature rejection checks passed.")
}

func distributionCommand(_ arguments: [String]) throws -> Bool {
    let command = arguments.first ?? ""
    if command == "self-test", (1...2).contains(arguments.count) {
        try selfTest(
            developmentApp: arguments.count == 2 ? URL(fileURLWithPath: arguments[1]) : nil)
        return true
    }
    guard ["verify", "notarize", "package"].contains(command) else { return false }
    try require(
        arguments.count == (command == "verify" ? 3 : 4),
        "Usage: verify APP TEAM | notarize APP TEAM KEYCHAIN_PROFILE | package APP TEAM NEW_OUTPUT_DIR"
    )
    try require(geteuid() != 0, "Distribution tools must run as a regular user.")
    let app = URL(fileURLWithPath: arguments[1])
    let team = arguments[2]
    let (version, record) = try verifyRelease(app, team: team, notarized: command != "notarize")
    if command == "notarize" {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(
            "Limitless-notary-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false)
        let zip = temporary.appendingPathComponent("Limitless.zip")
        try archive(app, to: zip)
        print("Submitting signed software to Apple. Diagnostic archive: \(zip.path)")
        let response = try run(
            "/usr/bin/xcrun",
            [
                "notarytool", "submit", zip.path,
                "--keychain-profile", arguments[3], "--wait", "--timeout", "30m", "--output-format",
                "json",
            ], capture: true, saveOutput: temporary.appendingPathComponent("response.json"))
        let result = try JSONSerialization.jsonObject(with: Data(response.utf8)) as? [String: Any]
        try require(
            result?["status"] as? String == "Accepted",
            "Apple did not accept this submission; inspect response.json and its submission ID.")
        _ = try run("/usr/bin/xcrun", ["stapler", "staple", app.path])
        _ = try verifyRelease(app, team: team, notarized: true)
        print("Notarized and stapled. Nothing published; archive again with the package command.")
    } else if command == "package" {
        try require(
            try cleanRevision() == record.sourceRevision,
            "Generate release metadata and cask from the same clean source revision as the app.")
        let output = URL(fileURLWithPath: arguments[3], isDirectory: true)
        try require(
            !output.resolvingSymlinksInPath().path.hasPrefix(
                app.resolvingSymlinksInPath().path + "/"),
            "Archive output must be outside the signed app.")
        try require(
            !FileManager.default.fileExists(atPath: output.path), "Output directory already exists."
        )
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
        let zip = output.appendingPathComponent("Limitless-\(version)-arm64.zip")
        try archive(app, to: zip)
        // Inspect the actual exported archive, not just its input bundle.
        let extracted = FileManager.default.temporaryDirectory.appendingPathComponent(
            "Limitless-verify-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: extracted) }
        _ = try run("/usr/bin/ditto", ["-x", "-k", zip.path, extracted.path])
        let (exportVersion, exportRecord) = try verifyRelease(
            extracted.appendingPathComponent("Limitless.app"), team: team, notarized: true)
        try require(
            exportVersion == version && exportRecord == record, "Exported archive metadata changed."
        )
        let digest = SHA256.hash(data: try Data(contentsOf: zip, options: .mappedIfSafe)).map {
            String(format: "%02x", $0)
        }.joined()
        try Data("\(digest)  \(zip.lastPathComponent)\n".utf8).write(
            to: output.appendingPathComponent("SHA256SUMS"), options: .withoutOverwriting)
        try Data(cask(version: version, digest: digest).utf8).write(
            to: output.appendingPathComponent("limitless.rb"), options: .withoutOverwriting)
        let manifest = [
            "version": version, "sourceRevision": record.sourceRevision, "teamID": team,
            "archive": zip.lastPathComponent, "sha256": digest,
        ]
        try JSONSerialization.data(
            withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]
        )
        .write(to: output.appendingPathComponent("release.json"), options: .withoutOverwriting)
        print(
            "Verified archive, digest, manifest and draft cask: \(output.path)\nNothing published. The cask URL becomes usable only after an authorized release."
        )
    } else {
        print(
            "Verified notarized Limitless \(version), source \(record.sourceRevision), team \(team)."
        )
    }
    return true
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if try distributionCommand(arguments) { exit(0) }
    let sanitizer = ["asan": "address", "tsan": "thread"][arguments.first ?? ""]
    let signing = arguments == ["sign"]
    let bundle = arguments == ["bundle"] || signing
    try require(
        arguments.count == 1 && (arguments == ["check"] || sanitizer != nil || bundle),
        "Usage: swift Tools/ProjectTool.swift check | asan | tsan | bundle | sign | self-test [APP] | verify APP TEAM | notarize APP TEAM KEYCHAIN_PROFILE | package APP TEAM NEW_OUTPUT_DIR"
    )
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
    let team = ProcessInfo.processInfo.environment["LIMITLESS_TEAM_ID"] ?? ""
    let certificate = ProcessInfo.processInfo.environment["LIMITLESS_SIGNING_IDENTITY"] ?? ""
    let sourceRevision = signing ? try cleanRevision() : nil
    if signing {
        try require(
            geteuid() != 0 && developer.hasSuffix(".app/Contents/Developer"),
            "Release signing requires full Xcode and a regular user.")
        _ = try developerRequirement(identifier: "io.github.leboonducoin.Limitless", team: team)
        try require(
            matches(certificate, "[0-9A-Fa-f]{40}"),
            "LIMITLESS_SIGNING_IDENTITY must be the certificate's SHA-1 fingerprint.")
    }
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
            signing
            ? "release" : ProcessInfo.processInfo.environment["LIMITLESS_CONFIGURATION"] ?? "debug"
        try require(
            ["debug", "release"].contains(configuration),
            "LIMITLESS_CONFIGURATION must be debug or release.")
        _ = try run(
            "/usr/bin/xcrun", ["swift", "build", "-c", configuration] + buildPath + compilerFlags)
        let binaryPath = try run(
            "/usr/bin/xcrun",
            ["swift", "build", "-c", configuration, "--show-bin-path"] + buildPath, capture: true)
        let info = try propertyList(URL(fileURLWithPath: "Packaging/Info.plist"))
        let version = info["CFBundleShortVersionString"] as? String ?? ""
        try require(
            try run(binaryPath + "/limitless", ["--version"], capture: true)
                == "Limitless \(version)",
            "CLI and bundle versions disagree.")
        let manager = FileManager.default
        let output =
            ProcessInfo.processInfo.environment["LIMITLESS_OUTPUT_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? manager.temporaryDirectory.appendingPathComponent(
                "Limitless-\(UUID().uuidString)", isDirectory: true)
        let app = output.appendingPathComponent("Limitless.app", isDirectory: true)
        guard !manager.fileExists(atPath: output.path) else {
            throw CocoaError(.fileWriteFileExists)
        }
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        for directory in [
            "MacOS", "Resources/limitless-skill", "Library/LaunchDaemons", "Library/HelperTools",
        ] {
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
            at: URL(fileURLWithPath: "skills/limitless/SKILL.md"),
            to: contents.appendingPathComponent("Resources/limitless-skill/SKILL.md"))
        let record = BuildRecord(
            sourceRevision: try run(
                "/usr/bin/git", ["rev-parse", "--verify", "HEAD"], capture: true),
            configuration: configuration,
            sourceClean: try run(
                "/usr/bin/git", ["status", "--porcelain", "--untracked-files=all"], capture: true
            ).isEmpty)
        try JSONEncoder().encode(record).write(
            to: contents.appendingPathComponent("Resources/Build.json"),
            options: .withoutOverwriting)
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
        if let sourceRevision {
            try require(
                try cleanRevision() == sourceRevision && record.sourceRevision == sourceRevision,
                "Source changed during the release build.")
        }
        // Sign nested executables explicitly before sealing the outer bundle.
        let signature = signing ? certificate : "-"
        let signingOptions = signing ? ["--options", "runtime", "--timestamp"] : []
        for (path, identifier) in [
            ("MacOS/limitless", "io.github.leboonducoin.Limitless.cli"),
            ("Library/HelperTools/LimitlessHelper", "io.github.leboonducoin.Limitless.helper"),
        ] {
            _ = try run(
                "/usr/bin/codesign",
                [
                    "--force", "--sign", signature, "--identifier", identifier,
                ] + signingOptions + [contents.appendingPathComponent(path).path])
        }
        _ = try run(
            "/usr/bin/codesign", ["--force", "--sign", signature] + signingOptions + [app.path])
        _ = try run("/usr/bin/codesign", ["--verify", "--strict", "--deep", app.path])
        _ = try run(
            "/usr/bin/plutil",
            [
                "-lint", contents.appendingPathComponent("Info.plist").path,
                contents.appendingPathComponent("Library/LaunchDaemons/" + daemon).path,
            ])
        if signing {
            _ = try verifyRelease(app, team: team, notarized: false)
            print("Developer ID bundle: \(app.path)\nNot installed, not notarized, not published.")
        } else {
            try selfTest(developmentApp: app)
            print(
                "Development bundle: \(app.path)\nNot installed, not notarized; privileged controls remain unavailable."
            )
        }
    } else if let sanitizer {
        _ = try run(
            "/usr/bin/xcrun",
            ["swift", "test", "--sanitize", sanitizer] + buildPath + compilerFlags)
    } else {
        try selfTest()
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

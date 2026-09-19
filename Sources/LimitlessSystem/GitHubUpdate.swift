import CryptoKit
import Darwin
import Foundation
import Security

public enum UpdateError: Error, LocalizedError, Sendable {
    case invalidRelease, invalidArchive, untrustedBuild, unsafeLocation, busy, failed

    public var errorDescription: String? {
        switch self {
        case .invalidRelease: "GitHub did not provide a valid Limitless release."
        case .invalidArchive: "The update archive failed verification."
        case .untrustedBuild: "The update must be signed by the same certificate as this app."
        case .unsafeLocation: "Move Limitless to a writable Applications folder before updating."
        case .busy: "Close the running Limitless app before replacing it."
        case .failed: "The update could not be completed. Reopen Limitless or retry."
        }
    }
}

/// Fixed public repository, no credentials, no privileged installation or executable paths over XPC.
public enum GitHubUpdate {
    public static let repository = URL(string: "https://github.com/leboonducoin/Limitless")!
    private static let latestURL = URL(
        string: "https://api.github.com/repos/leboonducoin/Limitless/releases/latest")!
    static let maximumArchiveSize = 64 * 1_024 * 1_024

    public struct Release: Equatable, Sendable {
        public let version: String
        let url: URL
        let size: Int
        let digest: String
    }

    public struct Staged: Sendable {
        public let app: URL
        public let directory: URL
    }

    private struct Response: Decodable {
        let tagName: String
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: URL
            let size: Int
            let digest: String?
        }
    }

    static func version(_ text: String) throws -> [Int] {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { throw UpdateError.invalidRelease }
        return try parts.map {
            guard !$0.isEmpty, $0.count <= 9,
                $0.utf8.allSatisfy({ (48...57).contains($0) }), let number = Int($0),
                String(number) == $0
            else { throw UpdateError.invalidRelease }
            return number
        }
    }

    static func release(from data: Data, currentVersion: String) throws -> Release? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(Response.self, from: data)
        guard !response.draft, !response.prerelease else { return nil }
        let name = response.tagName
        let candidate = name.hasPrefix("v") ? String(name.dropFirst()) : name
        guard try version(currentVersion).lexicographicallyPrecedes(version(candidate)) else {
            return nil
        }
        let archive = "Limitless-\(candidate)-arm64.zip"
        let assets = response.assets.filter { $0.name == archive }
        guard assets.count == 1, let asset = assets.first,
            asset.size > 0, asset.size <= maximumArchiveSize,
            asset.browserDownloadUrl.absoluteString == repository.absoluteString
                + "/releases/download/\(name)/\(archive)",
            let digest = asset.digest, digest.hasPrefix("sha256:"), digest.count == 71,
            digest.dropFirst(7).utf8.allSatisfy({
                (48...57).contains($0) || (97...102).contains($0)
            })
        else { throw UpdateError.invalidRelease }
        return Release(
            version: candidate, url: asset.browserDownloadUrl, size: asset.size,
            digest: String(digest.dropFirst(7)))
    }

    @concurrent public static func latest(currentVersion: String) async throws -> Release? {
        guard let data = try await download(latestURL, limit: 1_024 * 1_024, allowsMissing: true)
        else { return nil }
        return try release(from: data, currentVersion: currentVersion)
    }

    private static func download(_ url: URL, limit: Int, allowsMissing: Bool = false) async throws
        -> Data?
    {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 180
        let session = URLSession(
            configuration: configuration, delegate: GitHubRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.setValue("Limitless", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse,
            let finalURL = response.url, GitHubRedirects.allows(finalURL)
        else { throw UpdateError.invalidRelease }
        if allowsMissing, response.statusCode == 404 { return nil }
        guard response.statusCode == 200, response.expectedContentLength <= limit else {
            throw UpdateError.invalidRelease
        }
        var data = Data()
        for try await byte in bytes {
            guard data.count < limit else { throw UpdateError.invalidArchive }
            data.append(byte)
        }
        return data
    }

    @concurrent public static func stage(
        _ release: Release, identity: SignedIdentity, installedApp: URL
    ) async throws -> Staged {
        let target = try canonical(installedApp)
        try requireWritableApp(target)
        // Same volume for atomic replacement; private staging never overwrites an existing entry.
        let directory = target.deletingLastPathComponent().appendingPathComponent(
            ".Limitless-update-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700])
        var staged = false
        defer { if !staged { try? FileManager.default.removeItem(at: directory) } }
        guard let data = try await download(release.url, limit: release.size),
            data.count == release.size,
            SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == release.digest
        else { throw UpdateError.invalidArchive }
        let archive = directory.appendingPathComponent("update.zip")
        try data.write(to: archive, options: .withoutOverwriting)
        try await extract(archive, to: directory)
        let app = directory.appendingPathComponent("Limitless.app")
        try verify(app, identity: identity, newerThan: target, expectedVersion: release.version)
        try quarantine(app, downloadedFrom: release.url)
        staged = true
        return Staged(app: app, directory: directory)
    }

    static func quarantine(_ app: URL, downloadedFrom url: URL) throws {
        // URLSession does not apply quarantine itself. Let macOS make its normal launch decision.
        try (app as NSURL).setResourceValue(
            [
                "LSQuarantineAgentName": "Limitless",
                "LSQuarantineType": "LSQuarantineTypeOtherDownload",
                "LSQuarantineTimeStamp": Date(),
                "LSQuarantineOriginURL": repository,
                "LSQuarantineDataURL": url,
            ], forKey: .quarantinePropertiesKey)
        let properties =
            try app.resourceValues(forKeys: [.quarantinePropertiesKey]).allValues[
                .quarantinePropertiesKey] as? [String: Any]
        guard properties?["LSQuarantineAgentName"] as? String == "Limitless" else {
            throw UpdateError.invalidArchive
        }
    }

    /// Read the listing before extraction. Only plain files/directories with bounded total size.
    static func validateListing(_ listing: String) throws {
        let lines = listing.split(separator: "\n")
        guard !lines.isEmpty, lines.count <= 512 else { throw UpdateError.invalidArchive }
        var total = 0
        var names: Set<String> = []
        for line in lines {
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count == 9, let mode = fields.first,
                mode.first == "-" || mode.first == "d",
                !mode.contains("s"), !mode.contains("S"), !mode.contains("t"), !mode.contains("T"),
                let size = Int(fields[4]), (0...maximumArchiveSize * 4).contains(size)
            else { throw UpdateError.invalidArchive }
            let path = String(fields[8])
            guard path.hasPrefix("Limitless.app/"),
                path.utf8.allSatisfy({
                    (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
                        || [45, 46, 47, 95].contains($0)
                }),
                !path.split(separator: "/").contains(".."), !path.contains("//"),
                names.insert(path).inserted
            else { throw UpdateError.invalidArchive }
            total += size
            guard total <= maximumArchiveSize * 4 else { throw UpdateError.invalidArchive }
        }
        guard names.contains("Limitless.app/Contents/Info.plist"),
            names.contains("Limitless.app/Contents/MacOS/LimitlessApp")
        else { throw UpdateError.invalidArchive }
    }

    static func extract(_ archive: URL, to directory: URL) async throws {
        let listing = try await tar(["-tvf", archive.path], directory: directory)
        try validateListing(listing)
        // bsdtar's default path/symlink protections stay enabled (-P/-U are never used).
        _ = try await tar(
            [
                "-xkf", archive.path, "--no-same-owner", "--no-same-permissions", "--no-acls",
                "--no-fflags", "-C", directory.path,
            ], directory: directory)
    }

    private static func tar(_ arguments: [String], directory: URL) async throws -> String {
        let output = directory.appendingPathComponent(UUID().uuidString + ".log")
        guard FileManager.default.createFile(atPath: output.path, contents: nil) else {
            throw UpdateError.invalidArchive
        }
        let handle = try FileHandle(forWritingTo: output)
        defer {
            try? handle.close()
            try? FileManager.default.removeItem(at: output)
        }
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        child.arguments = arguments
        child.environment = ["PATH": "/usr/bin:/bin", "LC_ALL": "C", "TZ": "UTC"]
        child.standardInput = FileHandle.nullDevice
        child.standardOutput = handle
        child.standardError = FileHandle.nullDevice
        try child.run()
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))
        while child.isRunning {
            let size = try output.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            if Task.isCancelled || ContinuousClock.now >= deadline || size > 1_024 * 1_024 {
                child.terminate()
                try? await Task.sleep(for: .milliseconds(250))
                if child.isRunning { kill(child.processIdentifier, SIGKILL) }
                child.waitUntilExit()
                throw UpdateError.invalidArchive
            }
            try? await Task.sleep(for: .milliseconds(25))
        }
        guard child.terminationReason == .exit, child.terminationStatus == 0 else {
            throw UpdateError.invalidArchive
        }
        let data = try Data(contentsOf: output)
        guard data.count <= 1_024 * 1_024, let text = String(data: data, encoding: .utf8) else {
            throw UpdateError.invalidArchive
        }
        return text
    }

    private static func requireWritableApp(_ app: URL) throws {
        let values = try app.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard app.lastPathComponent == "Limitless.app", values.isDirectory == true,
            values.isSymbolicLink == false,
            FileManager.default.isWritableFile(atPath: app.path),
            FileManager.default.isWritableFile(atPath: app.deletingLastPathComponent().path),
            geteuid() != 0, geteuid() == getuid()
        else { throw UpdateError.unsafeLocation }
    }

    private static func canonical(_ url: URL) throws -> URL {
        guard url.isFileURL, let path = realpath(url.path, nil) else {
            throw UpdateError.unsafeLocation
        }
        defer { free(path) }
        return URL(fileURLWithPath: String(cString: path), isDirectory: true)
    }

    public static func verify(
        _ app: URL, identity: SignedIdentity, newerThan current: URL, expectedVersion: String? = nil
    ) throws {
        let info = try identity.verifyExecutable(at: app, identifier: LimitlessIdentity.application)
        guard let plist = info[kSecCodeInfoPList as String] as? [String: Any],
            plist["CFBundleIdentifier"] as? String == LimitlessIdentity.application,
            plist["CFBundleExecutable"] as? String == "LimitlessApp",
            let build = plist["CFBundleVersion"] as? String,
            let buildNumber = Int(build), buildNumber > 0,
            let versionName = plist["CFBundleShortVersionString"] as? String,
            let oldVersion = Bundle(url: current)?.object(
                forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            try version(oldVersion).lexicographicallyPrecedes(version(versionName)),
            expectedVersion == nil || expectedVersion == versionName,
            let kindName = plist["LimitlessHelperInstallation"] as? String,
            let kind = HelperInstallationKind(rawValue: kindName),
            kindName == Bundle(url: current)?.object(
                forInfoDictionaryKey: "LimitlessHelperInstallation") as? String,
            let flags = info[kSecCodeInfoFlags as String] as? UInt32, flags & 0x10000 != 0
        else { throw UpdateError.untrustedBuild }
        let cliInfo = try identity.verifyExecutable(
            at: app.appendingPathComponent("Contents/MacOS/limitless"),
            identifier: LimitlessIdentity.commandLine)
        let helperPath =
            kind == .blessed
            ? "Library/LaunchServices/" + LimitlessIdentity.helper
            : "Library/HelperTools/LimitlessHelper"
        let helperInfo = try identity.verifyExecutable(
            at: app.appendingPathComponent("Contents/" + helperPath),
            identifier: LimitlessIdentity.helper)
        for details in [info, cliInfo, helperInfo] {
            guard let flags = details[kSecCodeInfoFlags as String] as? UInt32,
                flags & 0x10000 != 0,
                (details[kSecCodeInfoEntitlementsDict as String] as? [String: Any] ?? [:]).isEmpty
            else { throw UpdateError.untrustedBuild }
        }
        struct Record: Decodable {
            let configuration: String
            let sourceClean: Bool
            let sourceRevision: String
        }
        let recordData = try Data(
            contentsOf: app.appendingPathComponent("Contents/Resources/Build.json"))
        guard recordData.count <= 4_096 else { throw UpdateError.untrustedBuild }
        let record = try JSONDecoder().decode(Record.self, from: recordData)
        guard record.configuration == "release", record.sourceClean,
            record.sourceRevision.count == 40,
            record.sourceRevision.utf8.allSatisfy({
                (48...57).contains($0) || (97...102).contains($0)
            })
        else { throw UpdateError.untrustedBuild }
        if kind == .blessed {
            guard let embedded = helperInfo[kSecCodeInfoPList as String] as? [String: Any],
                embedded["CFBundleVersion"] as? String == plist["CFBundleVersion"] as? String,
                embedded["SMAuthorizedClients"] as? [String] == [
                    try identity.requirement(for: LimitlessIdentity.application)
                ],
                plist["SMPrivilegedExecutables"] as? [String: String] == [
                    LimitlessIdentity.helper: try identity.requirement(
                        for: LimitlessIdentity.helper)
                ]
            else { throw UpdateError.untrustedBuild }
        }
    }

    /// The already installed app runs this unprivileged maintenance mode, then exits.
    /// No downloaded executable runs before macOS approves the replacement through NSWorkspace.
    public static func launchInstaller(_ staged: Staged) throws {
        guard let executable = Bundle.main.executableURL else { throw UpdateError.failed }
        let child = Process()
        child.executableURL = executable
        child.arguments = ["--finish-update", staged.app.path, String(getpid())]
        child.standardInput = FileHandle.nullDevice
        child.standardOutput = FileHandle.nullDevice
        child.standardError = FileHandle.nullDevice
        try child.run()
    }

    @concurrent public static func finish(app: URL, parentPID: Int32) async throws -> (
        app: URL, backup: URL, staging: URL
    ) {
        let current = try canonical(Bundle.main.bundleURL)
        let identity = try SignedIdentity(expectedIdentifier: LimitlessIdentity.application)
        try requireWritableApp(current)
        guard try app.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == false,
            try app.deletingLastPathComponent().resourceValues(forKeys: [.isSymbolicLinkKey])
                .isSymbolicLink == false
        else { throw UpdateError.unsafeLocation }
        let app = try canonical(app)
        let directory = app.deletingLastPathComponent()
        guard app.lastPathComponent == "Limitless.app",
            directory.deletingLastPathComponent() == current.deletingLastPathComponent(),
            directory.lastPathComponent.hasPrefix(".Limitless-update-"),
            let uuid = UUID(
                uuidString: String(
                    directory.lastPathComponent.dropFirst(".Limitless-update-".count))),
            directory.lastPathComponent == ".Limitless-update-" + uuid.uuidString
        else { throw UpdateError.unsafeLocation }
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        guard attributes[.ownerAccountID] as? UInt32 == geteuid(),
            attributes[.posixPermissions] as? Int == 0o700,
            parentPID > 1, parentPID != getpid()
        else { throw UpdateError.unsafeLocation }
        let parent = try? ProcessIdentity(pid: parentPID)
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))
        while parent?.isAlive == true {
            guard ContinuousClock.now < deadline else { throw UpdateError.busy }
            try await Task.sleep(for: .milliseconds(100))
        }
        try verify(app, identity: identity, newerThan: current)
        guard try SecureOwnershipJournal.isStateDirectoryAbsent(),
            try InstalledHelperFiles.areAbsent(),
            HelperInstallationKind.blessed.service.status == .notRegistered
        else { throw UpdateError.busy }
        let backupName = ".Limitless-previous-\(UUID().uuidString).app"
        let backup = current.deletingLastPathComponent().appendingPathComponent(backupName)
        do {
            _ = try FileManager.default.replaceItemAt(
                current, withItemAt: app, backupItemName: backupName,
                options: [.withoutDeletingBackupItem, .usingNewMetadataOnly])
            try identity.verifyExecutable(at: current, identifier: LimitlessIdentity.application)
        } catch {
            if FileManager.default.fileExists(atPath: backup.path) {
                _ = try? FileManager.default.replaceItemAt(
                    current, withItemAt: backup, options: .usingNewMetadataOnly)
            }
            throw UpdateError.failed
        }
        // Keep the old bundle until NSWorkspace confirms that macOS allowed the new launch.
        return (current, backup, directory)
    }
}

private final class GitHubRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    static func allows(_ url: URL) -> Bool {
        url.scheme == "https" && url.user == nil && url.password == nil
            && (url.port == nil || url.port == 443)
            && [
                "api.github.com", "github.com", "release-assets.githubusercontent.com",
                "objects.githubusercontent.com",
            ].contains(url.host ?? "")
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(request.url.map(Self.allows) == true ? request : nil)
    }
}

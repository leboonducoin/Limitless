import Darwin
import Foundation

enum PrivateApplicationLaunch {
    private static let prefix = "Limitless-Launch-"

    private static func cacheDirectory() throws -> URL {
        let path = try FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        try InstalledCLI.requirePrivatePath(path)
        return path
    }

    static func copy(_ source: URL) throws -> URL {
        let files = FileManager.default
        let directory = try cacheDirectory().appendingPathComponent(prefix + UUID().uuidString)
        try files.createDirectory(
            at: directory, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700])
        do {
            let copy = directory.appendingPathComponent(source.lastPathComponent, isDirectory: true)
            try files.copyItem(at: source, to: copy)
            try InstalledCLI.requirePrivatePath(copy)
            return copy
        } catch {
            try? files.removeItem(at: directory)
            throw error
        }
    }

    static func remove(_ app: URL) {
        let directory = app.deletingLastPathComponent()
        let name = directory.lastPathComponent
        guard let cache = try? cacheDirectory(),
            directory.deletingLastPathComponent().path == cache.path,
            name.hasPrefix(prefix),
            let id = UUID(uuidString: String(name.dropFirst(prefix.count))),
            name == prefix + id.uuidString,
            (try? InstalledCLI.requirePrivatePath(app)) != nil
        else { return }
        try? FileManager.default.removeItem(at: app)
        _ = rmdir(directory.path)
    }
}

import Darwin
import Foundation

public enum AgentSetup {
    public static let providers = ["codex", "claude", "cursor", "gemini"]

    private static func locations(_ provider: String) throws -> (config: String, skill: String) {
        switch provider {
        case "codex": (".codex/hooks.json", ".agents/skills/limitless")
        case "claude": (".claude/settings.json", ".claude/skills/limitless")
        case "cursor": (".cursor/hooks.json", ".cursor/skills/limitless")
        case "gemini": (".gemini/settings.json", ".gemini/skills/limitless")
        default: throw CocoaError(.fileReadInvalidFileName)
        }
    }

    private static func validate(_ url: URL, home: URL) throws {
        guard url.path.hasPrefix(home.path + "/"), geteuid() != 0 else {
            throw CocoaError(.fileWriteNoPermission)
        }
        var current = url
        while current.path != home.path {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: current.path)
                guard attributes[.type] as? FileAttributeType != .typeSymbolicLink,
                    attributes[.ownerAccountID] as? UInt32 == geteuid()
                else { throw CocoaError(.fileWriteNoPermission) }
            } catch let error as CocoaError
                where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile
            {
            }
            current.deleteLastPathComponent()
        }
    }

    private static func read(_ url: URL) throws -> Data? {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true, (values.fileSize ?? Int.max) <= 1_024 * 1_024 else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
    }

    static func merged(_ data: Data?, template: Data, provider: String, remove: Bool) throws -> Data
    {
        let source = try JSONSerialization.jsonObject(with: template) as? [String: Any]
        guard let additions = source?["hooks"] as? [String: [[String: Any]]] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var config: [String: Any] = [:]
        if let data {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CocoaError(.fileReadCorruptFile)
            }
            config = parsed
        }
        if provider == "cursor", let version = config["version"], (version as? Int) != 1 {
            throw CocoaError(.fileReadCorruptFile)
        }
        if config["hooks"] != nil, !(config["hooks"] is [String: Any]) {
            throw CocoaError(.fileReadCorruptFile)
        }
        var hooks = config["hooks"] as? [String: Any] ?? [:]
        let command = "/Applications/Limitless.app/Contents/MacOS/limitless hook " + provider
        for (event, entries) in additions {
            if hooks[event] != nil, !(hooks[event] is [[String: Any]]) {
                throw CocoaError(.fileReadCorruptFile)
            }
            let existing = hooks[event] as? [[String: Any]] ?? []
            var retained: [[String: Any]] = []
            for var entry in existing {
                if provider == "cursor" {
                    if entry["command"] as? String != command { retained.append(entry) }
                } else if let commands = entry["hooks"] as? [[String: Any]] {
                    let remaining = commands.filter { $0["command"] as? String != command }
                    if remaining.count == commands.count {
                        retained.append(entry)
                    } else if !remaining.isEmpty {
                        entry["hooks"] = remaining
                        retained.append(entry)
                    }
                } else {
                    retained.append(entry)
                }
            }
            if !remove { retained += entries }
            hooks[event] = retained.isEmpty ? nil : retained
        }
        config["hooks"] = hooks.isEmpty ? nil : hooks
        if provider == "cursor", !remove { config["version"] = 1 }
        return try JSONSerialization.data(
            withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
    }

    public static func configure(
        _ provider: String, remove: Bool = false,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        resources: URL = URL(
            fileURLWithPath: "/Applications/Limitless.app/Contents/Resources/limitless-skill")
    ) throws {
        let home = home.standardizedFileURL.resolvingSymlinksInPath()
        let paths = try locations(provider)
        let config = home.appendingPathComponent(paths.config)
        let skill = home.appendingPathComponent(paths.skill)
        let fileManager = FileManager.default
        let marker = skill.appendingPathComponent(".limitless-managed")
        if remove, !fileManager.fileExists(atPath: marker.path) { return }
        try validate(config, home: home)
        try validate(skill, home: home)
        let old = try read(config)
        try validate(marker, home: home)
        let existingMarker = try read(marker)
        let newConfigMarker = Data("Limitless:new-config\n".utf8)
        let savedMarker =
            existingMarker ?? (old == nil ? newConfigMarker : Data("Limitless\n".utf8))
        let template = try Data(
            contentsOf: resources.appendingPathComponent("hooks/\(provider).json"))
        let updated = try merged(old, template: template, provider: provider, remove: remove)
        let skillText = try Data(contentsOf: resources.appendingPathComponent("SKILL.md"))
        if fileManager.fileExists(atPath: skill.path) {
            try validate(skill.appendingPathComponent("SKILL.md"), home: home)
            try validate(marker, home: home)
            let names = try fileManager.contentsOfDirectory(atPath: skill.path)
            guard Set(names).isSubset(of: ["SKILL.md", ".limitless-managed"]),
                existingMarker == Data("Limitless\n".utf8) || existingMarker == newConfigMarker
            else { throw CocoaError(.fileWriteFileExists) }
        }
        let oldSkill = try read(skill.appendingPathComponent("SKILL.md"))
        let unchanged =
            old.flatMap { try? JSONSerialization.jsonObject(with: $0) as? NSDictionary }
            == (try JSONSerialization.jsonObject(with: updated) as? NSDictionary)
        if unchanged, !remove, oldSkill == skillText { return }
        try fileManager.createDirectory(
            at: config.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        if !unchanged, let old {
            let backup = config.appendingPathExtension("limitless-backup-" + UUID().uuidString)
            guard
                fileManager.createFile(
                    atPath: backup.path, contents: old, attributes: [.posixPermissions: 0o600])
            else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        if !remove {
            try fileManager.createDirectory(
                at: skill, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
            )
            try skillText.write(to: skill.appendingPathComponent("SKILL.md"), options: .atomic)
            try savedMarker.write(to: marker, options: .atomic)
        }
        if !unchanged {
            guard try read(config) == old else { throw CocoaError(.fileWriteUnknown) }
            try updated.write(to: config, options: .atomic)
            if old == nil {
                try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: config.path)
            }
        }
        if remove {
            let remaining = try JSONSerialization.jsonObject(with: updated) as? [String: Any] ?? [:]
            if existingMarker == newConfigMarker,
                remaining.isEmpty || (provider == "cursor" && Set(remaining.keys) == ["version"])
            {
                try fileManager.removeItem(at: config)
            }
            try fileManager.removeItem(at: skill)
        }
    }
}

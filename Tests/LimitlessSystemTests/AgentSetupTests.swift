import Foundation
import Testing

@testable import LimitlessSystem

@Test func freshAgentSetupNeedsNoPreexistingDirectoriesAndRemovesItsEmptyConfiguration() throws {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: home) }
    let resources = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
            "skills/limitless")
    for provider in AgentSetup.providers {
        try AgentSetup.configure(provider, home: home, resources: resources)
        try AgentSetup.configure(provider, home: home, resources: resources)
        try AgentSetup.configure(provider, remove: true, home: home, resources: resources)
        let directory = home.appendingPathComponent("." + provider)
        let name = provider == "codex" || provider == "cursor" ? "hooks.json" : "settings.json"
        #expect(
            !FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path))
    }
}

@Test(arguments: AgentSetup.providers)
func agentSetupPreservesSettingsIsRepeatableAndRemovesOnlyItsIntegration(_ provider: String) throws
{
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let home = root.appendingPathComponent("home")
    defer { try? FileManager.default.removeItem(at: root) }
    let resources = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
            "skills/limitless")
    let directory = home.appendingPathComponent("." + provider)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let config = directory.appendingPathComponent(
        provider == "codex" || provider == "cursor" ? "hooks.json" : "settings.json")
    let event = provider == "cursor" ? "stop" : (provider == "gemini" ? "AfterAgent" : "Stop")
    let other: [String: Any] =
        provider == "cursor"
        ? ["command": "other-command"]
        : ["hooks": [["type": "command", "command": "other-command"]]]
    let original = try JSONSerialization.data(withJSONObject: [
        "theme": "custom", "hooks": [event: [other]],
    ])
    try original.write(to: config)
    try AgentSetup.configure(provider, home: home, resources: resources)
    let installed = try Data(contentsOf: config)
    let object = try #require(JSONSerialization.jsonObject(with: installed) as? [String: Any])
    #expect(object["theme"] as? String == "custom")
    #expect((object["hooks"] as? [String: [[String: Any]]])?[event]?.count == 2)
    try AgentSetup.configure(provider, home: home, resources: resources)
    #expect(try Data(contentsOf: config) == installed)
    let backups = try FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: nil
    )
    .filter { $0.lastPathComponent.contains("limitless-backup-") }
    #expect(backups.count == 1)
    #expect(try Data(contentsOf: #require(backups.first)) == original)
    try AgentSetup.configure(provider, remove: true, home: home, resources: resources)
    let removed = try #require(
        JSONSerialization.jsonObject(with: Data(contentsOf: config)) as? [String: Any])
    #expect(removed["theme"] as? String == "custom")
    #expect((removed["hooks"] as? [String: [[String: Any]]])?[event]?.count == 1)
    let skill = home.appendingPathComponent(
        provider == "codex" ? ".agents/skills/limitless" : ".\(provider)/skills/limitless")
    #expect(!FileManager.default.fileExists(atPath: skill.path))
    try AgentSetup.configure(provider, remove: true, home: home, resources: resources)
}

@Test func agentSetupRefusesInvalidOrLinkedFilesWithoutOverwritingThem() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let directory = root.appendingPathComponent(".codex")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let resources = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
            "skills/limitless")
    let config = directory.appendingPathComponent("hooks.json")
    let invalid = Data("invalid JSON".utf8)
    try invalid.write(to: config)
    #expect(throws: (any Error).self) {
        try AgentSetup.configure("codex", home: root, resources: resources)
    }
    #expect(try Data(contentsOf: config) == invalid)
    try FileManager.default.removeItem(at: config)
    let outside = root.appendingPathComponent("untouched")
    try Data("{}".utf8).write(to: outside)
    try FileManager.default.createSymbolicLink(at: config, withDestinationURL: outside)
    #expect(throws: (any Error).self) {
        try AgentSetup.configure("codex", home: root, resources: resources)
    }
    #expect(try Data(contentsOf: outside) == Data("{}".utf8))
}

@Test func agentSetupRejectsAReplacedConfigurationDirectory() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let directory = root.appendingPathComponent(".codex")
    let moved = root.appendingPathComponent("moved-codex")
    let outside = root.appendingPathComponent("outside")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let resources = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
            "skills/limitless")
    let original = Data("victim".utf8)
    let target = outside.appendingPathComponent("hooks.json")
    try original.write(to: target)
    #expect(throws: JournalError.unexpectedContents) {
        try AgentSetup.configure(
            "codex", remove: false, home: root, resources: resources,
            beforeMutation: {
                try FileManager.default.moveItem(at: directory, to: moved)
                try FileManager.default.createSymbolicLink(
                    at: directory, withDestinationURL: outside)
            })
    }
    #expect(try Data(contentsOf: target) == original)
    #expect(
        !FileManager.default.fileExists(
            atPath: root.appendingPathComponent(".agents/skills/limitless").path))
}

@Test(arguments: [false, true])
func failedAgentSetupRestoresManagedSkillAndAllowsRetry(_ existingSkill: Bool) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let configDirectory = root.appendingPathComponent(".codex")
    let config = configDirectory.appendingPathComponent("hooks.json")
    let skill = root.appendingPathComponent(".agents/skills/limitless")
    let marker = skill.appendingPathComponent(".limitless-managed")
    let oldSkill = Data("Previous managed skill\n".utf8)
    let oldMarker = Data("Limitless:new-config\n".utf8)
    let resources = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
            "skills/limitless")
    defer {
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: configDirectory.path)
        try? FileManager.default.removeItem(at: root)
    }
    try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
    if existingSkill {
        try FileManager.default.createDirectory(at: skill, withIntermediateDirectories: true)
        try oldSkill.write(to: skill.appendingPathComponent("SKILL.md"))
        try oldMarker.write(to: marker)
    }
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o500], ofItemAtPath: configDirectory.path)
    #expect(throws: (any Error).self) {
        try AgentSetup.configure("codex", home: root, resources: resources)
    }
    #expect(!FileManager.default.fileExists(atPath: config.path))
    if existingSkill {
        #expect(try Data(contentsOf: skill.appendingPathComponent("SKILL.md")) == oldSkill)
        #expect(try Data(contentsOf: marker) == oldMarker)
    } else {
        #expect(!FileManager.default.fileExists(atPath: skill.path))
    }
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: configDirectory.path)
    try AgentSetup.configure("codex", home: root, resources: resources)
    #expect(FileManager.default.fileExists(atPath: config.path))
    #expect(FileManager.default.fileExists(atPath: marker.path))
}

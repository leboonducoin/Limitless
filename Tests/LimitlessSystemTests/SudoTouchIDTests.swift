import Darwin
import Foundation
import Testing

@testable import LimitlessSystem

private let sudoPolicy = """
    auth       include        sudo_local
    auth       sufficient     pam_smartcard.so
    auth       required       pam_opendirectory.so
    account    required       pam_permit.so
    password   required       pam_deny.so
    session    required       pam_permit.so
    """

@Test func sudoTouchIDPreservesPasswordAndOnlyRemovesItsOwnSetting() throws {
    for original: String? in [nil, "", "# Custom heading\n#auth sufficient pam_tid.so\n"] {
        let enabled = try SudoTouchID.transform(sudo: sudoPolicy, local: original, enabled: true)
        #expect(enabled.state == .enabled)
        #expect(
            try SudoTouchID.transform(sudo: sudoPolicy, local: enabled.contents, enabled: true)
                .contents == enabled.contents)
        #expect(
            try SudoTouchID.transform(sudo: sudoPolicy, local: enabled.contents, enabled: nil).state
                == .enabled)
        let disabled = try SudoTouchID.transform(
            sudo: sudoPolicy, local: enabled.contents, enabled: false)
        #expect(disabled.contents == original)
    }
    let external = "# Set up elsewhere\nauth sufficient pam_tid.so\n"
    for setting in [nil, true, false] as [Bool?] {
        let result = try SudoTouchID.transform(sudo: sudoPolicy, local: external, enabled: setting)
        #expect(result.contents == external)
        if setting != false { #expect(result.state == .external) }
    }
    let created = try SudoTouchID.transform(sudo: sudoPolicy, local: nil, enabled: true).contents!
    #expect(
        try SudoTouchID.transform(
            sudo: "changed later", local: created + "# Keep me\n", enabled: false
        ).contents == "# Keep me\n")
    for policy in [
        "",
        sudoPolicy.replacingOccurrences(
            of: "required       pam_opendirectory.so", with: "sufficient pam_permit.so"),
    ] {
        #expect(throws: JournalError.unexpectedContents) {
            try SudoTouchID.transform(sudo: policy, local: created, enabled: nil)
        }
        #expect(throws: JournalError.unexpectedContents) {
            try SudoTouchID.transform(sudo: policy, local: nil, enabled: true)
        }
    }
    for local in [
        "auth required another.so\n",
        created.replacingOccurrences(of: "pam_tid.so", with: "other.so"),
    ] {
        #expect(throws: JournalError.unexpectedContents) {
            try SudoTouchID.transform(sudo: sudoPolicy, local: local, enabled: true)
        }
    }
}

@Test func sudoTouchIDAtomicChangesPreserveFilesAndRejectUnsafeEntries() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let directory = root.appendingPathComponent("private/etc/pam.d")
    try FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    defer { try? FileManager.default.removeItem(at: root) }
    let sudo = directory.appendingPathComponent("sudo")
    let local = directory.appendingPathComponent("sudo_local")
    try Data(sudoPolicy.utf8).write(to: sudo)
    func change(_ value: Bool?) throws {
        _ = try SudoTouchID.access(change: value, root: root, owner: getuid())
    }
    try change(true)
    #expect(try SudoTouchID.access(change: nil, root: root, owner: getuid()) == .enabled)
    var info = stat()
    #expect(lstat(local.path, &info) == 0 && info.st_mode & 0o777 == 0o444)
    try change(false)
    #expect(!FileManager.default.fileExists(atPath: local.path))
    let original = Data("# User heading\n".utf8)
    try original.write(to: local)
    #expect(chmod(local.path, 0o640) == 0)
    try change(true)
    try change(false)
    #expect(try Data(contentsOf: local) == original)
    #expect(lstat(local.path, &info) == 0 && info.st_mode & 0o777 == 0o640)
    #expect(try String(contentsOf: sudo, encoding: .utf8) == sudoPolicy)
    #expect(chmod(local.path, 0o666) == 0)
    #expect(throws: JournalError.insecureFile) { try change(true) }
    try FileManager.default.removeItem(at: local)
    try FileManager.default.createSymbolicLink(at: local, withDestinationURL: sudo)
    #expect(throws: (any Error).self) { try change(true) }
    #expect(try String(contentsOf: sudo, encoding: .utf8) == sudoPolicy)
    try FileManager.default.removeItem(at: local)
    #expect(link(sudo.path, local.path) == 0)
    #expect(throws: JournalError.insecureFile) { try change(true) }
    try FileManager.default.removeItem(at: local)
    try Data(repeating: 0x61, count: 16_385).write(to: local)
    #expect(throws: JournalError.insecureFile) { try change(true) }
    try FileManager.default.removeItem(at: local)
    #expect(mkfifo(local.path, 0o600) == 0)
    #expect(throws: JournalError.insecureFile) { try change(true) }
    try FileManager.default.removeItem(at: local)
    let almostFull = Data(("#" + String(repeating: "a", count: 16_380)).utf8)
    try almostFull.write(to: local)
    #expect(throws: JournalError.unexpectedContents) { try change(true) }
    #expect(try Data(contentsOf: local) == almostFull)
    try FileManager.default.removeItem(at: local)
    #expect(chmod(directory.path, 0o777) == 0)
    #expect(throws: JournalError.insecureDirectory) { try change(true) }
}

@Test func sudoTouchIDExternalSettingNeedsExplicitRemoval() throws {
    let comments = "# Set up elsewhere\n\n# Keep this header\n"
    let external = "# Set up elsewhere\n\nauth\tsufficient\tpam_tid.so\n# Keep this header\n"
    for original in [external, "auth sufficient pam_tid.so", "auth sufficient pam_tid.so\n"] {
        let removed = try SudoTouchID.transform(
            sudo: sudoPolicy, local: original, enabled: false, removeExternal: true)
        #expect(removed.state == .disabled)
        #expect(removed.contents == (original == external ? comments : ""))
        #expect(
            try SudoTouchID.transform(
                sudo: sudoPolicy, local: original, enabled: true, removeExternal: true
            ).contents == original)
    }
    for (policy, local) in [
        ("changed policy", external),
        (sudoPolicy, external + "auth required another.so\n"),
        (sudoPolicy, external + "auth sufficient pam_tid.so\n"),
    ] {
        #expect(throws: JournalError.unexpectedContents) {
            try SudoTouchID.transform(
                sudo: policy, local: local, enabled: false, removeExternal: true)
        }
    }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let directory = root.appendingPathComponent("private/etc/pam.d")
    try FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    defer { try? FileManager.default.removeItem(at: root) }
    let sudo = directory.appendingPathComponent("sudo")
    let local = directory.appendingPathComponent("sudo_local")
    try Data(sudoPolicy.utf8).write(to: sudo)
    try Data(external.utf8).write(to: local)
    #expect(chmod(local.path, 0o640) == 0)
    _ = try SudoTouchID.access(change: false, root: root, owner: getuid())
    #expect(try String(contentsOf: local, encoding: .utf8) == external)
    #expect(
        try SudoTouchID.access(
            change: false, removeExternal: true, root: root, owner: getuid()) == .disabled)
    #expect(try SudoTouchID.access(change: nil, root: root, owner: getuid()) == .disabled)
    #expect(try String(contentsOf: local, encoding: .utf8) == comments)
    _ = try SudoTouchID.access(change: true, root: root, owner: getuid())
    _ = try SudoTouchID.access(change: false, root: root, owner: getuid())
    #expect(try String(contentsOf: local, encoding: .utf8) == comments)
    #expect(try String(contentsOf: sudo, encoding: .utf8) == sudoPolicy)
    var info = stat()
    #expect(lstat(local.path, &info) == 0 && info.st_mode & 0o777 == 0o640)
}

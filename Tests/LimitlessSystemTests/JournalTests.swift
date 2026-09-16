import Darwin
import Foundation
import Testing

@testable import LimitlessSystem

private func withJournalDirectory(_ body: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LimitlessJournalTest-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(directory)
}

@Test func journalIsDurableAcrossInstancesAndReleaseIsIdempotent() throws {
    try withJournalDirectory { directory in
        do {
            let journal = try SecureOwnershipJournal(testDirectory: directory)
            #expect(try !journal.loadOwned())
            try journal.storeOwned(true)
            #expect(try journal.loadOwned())
            try journal.storeOwned(true)
        }
        let reopened = try SecureOwnershipJournal(testDirectory: directory)
        #expect(try reopened.loadOwned())
        try reopened.storeOwned(false)
        try reopened.storeOwned(false)
        #expect(try !reopened.loadOwned())
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(files == [".lock"])
    }
}

@Test func journalLockExcludesASecondOwner() throws {
    try withJournalDirectory { directory in
        let first = try SecureOwnershipJournal(testDirectory: directory)
        #expect(throws: JournalError.alreadyLocked) {
            _ = try SecureOwnershipJournal(testDirectory: directory)
        }
        #expect(try !first.loadOwned())
    }
}

@Test(arguments: [
    "", "{}", "{\"version\":2,\"owned\":true}", "{\"version\":1,\"owned\":false}",
    String(repeating: "x", count: 1025),
])
func invalidJournalCannotBeTreatedAsUnowned(_ contents: String) throws {
    try withJournalDirectory { directory in
        let journal = try SecureOwnershipJournal(testDirectory: directory)
        let record = directory.appendingPathComponent("ownership.json")
        try Data(contents.utf8).write(to: record)
        #expect(chmod(record.path, 0o600) == 0)
        #expect(throws: JournalError.invalidRecord) { try journal.loadOwned() }
        #expect(throws: JournalError.invalidRecord) { try journal.storeOwned(true) }
        #expect(try Data(contentsOf: record) == Data(contents.utf8))
    }
}

@Test func journalRefusesReadableFilesAndNonPrivateDirectories() throws {
    try withJournalDirectory { directory in
        let journal = try SecureOwnershipJournal(testDirectory: directory)
        try journal.storeOwned(true)
        let record = directory.appendingPathComponent("ownership.json")
        #expect(chmod(record.path, 0o644) == 0)
        #expect(throws: JournalError.insecureFile) { try journal.loadOwned() }
    }
    try withJournalDirectory { directory in
        #expect(chmod(directory.path, 0o777) == 0)
        #expect(throws: JournalError.insecureDirectory) {
            _ = try SecureOwnershipJournal(testDirectory: directory)
        }
    }
}

@Test func journalNeverFollowsSymlinksOrAcceptsHardLinks() throws {
    try withJournalDirectory { directory in
        let journal = try SecureOwnershipJournal(testDirectory: directory)
        let foreign = directory.appendingPathComponent("foreign")
        let record = directory.appendingPathComponent("ownership.json")
        let original = Data("untouched".utf8)
        try original.write(to: foreign)
        #expect(chmod(foreign.path, 0o600) == 0)
        try FileManager.default.createSymbolicLink(at: record, withDestinationURL: foreign)
        #expect(throws: (any Error).self) { try journal.storeOwned(true) }
        #expect(try Data(contentsOf: foreign) == original)
        try FileManager.default.removeItem(at: record)
        try FileManager.default.linkItem(at: foreign, to: record)
        #expect(throws: JournalError.insecureFile) { try journal.loadOwned() }
    }
}

@Test func journalRejectsFIFOsWithoutBlocking() throws {
    try withJournalDirectory { directory in
        let journal = try SecureOwnershipJournal(testDirectory: directory)
        let record = directory.appendingPathComponent("ownership.json")
        #expect(mkfifo(record.path, 0o600) == 0)
        #expect(throws: JournalError.insecureFile) { try journal.loadOwned() }
    }
}

@Test func journalRejectsACLsThatCouldOverridePrivateModeBits() throws {
    try withJournalDirectory { directory in
        var acl = acl_init(1)
        defer { if let acl { acl_free(UnsafeMutableRawPointer(acl)) } }
        var entry: acl_entry_t?
        #expect(acl_create_entry(&acl, &entry) == 0)
        let item = try #require(entry)
        #expect(acl_set_tag_type(item, ACL_EXTENDED_ALLOW) == 0)
        var subject = UUID().uuid
        #expect(acl_set_qualifier(item, &subject) == 0)
        var permissions: acl_permset_t?
        #expect(acl_get_permset(item, &permissions) == 0)
        let permissionSet = try #require(permissions)
        let accessList = try #require(acl)
        #expect(acl_add_perm(permissionSet, ACL_WRITE_DATA) == 0)
        #expect(acl_set_file(directory.path, ACL_TYPE_EXTENDED, accessList) == 0)
        #expect(throws: JournalError.extendedAccess) {
            _ = try SecureOwnershipJournal(testDirectory: directory)
        }
    }
}

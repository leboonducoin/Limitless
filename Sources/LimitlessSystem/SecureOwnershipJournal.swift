import Darwin
import Foundation
import LimitlessCore

public enum JournalError: Error, Equatable, Sendable {
    case administratorRequired, insecureDirectory, insecureFile, invalidRecord, alreadyLocked
    case extendedAccess
    case system(Int32)
}

/// Root-only durable intent. No client-supplied path or session/task contents.
/// Keep one instance on the helper's serial worker; the lock also excludes other processes.
public final class SecureOwnershipJournal: OwnershipJournal {
    private let directoryFD: Int32
    private let lockFD: Int32
    private let owner: uid_t
    private static let filename = "ownership.json"
    private struct Record: Codable {
        let version: Int
        let owned: Bool
    }

    public convenience init() throws {
        guard geteuid() == 0 else { throw JournalError.administratorRequired }
        var parent = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parent >= 0 else { throw JournalError.system(errno) }
        defer { close(parent) }
        for component in ["Library", "Application Support"] {
            try Self.validateDirectory(parent, owner: 0, privateOnly: false)
            let next = openat(parent, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard next >= 0 else { throw JournalError.system(errno) }
            close(parent)
            parent = next
        }
        try Self.validateDirectory(parent, owner: 0, privateOnly: false)
        if mkdirat(parent, "Limitless", 0o700) != 0, errno != EEXIST {
            throw JournalError.system(errno)
        }
        let directory = openat(parent, "Limitless", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        try self.init(directoryFD: directory, owner: 0)
    }

    // Test-only construction stays module-internal. Production has a fixed root-owned path.
    convenience init(testDirectory: URL) throws {
        let directory = open(testDirectory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        try self.init(directoryFD: directory, owner: geteuid())
    }

    private init(directoryFD: Int32, owner: uid_t) throws {
        guard directoryFD >= 0 else { throw JournalError.system(errno) }
        do {
            try Self.validateDirectory(directoryFD, owner: owner, privateOnly: true)
            let lock = openat(
                directoryFD, ".lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK, 0o600)
            guard lock >= 0 else { throw JournalError.system(errno) }
            do {
                try Self.validateFile(lock, owner: owner)
                guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { throw JournalError.alreadyLocked }
            } catch {
                close(lock)
                throw error
            }
            self.directoryFD = directoryFD
            lockFD = lock
            self.owner = owner
        } catch {
            close(directoryFD)
            throw error
        }
    }

    deinit {
        close(lockFD)
        close(directoryFD)
    }

    public func loadOwned() throws -> Bool {
        let file = openat(
            directoryFD, Self.filename, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard file >= 0 else {
            if errno == ENOENT { return false }
            throw JournalError.system(errno)
        }
        defer { close(file) }
        try Self.validateFile(file, owner: owner)
        let data = try FileHandle(fileDescriptor: file, closeOnDealloc: false).read(upToCount: 1025)
        guard let data, !data.isEmpty, data.count <= 1024,
            let record = try? JSONDecoder().decode(Record.self, from: data),
            record.version == 1, record.owned
        else { throw JournalError.invalidRecord }
        return true
    }

    public func storeOwned(_ owned: Bool) throws {
        // A corrupt/foreign object is never silently replaced or followed.
        _ = try loadOwned()
        if !owned {
            if unlinkat(directoryFD, Self.filename, 0) != 0, errno != ENOENT {
                throw JournalError.system(errno)
            }
            try synchronizeDirectory()
            return
        }
        let temporary = ".ownership-\(UUID().uuidString)"
        let file = openat(
            directoryFD, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard file >= 0 else { throw JournalError.system(errno) }
        defer {
            close(file)
            unlinkat(directoryFD, temporary, 0)
        }
        let data = try JSONEncoder().encode(Record(version: 1, owned: true))
        try FileHandle(fileDescriptor: file, closeOnDealloc: false).write(contentsOf: data)
        guard fsync(file) == 0 else { throw JournalError.system(errno) }
        guard renameat(directoryFD, temporary, directoryFD, Self.filename) == 0 else {
            throw JournalError.system(errno)
        }
        try synchronizeDirectory()
    }

    private func synchronizeDirectory() throws {
        guard fsync(directoryFD) == 0 else { throw JournalError.system(errno) }
        // Flush the volume after its metadata barrier, before acknowledging ownership.
        guard fcntl(lockFD, F_FULLFSYNC) == 0 else { throw JournalError.system(errno) }
    }

    private static func validateDirectory(_ file: Int32, owner: uid_t, privateOnly: Bool) throws {
        var info = stat()
        guard fstat(file, &info) == 0 else { throw JournalError.system(errno) }
        guard info.st_mode & S_IFMT == S_IFDIR, info.st_uid == owner,
            info.st_mode & 0o022 == 0,
            !privateOnly || info.st_mode & 0o777 == 0o700
        else { throw JournalError.insecureDirectory }
        try rejectExtendedAccess(file)
    }

    private static func validateFile(_ file: Int32, owner: uid_t) throws {
        var info = stat()
        guard fstat(file, &info) == 0 else { throw JournalError.system(errno) }
        guard info.st_mode & S_IFMT == S_IFREG, info.st_uid == owner,
            info.st_mode & 0o777 == 0o600, info.st_nlink == 1
        else { throw JournalError.insecureFile }
        try rejectExtendedAccess(file)
    }

    private static func rejectExtendedAccess(_ file: Int32) throws {
        guard let acl = acl_get_fd_np(file, ACL_TYPE_EXTENDED) else {
            // On macOS, a valid descriptor with no extended ACL reports ENOENT.
            if errno == ENOENT { return }
            throw JournalError.system(errno)
        }
        defer { acl_free(UnsafeMutableRawPointer(acl)) }
        var entry: acl_entry_t?
        // macOS returns 0 for an entry, -1/EINVAL for the end of this valid ACL.
        guard acl_get_entry(acl, Int32(ACL_FIRST_ENTRY.rawValue), &entry) != 0 else {
            throw JournalError.extendedAccess
        }
        guard errno == EINVAL else { throw JournalError.system(errno) }
    }
}

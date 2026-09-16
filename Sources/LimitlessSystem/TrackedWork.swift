import Darwin
import Foundation

public enum WorkError: Error, Equatable, Sendable {
    case invalidProcess, processUnavailable, differentUser, administratorNotAllowed, alreadyStarted
}

/// The start timestamp protects against PID reuse. No process name/arguments are collected.
public struct ProcessIdentity: Sendable {
    public let pid: Int32
    private let user: UInt32
    private let startedSeconds: UInt64
    private let startedMicroseconds: UInt64

    public init(pid: Int32) throws {
        guard geteuid() != 0, geteuid() == getuid() else { throw WorkError.administratorNotAllowed }
        guard pid > 1, pid != getpid() else { throw WorkError.invalidProcess }
        guard let info = Self.read(pid), info.pbi_status != SZOMB else {
            throw WorkError.processUnavailable
        }
        guard info.pbi_uid == geteuid(), info.pbi_ruid == getuid() else {
            throw WorkError.differentUser
        }
        self.pid = pid
        user = info.pbi_uid
        startedSeconds = info.pbi_start_tvsec
        startedMicroseconds = info.pbi_start_tvusec
    }

    /// Failed observation ends protection, instead of assuming the original task still exists.
    public var isAlive: Bool { Self.read(pid).map(matches) ?? false }

    func matches(_ info: proc_bsdinfo) -> Bool {
        info.pbi_pid == UInt32(pid) && info.pbi_uid == user && info.pbi_ruid == user
            && info.pbi_start_tvsec == startedSeconds
            && info.pbi_start_tvusec == startedMicroseconds && info.pbi_status != SZOMB
    }

    static func read(_ pid: Int32) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        return proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size ? info : nil
    }
}

/// Runs an explicit command under the caller's identity, preserving stdin/stdout/stderr.
/// Foundation reports actual termination; no CPU/idle heuristic or shell interpolation.
@MainActor public final class TrackedCommand {
    private let process = Process()
    private let results: AsyncStream<Int32>
    private let completion: AsyncStream<Int32>.Continuation
    private var started = false

    public init(arguments: [String]) throws {
        guard geteuid() != 0, geteuid() == getuid() else { throw WorkError.administratorNotAllowed }
        guard let executable = arguments.first, !executable.isEmpty else {
            throw WorkError.invalidProcess
        }
        let stream = AsyncStream<Int32>.makeStream(bufferingPolicy: .bufferingNewest(1))
        results = stream.stream
        completion = stream.continuation
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["--"] + arguments
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        process.terminationHandler = { child in
            let code =
                child.terminationReason == .exit
                ? child.terminationStatus : 128 + child.terminationStatus
            stream.continuation.yield(code)
            stream.continuation.finish()
        }
    }

    public var isRunning: Bool { process.isRunning }
    public var processIdentifier: Int32 { process.processIdentifier }

    public func start() throws {
        guard !started else { throw WorkError.alreadyStarted }
        started = true
        do { try process.run() } catch {
            completion.finish()
            throw error
        }
    }

    public func result() async -> Int32 {
        for await code in results { return code }
        return 125
    }

    public func interrupt(terminate: Bool = false) {
        guard process.isRunning else { return }
        if terminate { process.terminate() } else { process.interrupt() }
    }
}

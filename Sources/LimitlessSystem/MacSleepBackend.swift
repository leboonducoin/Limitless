import Darwin
import Foundation
import IOKit
import IOKit.pwr_mgt
import LimitlessCore

public enum MacSleepError: Error, Equatable, Sendable {
    case administratorRequired
    case commandFailed(Int32)
    case commandTimedOut, verificationFailed
    case commandStillRunning, invalidTimeout
    case assertionFailed(IOReturn)
}

/// The only adapter aware of the undocumented global flag and registry property.
/// Mutating operations belong exclusively to the authenticated privileged helper.
public struct MacSleepBackend: SleepBackend, Sendable {
    private var assertionID: IOPMAssertionID?
    private var command = BoundedSystemCommand()

    public init() {}

    public var hasIdleAssertion: Bool {
        guard let assertionID,
            let properties = IOPMAssertionCopyProperties(assertionID)?.takeRetainedValue()
                as? [String: Any],
            let level = properties[kIOPMAssertionLevelKey] as? NSNumber
        else { return false }
        return level.uint32Value == kIOPMAssertionLevelOn
    }

    public mutating func observe() -> SleepObservation {
        guard !command.isRunning else { return .unknown }
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != IO_OBJECT_NULL else { return .unknown }
        defer { IOObjectRelease(service) }
        let property = IORegistryEntryCreateCFProperty(
            service, "SleepDisabled" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        return Self.decodeSleepProperty(property)
    }

    static func decodeSleepProperty(_ property: CFTypeRef?) -> SleepObservation {
        guard let property, CFGetTypeID(property) == CFBooleanGetTypeID(),
            let disabled = property as? Bool
        else { return .unknown }
        return disabled ? .disabled : .allowed
    }

    public mutating func setIdleAssertion(_ held: Bool) throws {
        if held, hasIdleAssertion { return }
        if let assertionID {
            let result = IOPMAssertionRelease(assertionID)
            guard result == kIOReturnSuccess else { throw MacSleepError.assertionFailed(result) }
            self.assertionID = nil
        }
        guard held else { return }
        var identifier: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Limitless active session" as CFString, &identifier)
        guard result == kIOReturnSuccess else { throw MacSleepError.assertionFailed(result) }
        assertionID = identifier
        guard hasIdleAssertion else { throw MacSleepError.verificationFailed }
    }

    public mutating func setSleepDisabled(_ disabled: Bool) throws {
        guard geteuid() == 0 else { throw MacSleepError.administratorRequired }
        // No source mask: this setting is global, regardless of -b/-c/-a policy.
        try command.run(
            executable: "/usr/bin/pmset", arguments: ["disablesleep", disabled ? "1" : "0"])
        // powerd applies the preference asynchronously. Wait at most one second;
        // neither a successful exit nor an unreadable property proves success.
        let expected: SleepObservation = disabled ? .disabled : .allowed
        for _ in 0..<20 {
            if observe() == expected { return }
            Thread.sleep(forTimeInterval: 0.05)
        }
        guard observe() == expected else { throw MacSleepError.verificationFailed }
    }
}

/// Internal subprocess boundary; executable/arguments are never XPC request fields.
/// A timed-out child remains tracked until termination, preventing overlapping writes.
struct BoundedSystemCommand: Sendable {
    private var process: Process?
    var isRunning: Bool { process?.isRunning == true }

    mutating func run(executable: String, arguments: [String], timeout: TimeInterval = 2) throws {
        guard timeout.isFinite, timeout > 0, timeout <= 2 else {
            throw MacSleepError.invalidTimeout
        }
        guard !isRunning else { throw MacSleepError.commandStillRunning }
        let child = Process()
        child.executableURL = URL(fileURLWithPath: executable)
        child.arguments = arguments
        child.currentDirectoryURL = URL(fileURLWithPath: "/")
        child.environment = ["PATH": "/usr/bin:/bin", "LC_ALL": "C"]
        child.standardInput = FileHandle.nullDevice
        child.standardOutput = FileHandle.nullDevice
        child.standardError = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        child.terminationHandler = { _ in finished.signal() }
        try child.run()
        process = child
        guard finished.wait(timeout: .now() + timeout) == .success else {
            if child.isRunning { child.terminate() }
            if finished.wait(timeout: .now() + 0.25) != .success, child.isRunning {
                kill(child.processIdentifier, SIGKILL)
                _ = finished.wait(timeout: .now() + 0.25)
            }
            throw MacSleepError.commandTimedOut
        }
        process = nil
        guard child.terminationReason == .exit, child.terminationStatus == 0 else {
            throw MacSleepError.commandFailed(child.terminationStatus)
        }
    }
}

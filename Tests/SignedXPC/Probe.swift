import Foundation
import os

final class ProbeServer: NSObject, NSXPCListenerDelegate, LimitlessXPC {
    let requirement: String
    private let lock = NSLock()
    private var connections: [NSXPCConnection] = []

    init(requirement: String) { self.requirement = requirement }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection)
        -> Bool
    {
        guard connection.effectiveUserIdentifier == geteuid(), geteuid() != 0 else { return false }
        connection.setCodeSigningRequirement(requirement)
        connection.exportedInterface = NSXPCInterface(with: LimitlessXPC.self)
        connection.exportedObject = self
        lock.withLock { connections.append(connection) }
        connection.activate()
        return true
    }

    func request(_ data: Data, reply: @escaping @Sendable (Data) -> Void) {
        // Fixed probe only: no runtime, process execution, session or power backend.
        guard data == Data("signed-xpc-probe".utf8) else { return }
        reply(Data("probe:\(getpid()):\(geteuid())".utf8))
    }
}

enum ProbeResult: Sendable {
    case reply(Data)
    case refused(String, Int)
    case timeout
}

@main struct Probe {
    static func main() async {
        do {
            guard geteuid() != 0, let identifier = Bundle.main.bundleIdentifier else {
                throw CocoaError(.coderValueNotFound)
            }
            let identity = try SignedIdentity(expectedIdentifier: identifier)
            let mode =
                Bundle.main.object(forInfoDictionaryKey: "LimitlessProbeCase") as? String ?? "valid"
            let wrongPin =
                (identity.certificateFingerprint.first == "0" ? "1" : "0")
                + identity.certificateFingerprint.dropFirst()
            if identifier == LimitlessIdentity.helper {
                var requirement = try identity.requirement(for: LimitlessIdentity.commandLine)
                if mode == "reject-client-pin" {
                    requirement = requirement.replacingOccurrences(
                        of: identity.certificateFingerprint, with: wrongPin)
                } else if mode == "reject-client-id" {
                    requirement = try identity.requirement(for: LimitlessIdentity.application)
                }
                let server = ProbeServer(requirement: requirement)
                let listener = NSXPCListener.service()
                listener.delegate = server
                // Bound even a rejected connection; no service remains running after this probe.
                DispatchQueue.global().asyncAfter(deadline: .now() + 8) { exit(0) }
                withExtendedLifetime(server) { listener.resume() }
                return
            }
            let connection = NSXPCConnection(serviceName: LimitlessIdentity.helper)
            var requirement = try identity.requirement(for: LimitlessIdentity.helper)
            if mode == "reject-server-pin" {
                requirement = requirement.replacingOccurrences(
                    of: identity.certificateFingerprint, with: wrongPin)
            } else if mode == "reject-server-id" {
                requirement = try identity.requirement(for: LimitlessIdentity.application)
            }
            connection.setCodeSigningRequirement(requirement)
            connection.remoteObjectInterface = NSXPCInterface(with: LimitlessXPC.self)
            connection.activate()
            let result: ProbeResult = await withCheckedContinuation { continuation in
                let pending = OSAllocatedUnfairLock(initialState: Optional(continuation))
                let finish: @Sendable (ProbeResult) -> Void = { result in
                    let current = pending.withLock { value in
                        defer { value = nil }
                        return value
                    }
                    current?.resume(returning: result)
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 5) { finish(.timeout) }
                guard
                    let proxy = connection.remoteObjectProxyWithErrorHandler({ @Sendable error in
                        let error = error as NSError
                        finish(.refused(error.domain, error.code))
                    }) as? any LimitlessXPC
                else {
                    finish(.refused("Probe", -1))
                    return
                }
                proxy.request(Data("signed-xpc-probe".utf8)) { finish(.reply($0)) }
            }
            connection.invalidate()
            switch result {
            case .reply(let data):
                let parts = String(decoding: data, as: UTF8.self).split(separator: ":")
                guard mode == "valid", parts.count == 3, parts[0] == "probe",
                    let peerPID = Int32(parts[1]), peerPID > 0, peerPID != getpid(),
                    UInt32(parts[2]) == geteuid()
                else { exit(1) }
                print("PASS valid: authenticated reply from distinct non-root PID \(peerPID)")
            case .refused(let domain, let code):
                let expectedCodes =
                    mode.hasPrefix("reject-server")
                    ? [NSXPCConnectionCodeSigningRequirementFailure]
                    : [NSXPCConnectionInterrupted, NSXPCConnectionInvalid]
                guard mode != "valid", domain == NSCocoaErrorDomain,
                    expectedCodes.contains(code)
                else {
                    print("FAIL \(mode): XPC error \(code)")
                    exit(1)
                }
                print("PASS \(mode): XPC invalidated the mismatched connection (\(code))")
            case .timeout:
                print("FAIL \(mode): timeout is not evidence of authentication refusal")
                exit(1)
            }
        } catch {
            print("FAIL probe: \(error)")
            exit(1)
        }
    }
}

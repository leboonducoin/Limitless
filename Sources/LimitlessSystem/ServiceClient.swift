import Foundation
import LimitlessCore
import os

/// One authenticated connection per owner. An interruption is terminal; no automatic reacquisition.
public actor ServiceClient {
    private let connection: NSXPCConnection
    private var closed = false

    public init(role: ClientRole) throws {
        let isApp = role == .application
        let identity = try SignedIdentity(
            expectedIdentifier:
                isApp ? LimitlessIdentity.application : LimitlessIdentity.commandLine)
        let connection = NSXPCConnection(
            machServiceName:
                isApp ? LimitlessIdentity.controlService : LimitlessIdentity.taskService,
            options: .privileged)
        connection.setCodeSigningRequirement(
            try identity.requirement(for: LimitlessIdentity.helper))
        connection.remoteObjectInterface = NSXPCInterface(with: LimitlessXPC.self)
        // Do not let Foundation silently reconnect a lost owner and renew old work.
        connection.interruptionHandler = { [weak connection] in connection?.invalidate() }
        self.connection = connection
        connection.activate()
    }

    isolated deinit { connection.invalidate() }

    public func close() {
        closed = true
        connection.invalidate()
    }

    public func send(_ operation: ServiceOperation) async throws -> ServiceReply {
        try Task.checkCancellation()
        guard !closed else { throw ServiceError.unavailable }
        let payload = try ServiceWire.encode(ServiceRequest(operation))
        do {
            let data: Data = try await withCheckedThrowingContinuation { continuation in
                let pending = OSAllocatedUnfairLock(
                    initialState:
                        CheckedContinuation<Data, any Error>?(continuation))
                let finish: @Sendable (Result<Data, any Error>) -> Void = { result in
                    let continuation = pending.withLock { value in
                        defer { value = nil }
                        return value
                    }
                    continuation?.resume(with: result)
                }
                // The timeout also releases the server-side owner when the caller closes below.
                DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                    finish(.failure(ServiceError.unavailable))
                }
                guard
                    let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
                        finish(.failure(ServiceError.unavailable))
                    }) as? any LimitlessXPC
                else {
                    finish(.failure(ServiceError.unavailable))
                    return
                }
                proxy.request(payload) { finish(.success($0)) }
            }
            try Task.checkCancellation()
            let reply = try ServiceWire.decodeReply(data)
            if let error = reply.error { throw error }
            return reply
        } catch {
            // Semantic refusal keeps the authenticated channel usable; transport failure does not.
            if error as? ServiceError == .unavailable || !(error is ServiceError) {
                close()
            }
            throw error
        }
    }
}

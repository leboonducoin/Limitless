import Foundation
import LimitlessCore
import LimitlessSystem

/// Confined to HelperServer's serial queue, including all bounded blocking OS operations.
final class HelperRuntime {
    var sessions: ServiceSessions
    var controller: SleepController
    var backend = MacSleepBackend()
    var powerReader = PowerSourceReader()
    var journal: SecureOwnershipJournal
    private(set) var expiredOwners: Set<UUID> = []

    init() throws {
        sessions = try ServiceSessions()
        journal = try SecureOwnershipJournal()
        controller = SleepController(restoringOwnedHold: try journal.loadOwned())
        // Restore a surviving journal before the listeners accept any request.
        _ = try reconcile(owner: UUID())
    }

    func reconcile(owner: UUID) throws -> ServiceStatus {
        let now = try SystemClock.now()
        expiredOwners.formUnion(
            try sessions.expire(now: now, consoleUser: ConsoleUser.identifier()))
        let power = powerReader.snapshot()
        var evaluation = sessions.evaluate(power: power, now: now)
        var report = controller.reconcile(
            wantsAwake: evaluation.wantsAwake, now: now,
            backend: &backend, journal: &journal)
        if report.fault != nil {
            try sessions.revokeAutomationAndStop()
            evaluation = sessions.evaluate(power: power, now: now)
            report = controller.reconcile(
                wantsAwake: false, now: now,
                backend: &backend, journal: &journal)
        }
        return ServiceStatus(
            policy: sessions.registry.policy, power: power, sleep: report,
            sessions: sessions.summaries(for: owner, evaluation: evaluation, now: now),
            sampledAt: now.wall,
            removal: sessions.isRemoving ? (journal.isRemoved ? .ready : .preparing) : .none)
    }

    func takeExpiredOwners() -> Set<UUID> {
        defer { expiredOwners.removeAll() }
        return expiredOwners
    }

    func request(_ data: Data, owner: UUID) -> ServiceReply {
        do {
            let request = try ServiceWire.decodeRequest(data)
            _ = try reconcile(owner: owner)
            if case .start = request.operation, controller.fault != nil {
                throw ServiceError.restorationRequired
            }
            let started = try sessions.apply(
                request.operation, owner: owner, now: SystemClock.now())
            switch request.operation {
            case .rearm: try controller.rearm()
            case .retryRestoration, .prepareRemoval: controller.retryRestoration()
            default: break
            }
            if request.operation == .prepareRemoval {
                let status = try reconcile(owner: owner)
                guard status.canRemoveService, !backend.hasIdleAssertion
                else { throw ServiceError.restorationRequired }
                try journal.removeUnownedDirectory()
            }
            return ServiceReply(status: try reconcile(owner: owner), startedSession: started)
        } catch {
            let failure: ServiceError
            switch error {
            case let value as ServiceError: failure = value
            case is PolicyError: failure = .sessionRejected
            case is SleepFault: failure = .restorationRequired
            default: failure = .unavailable
            }
            return ServiceReply(status: try? reconcile(owner: owner), error: failure)
        }
    }
}

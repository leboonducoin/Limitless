import Foundation
import LimitlessCore
import LimitlessSystem

final class HelperRuntime {
    var sessions: ServiceSessions
    var controller: SleepController
    var backend = MacSleepBackend()
    var powerReader = PowerSourceReader()
    var journal: SecureOwnershipJournal
    private let identity: SignedIdentity
    private var installedFiles: InstalledHelperFiles?
    private var removalReady = false
    private(set) var expiredOwners: Set<UUID> = []

    init(identity: SignedIdentity) throws {
        self.identity = identity
        sessions = try ServiceSessions()
        journal = try SecureOwnershipJournal()
        controller = SleepController(restoringOwnedHold: try journal.loadOwned())
        try reconcile()
    }

    @discardableResult
    func reconcile() throws -> (
        ClockSnapshot, PowerSnapshot, ThermalCondition, SessionEvaluation, SleepReport
    ) {
        let now = try SystemClock.now()
        expiredOwners.formUnion(
            try sessions.expire(now: now, consoleUser: ConsoleUser.identifier()))
        let power = powerReader.snapshot()
        let thermal = ThermalCondition(ProcessInfo.processInfo.thermalState)
        var evaluation = sessions.evaluate(power: power, now: now, thermal: thermal)
        var report = controller.reconcile(
            wantsAwake: evaluation.wantsAwake,
            keepsDisplayAwake: sessions.registry.policy.keepsDisplayAwake, now: now,
            backend: &backend, journal: &journal)
        if report.fault != nil {
            try sessions.revokeAutomationAndStop(reason: .powerFault, at: now.wall)
            evaluation = sessions.evaluate(power: power, now: now, thermal: thermal)
            report = controller.reconcile(
                wantsAwake: false, now: now,
                backend: &backend, journal: &journal)
        }
        return (now, power, thermal, evaluation, report)
    }

    private func status(owner: UUID) throws -> ServiceStatus {
        let (now, power, thermal, evaluation, report) = try reconcile()
        return ServiceStatus(
            policy: sessions.registry.policy, power: power, sleep: report,
            sessions: sessions.summaries(for: owner, evaluation: evaluation, now: now),
            sampledAt: now.wall,
            removal: sessions.isRemoving ? (removalReady ? .ready : .preparing) : .none,
            sudoTouchID: SudoTouchID.status(), batteryCutoff: sessions.registry.batteryCutoff,
            thermal: thermal, recentEndings: sessions.registry.recentEndings,
            protectionID: sessions.registry.protectionID,
            policyConfigured: sessions.policyConfigured)
    }

    func takeExpiredOwners() -> Set<UUID> {
        defer { expiredOwners.removeAll() }
        return expiredOwners
    }

    func request(_ data: Data, owner: UUID) -> ServiceReply {
        do {
            let request = try ServiceWire.decodeRequest(data)
            if case .setSudoTouchID = request.operation { throw ServiceError.unauthorized }
            let before = try status(owner: owner)
            switch request.operation {
            case .start, .startAgent:
                if before.thermal == .critical { throw ServiceError.thermalCritical }
                if controller.fault != nil { throw ServiceError.restorationRequired }
            case .setAutomation(true) where controller.fault != nil:
                throw ServiceError.restorationRequired
            case .cancelUpdate:
                guard sessions.isPreparingUpdate, before.canRemoveService,
                    !backend.hasIdleAssertion, try journal.loadOwned() == false
                else {
                    throw ServiceError.restorationRequired
                }
            default: break
            }
            let started = try sessions.apply(
                request.operation, owner: owner, now: SystemClock.now())
            switch request.operation {
            case .status, .heartbeat: return ServiceReply(status: before)
            case .installCLI:
                guard let user = sessions.consoleUser else { throw ServiceError.unauthorized }
                try InstalledCLI.install(identity: identity, user: user)
            case .rearm: try controller.rearm()
            case .retryRestoration, .prepareRemoval, .prepareUpdate: controller.retryRestoration()
            case .cancelUpdate: removalReady = false
            default: break
            }
            if request.operation == .prepareRemoval || request.operation == .prepareUpdate {
                removalReady = false
                let status = try status(owner: owner)
                guard status.canRemoveService, !backend.hasIdleAssertion
                else { throw ServiceError.restorationRequired }
                if request.operation == .prepareRemoval {
                    if let user = sessions.consoleUser { try InstalledCLI.remove(user: user) }
                }
                if installedFiles == nil {
                    installedFiles = try InstalledHelperFiles(identity: identity)
                }
                if request.operation == .prepareRemoval { try journal.removeUnownedDirectory() }
                removalReady = true
            }
            if request.operation == .finishRemoval {
                let status = try status(owner: owner)
                guard removalReady, status.canRemoveService,
                    !backend.hasIdleAssertion
                else { throw ServiceError.restorationRequired }
                try sessions.commitRemoval()
                try journal.removeUnownedDirectory()
                try installedFiles?.remove()
            }
            let after = try status(owner: owner)
            if let started,
                after.recentEndings.contains(where: {
                    $0.id == started && $0.reason == .thermalCritical
                })
            {
                return ServiceReply(status: after, error: .thermalCritical)
            }
            return ServiceReply(status: after, startedSession: started)
        } catch {
            let failure: ServiceError
            switch error {
            case let value as ServiceError: failure = value
            case is PolicyError: failure = .sessionRejected
            case is SleepFault: failure = .restorationRequired
            default: failure = .unavailable
            }
            return ServiceReply(status: try? status(owner: owner), error: failure)
        }
    }
}

import CoreFoundation
import Foundation
import LimitlessCore
import LimitlessSystem
import OpenDirectory

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
        if !sessions.isRemoving { removalReady = false }
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

    private func canRemove(_ status: ServiceStatus) throws -> Bool {
        guard status.canRemoveService, !backend.hasIdleAssertion else { return false }
        try journal.verifyUnownedForRemoval()
        return true
    }

    func request(_ data: Data, owner: UUID) -> ServiceReply {
        var attemptedPendingRemoval = false
        do {
            let request = try ServiceWire.decodeRequest(data)
            if case .setSudoTouchID = request.operation { throw ServiceError.unauthorized }
            try AdministratorAuthorization.verify(request)
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
            let operation: ServiceOperation
            if case .configure(let policy) = request.operation {
                operation = .configure(try policy.withAutomation(before.policy.allowsAutomation))
            } else {
                operation = request.operation
            }
            let user = sessions.consoleUser
            var savedPolicy: UserPolicy?
            if case .restorePolicy = operation, !before.policyConfigured, let user {
                savedPolicy = try SavedPowerPolicy.load(for: user)
            }
            let previousSessions: ServiceSessions? =
                if case .configure = operation { sessions } else { nil }
            let started = try sessions.apply(
                operation, owner: owner, now: SystemClock.now(), savedPolicy: savedPolicy)
            attemptedPendingRemoval =
                sessions.isPreparingRemoval
                && (operation == .prepareRemoval || operation == .finishRemoval)
            if let previousSessions, let user {
                do {
                    try SavedPowerPolicy.store(sessions.registry.policy, for: user)
                } catch {
                    sessions = previousSessions
                    throw error
                }
            }
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
                guard try canRemove(status) else { throw ServiceError.restorationRequired }
                if installedFiles == nil {
                    installedFiles = try InstalledHelperFiles(identity: identity)
                }
                removalReady = true
            }
            if request.operation == .finishRemoval {
                let status = try status(owner: owner)
                guard removalReady, try canRemove(status) else {
                    throw ServiceError.restorationRequired
                }
                if sessions.isPreparingRemoval, let user {
                    try InstalledCLI.remove(user: user)
                }
                try sessions.commitRemoval()
                if sessions.isUninstalling { try SavedPowerPolicy.removeAll() }
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
            if attemptedPendingRemoval, sessions.isPreparingRemoval,
                let current = try? status(owner: owner),
                (try? canRemove(current)) == true
            {
                sessions.cancelRemovalPreparation()
                removalReady = false
            }
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

private enum SavedPowerPolicy {
    private static let domain = LimitlessIdentity.helper + ".automation"

    private static func key(for user: UInt32) throws -> CFString {
        guard geteuid() == 0, user != 0 else { throw ServiceError.unauthorized }
        let node = try ODNode(session: ODSession.default(), type: UInt32(kODNodeTypeAuthentication))
        let query = try ODQuery(
            node: node, forRecordTypes: kODRecordTypeUsers, attribute: kODAttributeTypeUniqueID,
            matchType: ODMatchType(kODMatchEqualTo), queryValues: String(user),
            returnAttributes: [kODAttributeTypeGUID], maximumResults: 2)
        guard let records = try query.resultsAllowingPartial(false) as? [ODRecord],
            records.count == 1,
            let identifier = try records[0].values(forAttribute: kODAttributeTypeGUID).first
                as? String,
            let identity = UUID(uuidString: identifier)
        else { throw ServiceError.unavailable }
        return identity.uuidString as CFString
    }

    static func load(for user: UInt32) throws -> UserPolicy? {
        let key = try key(for: user)
        guard
            let value = CFPreferencesCopyValue(
                key, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        else { return nil }
        guard let data = value as? Data, data.count <= 1_024,
            let policy = try? JSONDecoder().decode(UserPolicy.self, from: data)
        else { throw ServiceError.unavailable }
        return policy
    }

    static func store(_ policy: UserPolicy, for user: UInt32) throws {
        let key = try key(for: user)
        let data = try JSONEncoder().encode(policy.withAutomation(false)) as CFData
        CFPreferencesSetValue(
            key, data, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        try synchronize()
    }

    static func removeAll() throws {
        guard geteuid() == 0 else { throw ServiceError.unauthorized }
        if let keys = CFPreferencesCopyKeyList(
            domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        {
            CFPreferencesSetMultiple(
                nil, keys, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            try synchronize()
        }
    }

    private static func synchronize() throws {
        guard
            CFPreferencesSynchronize(
                domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        else { throw ServiceError.unavailable }
    }
}

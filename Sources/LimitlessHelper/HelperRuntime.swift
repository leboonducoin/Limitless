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
    private var faultRevokedUser: UInt32?
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
            if let user = sessions.consoleUser, faultRevokedUser != user {
                do {
                    try AutomationConsent.store(nil, for: user)
                    faultRevokedUser = user
                } catch {}
            }
            evaluation = sessions.evaluate(power: power, now: now, thermal: thermal)
            report = controller.reconcile(
                wantsAwake: false, now: now,
                backend: &backend, journal: &journal)
        } else {
            faultRevokedUser = nil
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
            var authorizedPolicy: UserPolicy?
            if case .restorePolicy = operation, !before.policyConfigured,
                before.sleep.fault == nil, let user
            {
                authorizedPolicy = try AutomationConsent.load(for: user)
            }
            let changeRequiresConsentWrite: Bool
            switch operation {
            case .setAutomation: changeRequiresConsentWrite = true
            case .configure: changeRequiresConsentWrite = before.policy.allowsAutomation
            default: changeRequiresConsentWrite = false
            }
            let previousSessions = changeRequiresConsentWrite ? sessions : nil
            let started = try sessions.apply(
                operation, owner: owner, now: SystemClock.now(), authorizedPolicy: authorizedPolicy)
            if let previousSessions, let user {
                do {
                    let policy = sessions.registry.policy
                    try AutomationConsent.store(policy.allowsAutomation ? policy : nil, for: user)
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
                guard status.canRemoveService, !backend.hasIdleAssertion
                else { throw ServiceError.restorationRequired }
                if request.operation == .prepareRemoval {
                    if let user = sessions.consoleUser { try InstalledCLI.remove(user: user) }
                    try AutomationConsent.removeAll()
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

private enum AutomationConsent {
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
            let policy = try? JSONDecoder().decode(UserPolicy.self, from: data),
            policy.allowsAutomation
        else { throw ServiceError.unavailable }
        return policy
    }

    static func store(_ policy: UserPolicy?, for user: UInt32) throws {
        let key = try key(for: user)
        let data = try policy.map { try JSONEncoder().encode($0) as CFData }
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

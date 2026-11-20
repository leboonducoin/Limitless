import Foundation

public struct ServiceSessions: Sendable {
    public static let leaseSeconds: TimeInterval = 30
    public static let heartbeatSeconds: TimeInterval = 5
    public static let clientCapacity = 64
    public static let taskClientCapacity = clientCapacity - 4
    public private(set) var registry: SessionRegistry
    public private(set) var consoleUser: UInt32?
    public private(set) var policyConfigured = false
    private enum Drain: Equatable {
        case none
        case update(UInt32)
        case committedUpdate(UInt32)
        case removal(UInt32)
        case committedRemoval
    }
    private var drain = Drain.none
    public var isRemoving: Bool { drain != .none }
    public var isPreparingUpdate: Bool {
        if case .update = drain { return true }
        return false
    }
    public var isPreparingRemoval: Bool {
        if case .removal = drain { return true }
        return false
    }
    public var isUninstalling: Bool { isPreparingRemoval || drain == .committedRemoval }
    private struct Client: Sendable {
        let user: UInt32
        let role: ClientRole
        var lastContact: TimeInterval
        var hasStarted = false
    }
    private var clients: [UUID: Client] = [:]

    public init() throws { registry = SessionRegistry(policy: try UserPolicy()) }

    @discardableResult
    public mutating func expire(now: ClockSnapshot, consoleUser: UInt32?) throws -> Set<UUID> {
        let changedUser = self.consoleUser != consoleUser
        self.consoleUser = consoleUser
        let expired = Set(
            clients.compactMap { id, client in
                changedUser || client.user != consoleUser || now.continuous < client.lastContact
                    || now.continuous - client.lastContact >= Self.leaseSeconds ? id : nil
            })
        for id in expired { disconnect(id, at: now.wall) }
        if changedUser {
            registry = SessionRegistry(policy: try UserPolicy())
            policyConfigured = false
            if isPreparingUpdate || isPreparingRemoval { drain = .none }
        }
        return expired
    }

    public mutating func connect(
        owner: UUID, user: UInt32, role: ClientRole, now: ClockSnapshot
    ) throws {
        guard user != 0, user == consoleUser else { throw ServiceError.unauthorized }
        guard clients[owner] == nil, clients.count < Self.clientCapacity else {
            throw ServiceError.capacityReached
        }
        guard
            role != .task
                || clients.values.filter({ $0.role == .task }).count < Self.taskClientCapacity
        else { throw ServiceError.capacityReached }
        clients[owner] = Client(user: user, role: role, lastContact: now.continuous)
    }

    public mutating func disconnect(_ owner: UUID, at date: Date? = nil) {
        clients.removeValue(forKey: owner)
        registry.releaseOwner(owner, at: date)
    }

    public mutating func apply(
        _ operation: ServiceOperation, owner: UUID, now: ClockSnapshot,
        savedPolicy: UserPolicy? = nil
    ) throws -> UUID? {
        guard var client = clients[owner] else { throw ServiceError.ownerExpired }
        guard client.user == consoleUser else { throw ServiceError.unauthorized }
        guard now.continuous >= client.lastContact,
            now.continuous - client.lastContact < Self.leaseSeconds
        else {
            disconnect(owner, at: now.wall)
            throw ServiceError.ownerExpired
        }
        guard !operation.requiresApplication || client.role == .application else {
            throw ServiceError.unauthorized
        }
        if isRemoving {
            switch operation {
            case .configure, .restorePolicy, .setAutomation, .start, .startAgent, .extend, .rearm,
                .installCLI,
                .setSudoTouchID:
                throw ServiceError.removalInProgress
            case .status, .stop, .stopAll, .heartbeat, .retryRestoration, .prepareRemoval,
                .prepareUpdate, .cancelUpdate, .finishRemoval:
                break
            }
        }
        client.lastContact = now.continuous
        clients[owner] = client
        switch operation {
        case .configure(let policy):
            registry.updatePolicy(policy)
            policyConfigured = true
        case .restorePolicy:
            if !policyConfigured {
                if let savedPolicy { registry.updatePolicy(try savedPolicy.withAutomation(false)) }
                policyConfigured = true
            }
        case .setAutomation(let allowed):
            guard policyConfigured else { throw ServiceError.sessionRejected }
            registry.updatePolicy(try registry.policy.withAutomation(allowed))
        case .start, .startAgent:
            if client.role == .application, !policyConfigured {
                throw ServiceError.sessionRejected
            }
            guard client.role == .application || !client.hasStarted else {
                throw ServiceError.ownerExpired
            }
            guard !registry.sessions.values.contains(where: { $0.owner == owner }) else {
                throw PolicyError.duplicateSession
            }
            let request: SessionRequest
            let kind: SessionKind
            let agent: AgentProvider?
            if case .start(let submitted) = operation {
                request = submitted
                kind = client.role == .application ? .manual : .task
                agent = nil
            } else {
                guard client.role == .task, case .startAgent(let provider) = operation else {
                    throw ServiceError.unauthorized
                }
                request = SessionRequest(
                    mode: registry.policy.mode,
                    batteryFloor: max(20, registry.policy.batteryFloor))
                kind = .agent
                agent = provider
            }
            if kind == .agent {
                client.hasStarted = true
                clients[owner] = client
            }
            let id = try registry.start(request, owner: owner, kind: kind, now: now, agent: agent)
            client.hasStarted = true
            clients[owner] = client
            return id
        case .stop(let id):
            guard
                registry.stop(
                    id, owner: owner, reason: client.role == .task ? .taskEnded : .requested,
                    at: now.wall)
            else { throw ServiceError.unauthorized }
        case .extend(let id): try registry.extend(id, owner: owner, now: now)
        case .stopAll:
            try registry.revokeAutomationAndStop(reason: .requested, at: now.wall)
        case .prepareRemoval:
            try registry.revokeAutomationAndStop(at: now.wall)
            switch drain {
            case .committedUpdate, .committedRemoval: drain = .committedRemoval
            case .none, .update, .removal: drain = .removal(client.user)
            }
        case .prepareUpdate:
            guard registry.sessions.isEmpty else { throw ServiceError.sessionRejected }
            if drain == .none {
                drain = .update(client.user)
            } else if drain != .update(client.user) && drain != .committedUpdate(client.user) {
                throw ServiceError.removalInProgress
            }
        case .cancelUpdate:
            guard drain == .update(client.user) else { throw ServiceError.removalInProgress }
            drain = .none
        case .finishRemoval:
            guard
                drain == .removal(client.user) || drain == .committedRemoval
                    || drain == .update(client.user)
                    || drain == .committedUpdate(client.user)
            else {
                throw ServiceError.restorationRequired
            }
        case .status, .heartbeat, .rearm, .retryRestoration, .installCLI, .setSudoTouchID: break
        }
        return nil
    }

    public mutating func commitRemoval() throws {
        try registry.revokeAutomationAndStop()
        if case .update(let user) = drain { drain = .committedUpdate(user) }
        if case .removal = drain { drain = .committedRemoval }
    }

    public mutating func cancelRemovalPreparation() {
        if isPreparingRemoval { drain = .none }
    }

    public mutating func evaluate(
        power: PowerSnapshot, now: ClockSnapshot, thermal: ThermalCondition = .nominal
    ) -> SessionEvaluation {
        registry.evaluate(power: power, now: now, thermal: thermal)
    }

    public mutating func revokeAutomationAndStop(
        reason: SessionStopReason = .automationRevoked, at date: Date? = nil
    ) throws {
        try registry.revokeAutomationAndStop(reason: reason, at: date)
    }

    public func summaries(
        for owner: UUID, evaluation: SessionEvaluation, now: ClockSnapshot
    ) -> [SessionSummary] {
        registry.sessions.values.map { session in
            var limits: [TimeInterval] = []
            let elapsed = now.continuous - session.started.continuous
            if let maximum = session.authorizedDuration { limits.append(maximum - elapsed) }
            if let maximum = registry.policy.maximumDuration { limits.append(maximum - elapsed) }
            switch session.request.end {
            case .unlimited: break
            case .after(let seconds): limits.append(seconds - elapsed)
            case .at(let date): limits.append(date.timeIntervalSince(now.wall))
            }
            return SessionSummary(
                id: session.id, kind: session.kind, end: session.request.end,
                startedAt: session.started.wall, remainingSeconds: limits.min().map { max(0, $0) },
                suspension: evaluation.suspended[session.id],
                belongsToClient: session.owner == owner, agent: session.agent)
        }.sorted { $0.id.uuidString < $1.id.uuidString }
    }
}

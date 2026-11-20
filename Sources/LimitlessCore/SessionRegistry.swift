import Foundation

public enum SessionStopReason: String, Codable, Sendable {
    case expired, batteryFloor, automationRevoked, policyChanged, thermalCritical
    case requested, taskEnded, ownerLost, manualPriority, powerFault
}

public struct SessionEnding: Codable, Equatable, Sendable {
    public let id: UUID
    public let reason: SessionStopReason
    public let date: Date
}

public enum SuspensionReason: String, Codable, Sendable {
    case powerSource, unknownPowerSource, unreadableBattery
}

public struct SessionEvaluation: Equatable, Sendable {
    public let eligible: Set<UUID>
    public let suspended: [UUID: SuspensionReason]
    public let stopped: [UUID: SessionStopReason]
    public var wantsAwake: Bool { !eligible.isEmpty }
}

public struct BatteryCutoff: Codable, Equatable, Sendable {
    public let sessionID: UUID
    public let percent: Int
    public let limit: Int
}

public struct SessionRegistry: Sendable {
    public private(set) var policy: UserPolicy
    public private(set) var sessions: [UUID: Session] = [:]
    public private(set) var protectionID: UUID?
    public private(set) var batteryCutoff: BatteryCutoff?
    public private(set) var recentEndings: [SessionEnding] = []
    public static let capacity = 256

    public init(policy: UserPolicy) { self.policy = policy }

    public mutating func updatePolicy(_ policy: UserPolicy) { self.policy = policy }

    @discardableResult
    public mutating func start(
        _ request: SessionRequest, owner: UUID, kind: SessionKind,
        now: ClockSnapshot, id: UUID = UUID(), agent: AgentProvider? = nil
    ) throws -> UUID {
        try request.validate(policy: policy, kind: kind, now: now)
        guard sessions[id] == nil else { throw PolicyError.duplicateSession }
        guard sessions.count < Self.capacity else { throw PolicyError.sessionLimitReached }
        if kind == .agent, sessions.values.contains(where: { $0.kind == .manual }) {
            throw ServiceError.sessionRejected
        }
        let sharedID = protectionID ?? UUID()
        if kind == .manual {
            guard !sessions.values.contains(where: { $0.kind == .manual }) else {
                throw PolicyError.duplicateSession
            }
            for agent in sessions.values where agent.kind == .agent {
                end(agent.id, reason: .manualPriority, at: now.wall)
            }
        }
        sessions[id] = Session(
            id: id, owner: owner, kind: kind, request: request, agent: agent,
            started: now, authorizedDuration: policy.maximumDuration
        )
        protectionID = sharedID
        batteryCutoff = nil
        return id
    }

    @discardableResult
    public mutating func stop(
        _ id: UUID, owner: UUID, reason: SessionStopReason = .requested, at date: Date? = nil
    ) -> Bool {
        guard sessions[id]?.owner == owner else { return false }
        end(id, reason: reason, at: date)
        return true
    }

    public mutating func extend(_ id: UUID, owner: UUID, now: ClockSnapshot) throws {
        guard let session = sessions[id], session.owner == owner, session.kind == .manual else {
            throw ServiceError.unauthorized
        }
        guard !session.hasExpired(at: now, policy: policy) else {
            throw ServiceError.sessionRejected
        }
        let end: SessionEnd
        let remaining: TimeInterval
        let elapsed = now.continuous - session.started.continuous
        switch session.request.end {
        case .unlimited: throw ServiceError.sessionRejected
        case .after(let seconds):
            let extended = seconds + 15 * 60
            guard extended > seconds else { throw PolicyError.invalidDuration }
            end = .after(seconds: extended)
            remaining = extended - elapsed
        case .at(let date):
            let extended = date.addingTimeInterval(15 * 60)
            guard extended > date else { throw PolicyError.invalidDate }
            end = .at(extended)
            remaining = extended.timeIntervalSince(now.wall)
        }
        for maximum in [session.authorizedDuration, policy.maximumDuration].compactMap({ $0 }) {
            guard remaining <= maximum - elapsed else { throw ServiceError.sessionRejected }
        }
        let request = SessionRequest(
            mode: session.request.mode, batteryFloor: session.request.batteryFloor, end: end)
        try request.validate(policy: policy, kind: session.kind, now: now)
        sessions[id] = Session(
            id: id, owner: owner, kind: session.kind, request: request, agent: session.agent,
            started: session.started, authorizedDuration: session.authorizedDuration)
    }

    public mutating func releaseOwner(_ owner: UUID, at date: Date? = nil) {
        for session in sessions.values where session.owner == owner {
            end(session.id, reason: .ownerLost, at: date)
        }
    }

    public mutating func stopAll(reason: SessionStopReason = .requested, at date: Date? = nil) {
        if date == nil {
            sessions.removeAll()
            protectionID = nil
        } else {
            for id in sessions.keys { end(id, reason: reason, at: date) }
        }
    }

    public mutating func revokeAutomationAndStop(
        reason: SessionStopReason = .automationRevoked, at date: Date? = nil
    ) throws {
        stopAll(reason: reason, at: date)
        policy = try UserPolicy(
            mode: policy.mode, batteryFloor: policy.batteryFloor,
            maximumDuration: policy.maximumDuration, allowsAutomation: false,
            keepsDisplayAwake: policy.keepsDisplayAwake
        )
    }

    public mutating func evaluate(
        power: PowerSnapshot, now: ClockSnapshot, thermal: ThermalCondition = .nominal
    ) -> SessionEvaluation {
        var eligible: Set<UUID> = []
        var suspended: [UUID: SuspensionReason] = [:]
        var stopped: [UUID: SessionStopReason] = [:]

        for session in sessions.values {
            if thermal == .critical {
                stopped[session.id] = .thermalCritical
                continue
            }
            if session.kind != .manual, !policy.allowsAutomation {
                stopped[session.id] = .automationRevoked
                continue
            }
            if session.hasExpired(at: now, policy: policy) {
                stopped[session.id] = .expired
                continue
            }
            let mode = session.request.mode ?? policy.mode
            if mode != .all, policy.mode != .all, mode != policy.mode {
                stopped[session.id] = .policyChanged
                continue
            }
            let floor = max(session.request.batteryFloor ?? 0, policy.batteryFloor)
            if floor > 0 {
                switch power.battery {
                case .available(let percent, let discharging):
                    if power.source == .battery || discharging, percent <= floor {
                        stopped[session.id] = .batteryFloor
                        batteryCutoff = BatteryCutoff(
                            sessionID: session.id, percent: percent, limit: floor)
                        continue
                    }
                case .unavailable:
                    suspended[session.id] = .unreadableBattery
                    continue
                case .notPresent: break
                }
            }
            guard power.source != .unknown else {
                suspended[session.id] = .unknownPowerSource
                continue
            }
            guard mode.allows(power.source), policy.mode.allows(power.source) else {
                suspended[session.id] = .powerSource
                continue
            }
            eligible.insert(session.id)
        }
        for (id, reason) in stopped { end(id, reason: reason, at: now.wall) }
        return SessionEvaluation(eligible: eligible, suspended: suspended, stopped: stopped)
    }

    private mutating func end(_ id: UUID, reason: SessionStopReason, at date: Date?) {
        sessions.removeValue(forKey: id)
        if sessions.isEmpty { protectionID = nil }
        guard let date else { return }
        if recentEndings.count == 32 { recentEndings.removeFirst() }
        recentEndings.append(SessionEnding(id: id, reason: reason, date: date))
    }
}

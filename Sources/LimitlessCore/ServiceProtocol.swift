import Foundation

public enum ClientRole: Sendable {
    case application, task
}

public enum ServiceOperation: Codable, Equatable, Sendable {
    case status
    case configure(UserPolicy)
    case restorePolicy(UserPolicy)
    case setAutomation(Bool)
    case start(SessionRequest)
    case startAgent(AgentProvider)
    case stop(UUID)
    case extend(UUID)
    case stopAll
    case heartbeat
    case rearm
    case retryRestoration
    case prepareRemoval
    case prepareUpdate
    case cancelUpdate
    case finishRemoval
    case installCLI
    case setSudoTouchID(Bool)

    public var requiresApplication: Bool {
        switch self {
        case .configure, .restorePolicy, .setAutomation, .extend, .stopAll, .rearm,
            .retryRestoration,
            .prepareRemoval,
            .prepareUpdate, .cancelUpdate,
            .finishRemoval, .installCLI, .setSudoTouchID:
            true
        case .status, .start, .startAgent, .stop, .heartbeat: false
        }
    }
}

public enum ServiceError: String, Error, Codable, Sendable {
    case invalidMessage, incompatibleVersion, unauthorized, ownerExpired, capacityReached
    case sessionRejected, restorationRequired, removalInProgress, unavailable
    case sudoTouchIDPermissionDenied, sudoTouchIDFailed, thermalCritical
}

public enum RemovalState: String, Codable, Equatable, Sendable {
    case none, preparing, ready
}

public enum SudoTouchIDState: String, Codable, Equatable, Sendable {
    case unavailable, disabled, enabled, external
}

public struct ServiceRequest: Codable, Sendable {
    public let version: Int
    public let operation: ServiceOperation
    public init(_ operation: ServiceOperation) {
        version = ServiceWire.version
        self.operation = operation
    }
}

public struct SessionSummary: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let kind: SessionKind
    public let end: SessionEnd
    public let startedAt: Date
    public let remainingSeconds: TimeInterval?
    public let suspension: SuspensionReason?
    public let belongsToClient: Bool
    public let agent: AgentProvider?

    public init(
        id: UUID, kind: SessionKind, end: SessionEnd, startedAt: Date,
        remainingSeconds: TimeInterval?, suspension: SuspensionReason?, belongsToClient: Bool,
        agent: AgentProvider? = nil
    ) {
        self.id = id
        self.kind = kind
        self.end = end
        self.startedAt = startedAt
        self.remainingSeconds = remainingSeconds
        self.suspension = suspension
        self.belongsToClient = belongsToClient
        self.agent = agent
    }
}

public struct ServiceStatus: Codable, Equatable, Sendable {
    public let policy: UserPolicy
    public let policyConfigured: Bool
    public let power: PowerSnapshot
    public let sleep: SleepReport
    public let sessions: [SessionSummary]
    public let sampledAt: Date
    public let removal: RemovalState
    public let sudoTouchID: SudoTouchIDState
    public let batteryCutoff: BatteryCutoff?
    public let thermal: ThermalCondition
    public let recentEndings: [SessionEnding]
    public let protectionID: UUID?

    public var protectionRemainingSeconds: TimeInterval? {
        let deadlines = sessions.compactMap(\.remainingSeconds)
        return deadlines.count == sessions.count ? deadlines.max() : nil
    }

    public var canRemoveService: Bool {
        removal != .none && sessions.isEmpty && !sleep.ownsGlobalHold
            && sleep.observed == .allowed && (sleep.phase == .inactive || sleep.phase == .blocked)
    }

    public var diagnosticSummary: String {
        let end = recentEndings.last?.reason.rawValue ?? "none"
        return """
            State: \(sleep.phase.rawValue)
            Observed sleep flag: \(sleep.observed.rawValue)
            Owned power change: \(sleep.ownsGlobalHold ? "yes" : "no")
            Power source: \(power.source.rawValue)
            Thermal state: \(thermal.rawValue)
            Battery reserve: \(policy.batteryFloor)%
            Shared session: \(sessions.isEmpty ? "none" : "present")
            Active or suspended requests: \(sessions.count)
            Last stop reason: \(end)
            Power fault: \(sleep.fault?.rawValue ?? "none")
            """
    }

    public var canRestoreAutomation: Bool {
        policyConfigured && !policy.allowsAutomation && sessions.isEmpty && removal == .none
            && sleep.phase == .inactive && sleep.observed == .allowed && !sleep.ownsGlobalHold
            && sleep.fault == nil
    }

    public init(
        policy: UserPolicy, power: PowerSnapshot, sleep: SleepReport,
        sessions: [SessionSummary], sampledAt: Date, removal: RemovalState = .none,
        sudoTouchID: SudoTouchIDState = .unavailable, batteryCutoff: BatteryCutoff? = nil,
        thermal: ThermalCondition = .unknown, recentEndings: [SessionEnding] = [],
        protectionID: UUID? = nil, policyConfigured: Bool = true
    ) {
        self.policy = policy
        self.policyConfigured = policyConfigured
        self.power = power
        self.sleep = sleep
        self.sessions = sessions
        self.sampledAt = sampledAt
        self.removal = removal
        self.sudoTouchID = sudoTouchID
        self.batteryCutoff = batteryCutoff
        self.thermal = thermal
        self.recentEndings = recentEndings
        self.protectionID = protectionID
    }
}

public struct ServiceReply: Codable, Sendable {
    public let version: Int
    public let status: ServiceStatus?
    public let startedSession: UUID?
    public let error: ServiceError?
    public let sudoTouchID: SudoTouchIDState?

    public init(
        status: ServiceStatus? = nil, startedSession: UUID? = nil, error: ServiceError? = nil,
        sudoTouchID: SudoTouchIDState? = nil
    ) {
        version = ServiceWire.version
        self.status = status
        self.startedSession = startedSession
        self.error = error
        self.sudoTouchID = sudoTouchID
    }
}

public enum ServiceWire {
    public static let version = 13
    public static let maximumMessageBytes = 131_072

    private struct Header: Decodable {
        let version: Int
    }

    public static func decodeRequest(_ data: Data) throws -> ServiceRequest {
        let request: ServiceRequest = try decode(data)
        guard request.version == version else { throw ServiceError.incompatibleVersion }
        return request
    }

    public static func decodeReply(_ data: Data) throws -> ServiceReply {
        let reply: ServiceReply = try decode(data)
        guard reply.version == version else { throw ServiceError.incompatibleVersion }
        return reply
    }

    public static func encode(_ value: some Encodable) throws -> Data {
        let data = try JSONEncoder().encode(value)
        guard data.count <= maximumMessageBytes else { throw ServiceError.invalidMessage }
        return data
    }

    private static func decode<T: Decodable>(_ data: Data) throws -> T {
        guard !data.isEmpty, data.count <= maximumMessageBytes else {
            throw ServiceError.invalidMessage
        }
        let decoder = JSONDecoder()
        do { return try decoder.decode(T.self, from: data) } catch {
            if let header = try? decoder.decode(Header.self, from: data),
                header.version != version
            {
                throw ServiceError.incompatibleVersion
            }
            throw ServiceError.invalidMessage
        }
    }
}

import Foundation

/// Roles come from separate authenticated endpoints, never from request data.
public enum ClientRole: Sendable {
    case application, task
}

public enum ServiceOperation: Codable, Equatable, Sendable {
    case status
    case configure(UserPolicy)
    case start(SessionRequest)
    case stop(UUID)
    case stopAll
    case heartbeat
    case rearm
    case retryRestoration

    public var requiresApplication: Bool {
        switch self {
        case .configure, .stopAll, .rearm, .retryRestoration: true
        case .status, .start, .stop, .heartbeat: false
        }
    }
}

public enum ServiceError: String, Error, Codable, Sendable {
    case invalidMessage, incompatibleVersion, unauthorized, ownerExpired, capacityReached
    case sessionRejected, restorationRequired, unavailable
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
}

public struct ServiceStatus: Codable, Equatable, Sendable {
    public let policy: UserPolicy
    public let power: PowerSnapshot
    public let sleep: SleepReport
    public let sessions: [SessionSummary]
    public let sampledAt: Date

    public init(
        policy: UserPolicy, power: PowerSnapshot, sleep: SleepReport,
        sessions: [SessionSummary], sampledAt: Date
    ) {
        self.policy = policy
        self.power = power
        self.sleep = sleep
        self.sessions = sessions
        self.sampledAt = sampledAt
    }
}

public struct ServiceReply: Codable, Sendable {
    public let version: Int
    public let status: ServiceStatus?
    public let startedSession: UUID?
    public let error: ServiceError?

    public init(
        status: ServiceStatus? = nil, startedSession: UUID? = nil, error: ServiceError? = nil
    ) {
        version = ServiceWire.version
        self.status = status
        self.startedSession = startedSession
        self.error = error
    }
}

/// NSData is the only XPC payload type; decoding and semantic validation happen in the helper.
public enum ServiceWire {
    public static let version = 1
    public static let maximumMessageBytes = 131_072

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
        do { return try JSONDecoder().decode(T.self, from: data) } catch {
            throw ServiceError.invalidMessage
        }
    }
}

import Foundation
import Testing

@testable import LimitlessCore

private func serviceClock(_ time: TimeInterval) throws -> ClockSnapshot {
    try ClockSnapshot(continuous: time, wall: Date(timeIntervalSince1970: 1_000 + time))
}

private func service() throws -> (ServiceSessions, UUID, UUID) {
    var value = try ServiceSessions()
    let app = UUID()
    let task = UUID()
    let now = try serviceClock(0)
    try value.expire(now: now, consoleUser: 501)
    try value.connect(owner: app, user: 501, role: .application, now: now)
    try value.connect(owner: task, user: 501, role: .task, now: now)
    return (value, app, task)
}

@Test func taskEndpointCannotChangePolicyOrRearmAndCannotImpersonateApp() throws {
    var (value, app, task) = try service()
    let now = try serviceClock(0)
    for operation in [
        ServiceOperation.configure(try UserPolicy(allowsAutomation: true)),
        .stopAll, .rearm, .retryRestoration,
    ] {
        #expect(throws: ServiceError.unauthorized) {
            try value.apply(operation, owner: task, now: now)
        }
    }
    #expect(throws: PolicyError.automationNotAuthorized) {
        try value.apply(.start(SessionRequest()), owner: task, now: now)
    }
    _ = try value.apply(.configure(try UserPolicy(allowsAutomation: true)), owner: app, now: now)
    let started = try value.apply(.start(SessionRequest()), owner: task, now: now)
    let id = try #require(started)
    #expect(value.registry.sessions[id]?.kind == .task)
    #expect(throws: ServiceError.unauthorized) { try value.apply(.stop(id), owner: app, now: now) }
}

@Test func expiredLeaseCannotBeRenewedOrResurrectWork() throws {
    var (value, app, _) = try service()
    _ = try value.apply(.start(SessionRequest()), owner: app, now: serviceClock(0))
    #expect(throws: ServiceError.ownerExpired) {
        try value.apply(.heartbeat, owner: app, now: serviceClock(30))
    }
    #expect(value.registry.sessions.isEmpty)
    #expect(throws: ServiceError.ownerExpired) {
        try value.apply(.start(SessionRequest()), owner: app, now: serviceClock(31))
    }
}

@Test func heartbeatMaintainsLivenessWithoutExtendingAuthorizedDeadline() throws {
    var (value, app, task) = try service()
    _ = try value.apply(
        .configure(try UserPolicy(maximumDuration: 10, allowsAutomation: true)),
        owner: app, now: serviceClock(0))
    _ = try value.apply(.start(SessionRequest()), owner: task, now: serviceClock(0))
    _ = try value.apply(.heartbeat, owner: task, now: serviceClock(9))
    let evaluation = value.evaluate(
        power: PowerSnapshot(source: .external, battery: .notPresent),
        now: try serviceClock(10))
    #expect(evaluation.stopped.values.first == .expired)
    _ = try value.apply(.heartbeat, owner: task, now: serviceClock(11))
    #expect(value.registry.sessions.isEmpty)
    #expect(throws: ServiceError.ownerExpired) {
        try value.apply(.start(SessionRequest()), owner: task, now: serviceClock(11))
    }
}

@Test func disconnectedTaskReleasesOnlyItsOwnDemand() throws {
    var (value, app, task) = try service()
    _ = try value.apply(
        .configure(try UserPolicy(allowsAutomation: true)), owner: app, now: serviceClock(0))
    let manual = try value.apply(.start(SessionRequest()), owner: app, now: serviceClock(0))
    _ = try value.apply(.start(SessionRequest()), owner: task, now: serviceClock(0))
    value.disconnect(task)
    #expect(value.registry.sessions.count == 1)
    #expect(value.registry.sessions.values.first?.id == manual)
    #expect(throws: PolicyError.duplicateSession) {
        try value.apply(.start(SessionRequest()), owner: app, now: serviceClock(1))
    }
}

@Test func consoleSwitchResetsAuthorizationAndNeverAdmitsRootOrBackgroundUser() throws {
    var (value, app, task) = try service()
    _ = try value.apply(
        .configure(try UserPolicy(batteryFloor: 0, allowsAutomation: true)),
        owner: app, now: serviceClock(0))
    _ = try value.apply(.start(SessionRequest()), owner: task, now: serviceClock(0))
    let revoked = try value.expire(now: serviceClock(1), consoleUser: 502)
    #expect(revoked == [app, task])
    #expect(value.registry.sessions.isEmpty)
    #expect(value.registry.policy == (try UserPolicy()))
    for user: UInt32 in [0, 501] {
        #expect(throws: ServiceError.unauthorized) {
            try value.connect(owner: UUID(), user: user, role: .application, now: serviceClock(1))
        }
    }
}

@Test func watchdogExpiresStaleClientsAndBoundsConnections() throws {
    var value = try ServiceSessions()
    try value.expire(now: serviceClock(0), consoleUser: 501)
    for _ in 0..<ServiceSessions.clientCapacity {
        try value.connect(owner: UUID(), user: 501, role: .task, now: serviceClock(0))
    }
    #expect(throws: ServiceError.capacityReached) {
        try value.connect(owner: UUID(), user: 501, role: .task, now: serviceClock(0))
    }
    #expect(try value.expire(now: serviceClock(30), consoleUser: 501).count == 64)
    try value.connect(owner: UUID(), user: 501, role: .task, now: serviceClock(30))
}

@Test func transportRejectsOversizeMalformedUnknownVersionsAndInvalidPolicy() throws {
    for data in [
        Data(), Data("{}".utf8), Data(repeating: 32, count: ServiceWire.maximumMessageBytes + 1),
        Data(
            #"{"version":1,"operation":{"configure":{"_0":{"mode":"all","batteryFloor":51,"allowsAutomation":true}}}}"#
                .utf8),
    ] {
        #expect(throws: ServiceError.invalidMessage) { try ServiceWire.decodeRequest(data) }
    }
    #expect(throws: ServiceError.incompatibleVersion) {
        try ServiceWire.decodeRequest(Data(#"{"version":2,"operation":{"status":{}}}"#.utf8))
    }
    for operation in [
        ServiceOperation.status, .heartbeat, .stop(UUID()), .rearm, .retryRestoration,
        .stopAll, .configure(try UserPolicy()), .start(SessionRequest(end: .after(seconds: 60))),
    ] {
        #expect(
            try ServiceWire.decodeRequest(ServiceWire.encode(ServiceRequest(operation))).operation
                == operation)
    }
}

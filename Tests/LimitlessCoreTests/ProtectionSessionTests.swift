import Foundation
import Testing

@testable import LimitlessCore

private func clock(_ seconds: Double) throws -> ClockSnapshot {
    try ClockSnapshot(continuous: seconds, wall: Date(timeIntervalSince1970: 10_000 + seconds))
}

private let external = PowerSnapshot(source: .external, battery: .notPresent)

@Test func independentRequestsShareOneProtectionUntilTheLastOwnerLeaves() throws {
    var registry = SessionRegistry(policy: try UserPolicy(allowsAutomation: true))
    let first = UUID()
    let second = UUID()
    let a = try registry.start(
        .init(end: .after(seconds: 30)), owner: first, kind: .task, now: clock(0))
    let sharedID = try #require(registry.protectionID)
    let b = try registry.start(
        .init(end: .after(seconds: 60)), owner: second, kind: .task, now: clock(0))
    #expect(registry.protectionID == sharedID)
    #expect(registry.evaluate(power: external, now: try clock(1)).eligible == [a, b])
    let expired = registry.evaluate(power: external, now: try clock(30))
    #expect(expired.stopped[a] == .expired && expired.eligible == [b])
    #expect(registry.protectionID == sharedID)
    let stoppedByWrongOwner = registry.stop(b, owner: first)
    #expect(!stoppedByWrongOwner)
    registry.releaseOwner(second, at: try clock(31).wall)
    #expect(registry.protectionID == nil && registry.sessions.isEmpty)
    try registry.start(.init(), owner: first, kind: .task, now: clock(32))
    #expect(registry.protectionID != nil && registry.protectionID != sharedID)
}

@Test func aStricterRequestStopsOnItsOwnReserveWithinTheSameProtection() throws {
    var registry = SessionRegistry(policy: try UserPolicy(batteryFloor: 20, allowsAutomation: true))
    let a = try registry.start(.init(batteryFloor: 40), owner: UUID(), kind: .task, now: clock(0))
    let b = try registry.start(.init(batteryFloor: 25), owner: UUID(), kind: .task, now: clock(0))
    let sharedID = try #require(registry.protectionID)
    let power = PowerSnapshot(
        source: .battery, battery: .available(percent: 35, isDischarging: true))
    let cutoff = registry.evaluate(power: power, now: try clock(1))
    #expect(cutoff.stopped[a] == .batteryFloor && cutoff.eligible == [b])
    #expect(registry.protectionID == sharedID)
    let critical = registry.evaluate(power: power, now: try clock(2), thermal: .critical)
    #expect(critical.stopped[b] == .thermalCritical && !critical.wantsAwake)
    #expect(registry.protectionID == nil)
    #expect(!registry.evaluate(power: external, now: try clock(3)).wantsAwake)
}

@Test func aSecondManualOwnerCannotReplaceOrExtendTheCurrentSession() throws {
    var registry = SessionRegistry(policy: try UserPolicy())
    let owner = UUID()
    let other = UUID()
    let id = try registry.start(
        .init(end: .after(seconds: 60)), owner: owner, kind: .manual, now: clock(0))
    let sharedID = try #require(registry.protectionID)
    #expect(throws: PolicyError.duplicateSession) {
        try registry.start(.init(), owner: other, kind: .manual, now: clock(1))
    }
    #expect(throws: ServiceError.unauthorized) {
        try registry.extend(id, owner: other, now: clock(1))
    }
    try registry.extend(id, owner: owner, now: clock(1))
    #expect(registry.sessions[id]?.request.end == .after(seconds: 960))
    #expect(registry.protectionID == sharedID)
}

@Test func manualPriorityDoesNotRecreateTheSharedProtection() throws {
    var registry = SessionRegistry(policy: try UserPolicy(allowsAutomation: true))
    let agent = try registry.start(.init(), owner: UUID(), kind: .agent, now: clock(0))
    let sharedID = try #require(registry.protectionID)
    let manual = try registry.start(.init(), owner: UUID(), kind: .manual, now: clock(1))
    #expect(registry.protectionID == sharedID)
    #expect(registry.sessions[manual] != nil && registry.sessions[agent] == nil)
    #expect(registry.recentEndings.last?.reason == .manualPriority)
}

@Test func stopAllClearsRequestsAndSharedProtectionForEveryCaller() throws {
    var registry = SessionRegistry(policy: try UserPolicy(allowsAutomation: true))
    try registry.start(.init(), owner: UUID(), kind: .task, now: clock(0))
    try registry.start(.init(), owner: UUID(), kind: .agent, now: clock(0))
    registry.stopAll(at: try clock(1).wall)
    #expect(registry.protectionID == nil && registry.sessions.isEmpty)
    #expect(registry.recentEndings.map(\.reason) == [.requested, .requested])
}

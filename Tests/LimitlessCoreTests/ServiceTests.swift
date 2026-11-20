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

@Test func taskConnectionsLeaveCapacityForPowerControls() throws {
    var value = try ServiceSessions()
    let now = try serviceClock(0)
    try value.expire(now: now, consoleUser: 501)
    for _ in 0..<ServiceSessions.taskClientCapacity {
        try value.connect(owner: UUID(), user: 501, role: .task, now: now)
    }
    #expect(throws: ServiceError.capacityReached) {
        try value.connect(owner: UUID(), user: 501, role: .task, now: now)
    }
    let app = UUID()
    try value.connect(owner: app, user: 501, role: .application, now: now)
    _ = try value.apply(.status, owner: app, now: now)
}

@Test func aFreshHelperUsesDefaultsUntilTheUserSavesPowerLimits() throws {
    var (value, app, _) = try service()
    let now = try serviceClock(0)
    let approved = try UserPolicy(
        mode: .external, batteryFloor: 35, maximumDuration: 60, allowsAutomation: true)
    _ = try value.apply(.restorePolicy, owner: app, now: now)
    #expect(value.registry.policy == (try UserPolicy()))
    _ = try value.apply(.restorePolicy, owner: app, now: now, savedPolicy: approved)
    #expect(value.registry.policy == (try UserPolicy()))
}

@Test func aFreshHelperRestoresManualLimitsBeforeEnablingAutomation() throws {
    var (value, app, _) = try service()
    let now = try serviceClock(0)
    let saved = try UserPolicy(
        mode: .external, batteryFloor: 80, maximumDuration: 1_200, keepsDisplayAwake: false)
    #expect(throws: ServiceError.sessionRejected) {
        try value.apply(.start(.init()), owner: app, now: now)
    }
    _ = try value.apply(
        .restorePolicy, owner: app, now: now, savedPolicy: try saved.withAutomation(true))
    #expect(value.policyConfigured && value.registry.policy == saved)
    let second = UUID()
    try value.connect(owner: second, user: 501, role: .application, now: now)
    _ = try value.apply(.restorePolicy, owner: second, now: now)
    #expect(value.registry.policy == saved)
    _ = try value.apply(.start(.init()), owner: app, now: now)
    let battery = PowerSnapshot(
        source: .battery, battery: .available(percent: 45, isDischarging: true))
    let evaluation = value.evaluate(power: battery, now: now)
    #expect(!evaluation.wantsAwake)
    try value.expire(now: now, consoleUser: 502)
    #expect(!value.policyConfigured && value.registry.sessions.isEmpty)
}

@Test func automationTogglePreservesTheLatestPowerLimits() throws {
    var (value, app, _) = try service()
    let now = try serviceClock(0)
    let policy = try UserPolicy(
        mode: .external, batteryFloor: 80, maximumDuration: 1_200, keepsDisplayAwake: false)
    _ = try value.apply(.configure(policy), owner: app, now: now)
    _ = try value.apply(.setAutomation(true), owner: app, now: now)
    #expect(value.registry.policy == (try policy.withAutomation(true)))
    _ = try value.apply(.setAutomation(false), owner: app, now: now)
    #expect(value.registry.policy == policy)
}

@Test func taskEndpointCannotChangePolicyOrRearmAndCannotImpersonateApp() throws {
    var (value, app, task) = try service()
    let now = try serviceClock(0)
    for operation in [
        ServiceOperation.configure(try UserPolicy(allowsAutomation: true)),
        .restorePolicy,
        .stopAll, .rearm, .retryRestoration, .prepareRemoval, .prepareUpdate, .finishRemoval,
        .installCLI, .extend(UUID()), .setSudoTouchID(true), .setSudoTouchID(false),
        .setAutomation(true), .cancelUpdate,
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

@Test func stoppingAutomatedWorkRequiresApprovalBeforeNewTaskConnectionsCanStart() throws {
    var (value, app, task) = try service()
    let now = try serviceClock(0)
    _ = try value.apply(.configure(try UserPolicy(allowsAutomation: true)), owner: app, now: now)
    _ = try value.apply(.start(SessionRequest()), owner: task, now: now)
    _ = try value.apply(.stopAll, owner: app, now: now)
    #expect(!value.registry.policy.allowsAutomation)
    #expect(value.registry.sessions.isEmpty)
    #expect(throws: ServiceError.ownerExpired) {
        try value.apply(.start(SessionRequest()), owner: task, now: now)
    }
    let next = UUID()
    try value.connect(owner: next, user: 501, role: .task, now: now)
    #expect(throws: PolicyError.automationNotAuthorized) {
        try value.apply(.start(SessionRequest()), owner: next, now: now)
    }
    _ = try value.apply(.setAutomation(true), owner: app, now: now)
    #expect(try value.apply(.start(SessionRequest()), owner: next, now: now) != nil)
}

@Test(arguments: [SessionEnd.after(seconds: 60), .at(Date(timeIntervalSince1970: 1_060))])
func repeatedExtensionsAccumulateOnTheOwnedDeadlineWithoutRestarting(_ end: SessionEnd) throws {
    var (value, app, task) = try service()
    _ = try value.apply(.configure(try UserPolicy()), owner: app, now: serviceClock(0))
    let id = try #require(
        try value.apply(.start(.init(end: end)), owner: app, now: serviceClock(0)))
    for _ in 0..<100 {
        _ = try value.apply(.extend(id), owner: app, now: serviceClock(10))
    }
    let evaluation = value.evaluate(
        power: .init(source: .external, battery: .notPresent), now: try serviceClock(10))
    let summary = try #require(
        value.summaries(for: app, evaluation: evaluation, now: try serviceClock(10)).first)
    #expect(summary.id == id && summary.remainingSeconds == 90_050)
    #expect(value.registry.sessions[id]?.started == (try serviceClock(0)))
    #expect(value.registry.sessions[id]?.kind == .manual)
    #expect(throws: ServiceError.unauthorized) {
        try value.apply(.extend(id), owner: task, now: serviceClock(10))
    }
    let other = UUID()
    try value.connect(owner: other, user: 501, role: .application, now: serviceClock(10))
    #expect(throws: ServiceError.unauthorized) {
        try value.apply(.extend(id), owner: other, now: serviceClock(10))
    }
    _ = try value.apply(.stopAll, owner: app, now: serviceClock(10))
    #expect(throws: ServiceError.unauthorized) {
        try value.apply(.extend(id), owner: app, now: serviceClock(10))
    }
    #expect(value.registry.sessions.isEmpty)
}

@Test func extensionsCannotReviveExpiredSessionsOrExceedEitherPolicyCeiling() throws {
    var (value, app, _) = try service()
    _ = try value.apply(
        .configure(try UserPolicy(maximumDuration: 1_000)), owner: app, now: serviceClock(0))
    let id = try #require(
        try value.apply(.start(.init(end: .after(seconds: 60))), owner: app, now: serviceClock(0)))
    _ = try value.apply(.extend(id), owner: app, now: serviceClock(1))
    #expect(throws: ServiceError.sessionRejected) {
        try value.apply(.extend(id), owner: app, now: serviceClock(1))
    }
    _ = try value.apply(.configure(try UserPolicy()), owner: app, now: serviceClock(1))
    #expect(throws: ServiceError.sessionRejected) {
        try value.apply(.extend(id), owner: app, now: serviceClock(1))
    }
    _ = try value.apply(
        .configure(try UserPolicy(maximumDuration: 500)), owner: app, now: serviceClock(1))
    #expect(throws: ServiceError.sessionRejected) {
        try value.apply(.extend(id), owner: app, now: serviceClock(1))
    }
    _ = try value.apply(.stopAll, owner: app, now: serviceClock(1))
    let short = try #require(
        try value.apply(.start(.init(end: .after(seconds: 1))), owner: app, now: serviceClock(1)))
    #expect(throws: ServiceError.sessionRejected) {
        try value.apply(.extend(short), owner: app, now: serviceClock(2))
    }
    _ = try value.apply(.stopAll, owner: app, now: serviceClock(2))
    let unlimited = try #require(
        try value.apply(.start(.init()), owner: app, now: serviceClock(2)))
    #expect(throws: ServiceError.sessionRejected) {
        try value.apply(.extend(unlimited), owner: app, now: serviceClock(2))
    }
}

@Test func agentsShareAwakeTimeAndYieldPermanentlyToManualSessions() throws {
    var (value, app, first) = try service()
    let now = try serviceClock(0)
    _ = try value.apply(.configure(try UserPolicy(allowsAutomation: true)), owner: app, now: now)
    let startedA = try value.apply(.startAgent(.other), owner: first, now: now)
    let a = try #require(startedA)
    let second = UUID()
    try value.connect(owner: second, user: 501, role: .task, now: now)
    let startedB = try value.apply(.startAgent(.other), owner: second, now: now)
    let b = try #require(startedB)
    #expect(value.registry.sessions[a]?.request.mode == .all)
    #expect(value.registry.sessions[a]?.request.batteryFloor == 20)
    _ = try value.apply(.stop(a), owner: first, now: now)
    #expect(value.registry.sessions[b] != nil)
    let startedManual = try value.apply(.start(.init()), owner: app, now: now)
    let manual = try #require(startedManual)
    #expect(value.registry.sessions.count == 1 && value.registry.sessions[manual] != nil)
    #expect(throws: ServiceError.ownerExpired) {
        try value.apply(.startAgent(.other), owner: second, now: now)
    }
    let third = UUID()
    try value.connect(owner: third, user: 501, role: .task, now: now)
    let original = value.registry.policy
    #expect(throws: ServiceError.sessionRejected) {
        try value.apply(.startAgent(.other), owner: third, now: now)
    }
    #expect(value.registry.policy == original && value.registry.sessions[manual] != nil)
    _ = try value.apply(.stop(manual), owner: app, now: now)
    #expect(throws: ServiceError.ownerExpired) {
        try value.apply(.startAgent(.other), owner: third, now: now)
    }
}

@Test func agentsRespectStricterLimitsAndNeverReacquireAfterBatteryCutoff() throws {
    var (value, app, task) = try service()
    let now = try serviceClock(0)
    _ = try value.apply(
        .configure(
            try UserPolicy(
                mode: .battery, batteryFloor: 35,
                maximumDuration: 60, allowsAutomation: true)), owner: app, now: now)
    let started = try value.apply(.startAgent(.other), owner: task, now: now)
    let id = try #require(started)
    #expect(value.registry.sessions[id]?.request.mode == .battery)
    #expect(value.registry.sessions[id]?.request.batteryFloor == 35)
    #expect(value.registry.sessions[id]?.authorizedDuration == 60)
    let power = PowerSnapshot(
        source: .battery, battery: .available(percent: 35, isDischarging: true))
    #expect(value.evaluate(power: power, now: now).stopped[id] == .batteryFloor)
    #expect(throws: ServiceError.ownerExpired) {
        try value.apply(.startAgent(.other), owner: task, now: now)
    }
}

@Test func thermalCutoffEndsTrackedWorkAndReportsItsReason() throws {
    var (value, app, task) = try service()
    let now = try serviceClock(0)
    let power = PowerSnapshot(source: .external, battery: .notPresent)
    _ = try value.apply(.configure(try UserPolicy(allowsAutomation: true)), owner: app, now: now)
    let started = try value.apply(.startAgent(.codex), owner: task, now: now)
    let id = try #require(started)
    let serious = value.evaluate(power: power, now: now, thermal: .serious)
    #expect(serious.eligible == [id])
    #expect(value.summaries(for: app, evaluation: serious, now: now).first?.agent == .codex)
    let critical = value.evaluate(power: power, now: now, thermal: .critical)
    #expect(!critical.wantsAwake && critical.stopped[id] == .thermalCritical)
    #expect(value.registry.recentEndings.last?.reason == .thermalCritical)
    #expect(!value.evaluate(power: power, now: now, thermal: .nominal).wantsAwake)
    #expect(throws: ServiceError.ownerExpired) {
        try value.apply(.startAgent(.codex), owner: task, now: now)
    }
}

@Test func expiredLeaseCannotBeRenewedOrResurrectWork() throws {
    var (value, app, _) = try service()
    _ = try value.apply(.configure(try UserPolicy()), owner: app, now: serviceClock(0))
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
    let now = try serviceClock(0)
    let second = UUID()
    try value.connect(owner: second, user: 501, role: .task, now: now)
    let remaining = try value.apply(.start(.init()), owner: second, now: now)
    _ = try value.apply(.start(.init()), owner: task, now: now)
    value.disconnect(task)
    #expect(value.registry.sessions.count == 1)
    #expect(value.registry.sessions.values.first?.id == remaining)
    #expect(throws: ServiceError.ownerExpired) {
        try value.apply(.start(.init()), owner: task, now: serviceClock(1))
    }
}

@Test func globalStopWithdrawsAutomationEvenAfterManualProtectionTookPriority() throws {
    var (value, app, task) = try service()
    let now = try serviceClock(0)
    _ = try value.apply(.configure(try UserPolicy(allowsAutomation: true)), owner: app, now: now)
    _ = try value.apply(.start(.init()), owner: task, now: now)
    _ = try value.apply(.start(.init()), owner: app, now: now)
    _ = try value.apply(.stopAll, owner: app, now: now)
    #expect(value.registry.sessions.isEmpty && !value.registry.policy.allowsAutomation)
    let replacement = UUID()
    try value.connect(owner: replacement, user: 501, role: .task, now: now)
    #expect(throws: PolicyError.automationNotAuthorized) {
        try value.apply(.start(.init()), owner: replacement, now: now)
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
    for _ in 0..<ServiceSessions.taskClientCapacity {
        try value.connect(owner: UUID(), user: 501, role: .task, now: serviceClock(0))
    }
    #expect(throws: ServiceError.capacityReached) {
        try value.connect(owner: UUID(), user: 501, role: .task, now: serviceClock(0))
    }
    #expect(
        try value.expire(now: serviceClock(30), consoleUser: 501).count
            == ServiceSessions.taskClientCapacity)
    try value.connect(owner: UUID(), user: 501, role: .task, now: serviceClock(30))
}

@Test func transportRejectsOversizeMalformedUnknownVersionsAndInvalidPolicy() throws {
    for data in [
        Data(), Data("{}".utf8), Data(repeating: 32, count: ServiceWire.maximumMessageBytes + 1),
        Data(
            #"{"version":\#(ServiceWire.version),"operation":{"configure":{"_0":{"mode":"all","batteryFloor":81,"allowsAutomation":true}}}}"#
                .utf8),
    ] {
        #expect(throws: ServiceError.invalidMessage) { try ServiceWire.decodeRequest(data) }
    }
    #expect(throws: ServiceError.incompatibleVersion) {
        try ServiceWire.decodeRequest(Data(#"{"version":1,"operation":{"status":{}}}"#.utf8))
    }
    #expect(throws: ServiceError.incompatibleVersion) {
        try ServiceWire.decodeRequest(
            Data(#"{"version":5,"operation":{"setSudoTouchID":{"_0":false}}}"#.utf8))
    }
    #expect(throws: ServiceError.incompatibleVersion) {
        try ServiceWire.decodeRequest(Data(#"{"version":8,"operation":{"status":{}}}"#.utf8))
    }
    #expect(throws: ServiceError.incompatibleVersion) {
        try ServiceWire.decodeRequest(Data(#"{"version":10,"operation":{"status":{}}}"#.utf8))
    }
    #expect(throws: ServiceError.incompatibleVersion) {
        try ServiceWire.decodeRequest(Data(#"{"version":11,"operation":{"startAgent":{}}}"#.utf8))
    }
    #expect(throws: ServiceError.incompatibleVersion) {
        try ServiceWire.decodeReply(Data(#"{"version":11,"status":{}}"#.utf8))
    }
    for operation in [
        ServiceOperation.status, .heartbeat, .stop(UUID()), .extend(UUID()), .rearm,
        .retryRestoration,
        .stopAll, .prepareRemoval, .prepareUpdate, .cancelUpdate, .finishRemoval,
        .configure(try UserPolicy(batteryFloor: 80)),
        .restorePolicy,
        .start(SessionRequest(end: .after(seconds: 60))), .startAgent(.codex),
        .setSudoTouchID(true), .setAutomation(true),
    ] {
        #expect(
            try ServiceWire.decodeRequest(ServiceWire.encode(ServiceRequest(operation))).operation
                == operation)
    }
}

@Test(arguments: [false, true])
func unfinishedRemovalReopensAdmissionWithoutRevivingWork(_ switchUser: Bool) throws {
    var (value, app, task) = try service()
    let now = try serviceClock(0)
    let policy = try UserPolicy(batteryFloor: 40, allowsAutomation: true)
    _ = try value.apply(.configure(policy), owner: app, now: now)
    _ = try value.apply(.start(SessionRequest()), owner: task, now: now)
    _ = try value.apply(.prepareRemoval, owner: app, now: now)
    #expect(value.isPreparingRemoval && value.registry.sessions.isEmpty)
    if switchUser {
        try value.expire(now: now, consoleUser: 502)
        app = UUID()
        try value.connect(owner: app, user: 502, role: .application, now: now)
        _ = try value.apply(.restorePolicy, owner: app, now: now, savedPolicy: policy)
    } else {
        value.cancelRemovalPreparation()
    }
    #expect(!value.isRemoving && !value.isUninstalling)
    #expect(!value.registry.policy.allowsAutomation && value.registry.policy.batteryFloor == 40)
    #expect(value.registry.sessions.isEmpty)
    #expect(throws: ServiceError.restorationRequired) {
        try value.apply(.finishRemoval, owner: app, now: now)
    }
    let started = try value.apply(.start(SessionRequest()), owner: app, now: now)
    #expect(started != nil)
}

@Test func committedRemovalRevokesWorkAndCannotBeUndoneByAnotherClientOrConsoleChange() throws {
    var (value, app, task) = try service()
    let now = try serviceClock(0)
    #expect(throws: ServiceError.restorationRequired) {
        try value.apply(.finishRemoval, owner: app, now: now)
    }
    _ = try value.apply(.configure(try UserPolicy(allowsAutomation: true)), owner: app, now: now)
    _ = try value.apply(.start(SessionRequest()), owner: task, now: now)
    _ = try value.apply(.start(SessionRequest()), owner: app, now: now)
    _ = try value.apply(.prepareRemoval, owner: app, now: now)
    #expect(value.isRemoving && value.registry.sessions.isEmpty)
    _ = try value.apply(.finishRemoval, owner: app, now: now)
    try value.commitRemoval()
    value.cancelRemovalPreparation()
    #expect(value.isRemoving)
    #expect(!value.registry.policy.allowsAutomation)
    for operation in [
        ServiceOperation.configure(try UserPolicy(allowsAutomation: true)),
        .start(SessionRequest()), .extend(UUID()), .rearm, .setSudoTouchID(true),
        .setSudoTouchID(false),
    ] {
        #expect(throws: ServiceError.removalInProgress) {
            try value.apply(operation, owner: app, now: now)
        }
    }
    _ = try value.apply(.heartbeat, owner: task, now: now)
    _ = try value.apply(.prepareRemoval, owner: app, now: now)
    _ = try value.expire(now: serviceClock(1), consoleUser: 502)
    let next = UUID()
    try value.connect(owner: next, user: 502, role: .application, now: serviceClock(1))
    #expect(throws: ServiceError.removalInProgress) {
        try value.apply(.start(SessionRequest()), owner: next, now: serviceClock(1))
    }
    _ = try value.apply(.retryRestoration, owner: next, now: serviceClock(1))
    #expect(value.registry.sessions.isEmpty)
}

@Test func updateWaitsForAllSessionsAndAtomicallyClosesNewAdmission() throws {
    var (value, app, task) = try service()
    let now = try serviceClock(0)
    _ = try value.apply(.configure(try UserPolicy(allowsAutomation: true)), owner: app, now: now)
    _ = try value.apply(.start(SessionRequest()), owner: task, now: now)
    let second = UUID()
    try value.connect(owner: second, user: 501, role: .task, now: now)
    _ = try value.apply(.start(SessionRequest()), owner: second, now: now)
    #expect(throws: ServiceError.sessionRejected) {
        try value.apply(.prepareUpdate, owner: app, now: now)
    }
    #expect(value.registry.sessions.count == 2 && !value.isRemoving)
    _ = try value.apply(.stopAll, owner: app, now: now)
    _ = try value.apply(.prepareUpdate, owner: app, now: now)
    #expect(value.isPreparingUpdate && !value.registry.policy.allowsAutomation)
    #expect(throws: ServiceError.removalInProgress) {
        try value.apply(.start(SessionRequest()), owner: app, now: now)
    }
}

@Test func cancellingAnUpdateReopensAdmissionOnlyForTheSameConsoleUserBeforeCommit() throws {
    var (value, app, _) = try service()
    let now = try serviceClock(0)
    let policy = try UserPolicy(batteryFloor: 70, allowsAutomation: true)
    _ = try value.apply(.configure(policy), owner: app, now: now)
    _ = try value.apply(.prepareUpdate, owner: app, now: now)
    value.disconnect(app)
    let reconnected = UUID()
    try value.connect(owner: reconnected, user: 501, role: .application, now: now)
    _ = try value.apply(.cancelUpdate, owner: reconnected, now: now)
    #expect(!value.isRemoving && value.registry.policy == policy)
    _ = try value.apply(.prepareUpdate, owner: reconnected, now: now)
    try value.expire(now: now, consoleUser: 502)
    let other = UUID()
    try value.connect(owner: other, user: 502, role: .application, now: now)
    #expect(!value.isRemoving && !value.policyConfigured)
    #expect(throws: ServiceError.removalInProgress) {
        try value.apply(.cancelUpdate, owner: other, now: now)
    }
    try value.expire(now: now, consoleUser: 501)
    try value.connect(owner: reconnected, user: 501, role: .application, now: now)
    _ = try value.apply(.prepareUpdate, owner: reconnected, now: now)
    _ = try value.apply(.finishRemoval, owner: reconnected, now: now)
    try value.commitRemoval()
    #expect(value.isRemoving && !value.isPreparingUpdate)
    #expect(throws: ServiceError.removalInProgress) {
        try value.apply(.cancelUpdate, owner: reconnected, now: now)
    }
    _ = try value.apply(.prepareUpdate, owner: reconnected, now: now)
    #expect(value.isRemoving && !value.isPreparingUpdate)
    _ = try value.apply(.finishRemoval, owner: reconnected, now: now)
}
@Test func removalNeedsAnExplicitDrainAndConfirmedRestoration() throws {
    let reports: [(SleepPhase, SleepObservation, Bool, Bool)] = [
        (.inactive, .allowed, false, true), (.blocked, .allowed, false, true),
        (.restoring, .allowed, true, false), (.inactive, .unknown, false, false),
        (.inactive, .disabled, false, false), (.active, .allowed, false, false),
    ]
    for (phase, observed, owned, expected) in reports {
        for removal in [RemovalState.none, .preparing, .ready] {
            let value = ServiceStatus(
                policy: try UserPolicy(),
                power: PowerSnapshot(source: .unknown, battery: .unavailable),
                sleep: SleepReport(
                    phase: phase, observed: observed, ownsGlobalHold: owned, fault: nil),
                sessions: [], sampledAt: Date(), removal: removal)
            #expect(value.canRemoveService == (expected && removal != .none))
        }
    }
    let withWork = ServiceStatus(
        policy: try UserPolicy(), power: PowerSnapshot(source: .unknown, battery: .unavailable),
        sleep: SleepReport(phase: .inactive, observed: .allowed, ownsGlobalHold: false, fault: nil),
        sessions: [
            SessionSummary(
                id: UUID(), kind: .task, end: .unlimited, startedAt: Date(), remainingSeconds: nil,
                suspension: .powerSource, belongsToClient: false)
        ],
        sampledAt: Date(), removal: .preparing)
    #expect(!withWork.canRemoveService)
}

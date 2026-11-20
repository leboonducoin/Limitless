import Foundation
import LimitlessCore
import Testing

@testable import LimitlessApp

private func protection(
    _ id: UUID?, _ times: [TimeInterval?], phase: SleepPhase = .active
) throws -> ServiceStatus {
    let now = Date()
    return ServiceStatus(
        policy: try UserPolicy(), power: .init(source: .external, battery: .notPresent),
        sleep: .init(
            phase: phase, observed: phase == .active ? .disabled : .allowed,
            ownsGlobalHold: phase == .active, fault: nil),
        sessions: times.map { remaining in
            SessionSummary(
                id: UUID(), kind: .task, end: .unlimited, startedAt: now,
                remainingSeconds: remaining, suspension: nil, belongsToClient: false)
        }, sampledAt: now, protectionID: id)
}

@Test func reminderFollowsTheSharedDeadlineAndCanBeRearmedByAnExtension() throws {
    var notices = SessionNotices()
    let id = UUID()
    let before = try protection(id, [60, 301])
    #expect(before.protectionRemainingSeconds == 301)
    let cases = [
        (before, false), (try protection(id, [30, 300]), true),
        (try protection(id, [290]), false), (try protection(id, [900]), false),
        (try protection(id, [300]), true), (try protection(UUID(), [300]), true),
    ]
    for (status, expected) in cases {
        let shouldRemind = notices.shouldRemind(status)
        #expect(shouldRemind == expected)
    }
}

@Test func unboundedExpiredAndUnobservedProtectionDoNotSendAReminder() throws {
    var notices = SessionNotices()
    let id = UUID()
    for status in [
        try protection(id, [10, nil]), try protection(id, [0]),
        try protection(id, [10], phase: .recovering), try protection(nil, []),
    ] {
        let shouldRemind = notices.shouldRemind(status)
        #expect(!shouldRemind)
    }
    let shouldRemind = notices.shouldRemind(try protection(id, [10]))
    #expect(shouldRemind)
}

@Test @MainActor func iconPreferenceHidesOnlyTheMenuBarTime() throws {
    let domain = "Limitless.menu-style-test.\(UUID())"
    let preferences = try #require(UserDefaults(suiteName: domain))
    defer { preferences.removePersistentDomain(forName: domain) }
    let model = AppModel(preferences: preferences)
    try model.accept(ServiceReply(status: protection(UUID(), [60, 120])))
    model.menuBarStyle = .timer
    #expect(model.menuBarDeadline != nil)
    model.menuBarStyle = .icon
    #expect(model.menuBarDeadline == nil && model.protectionRemainingSeconds != nil)
    #expect(AppModel(preferences: preferences).menuBarStyle == .icon)
}

@Test func lidMuteRequiresOptInActiveProtectionAndNoExternalDisplay() {
    for state in [LidDisplayState.open, .closedWithDisplay, .unknown] {
        #expect(
            !state.shouldMuteAudio(
                active: true, screenAsleep: false, muteOnSleep: false, muteOnLidClose: true))
    }
    #expect(
        LidDisplayState.closedHeadless.shouldMuteAudio(
            active: true, screenAsleep: false, muteOnSleep: false, muteOnLidClose: true))
    #expect(
        !LidDisplayState.closedHeadless.shouldMuteAudio(
            active: true, screenAsleep: false, muteOnSleep: false, muteOnLidClose: false))
    #expect(
        !LidDisplayState.closedHeadless.shouldMuteAudio(
            active: false, screenAsleep: true, muteOnSleep: true, muteOnLidClose: true))
    #expect(
        LidDisplayState.closedWithDisplay.shouldMuteAudio(
            active: true, screenAsleep: true, muteOnSleep: true, muteOnLidClose: false))
}

private actor AssociationPermission {
    private var decisions: [Bool]
    init(_ decisions: [Bool]) { self.decisions = decisions }
    func next() -> Bool { decisions.isEmpty ? false : decisions.removeFirst() }
}

@Test func hotspotRechecksTheAuthenticatedSessionAfterScanning() async throws {
    let permission = AssociationPermission([true, false])
    var scanned = false
    var associated = false
    let result = try await HotspotFallback.associateIfCurrent(
        canJoin: { await permission.next() },
        scan: {
            scanned = true
            return { associated = true }
        })
    #expect(result == .cancelled && scanned && !associated)
}

@Test func hotspotRejectsMissingMatchAndAssociatesOnlyWithTwoAuthorizations() async throws {
    let noMatch = try await HotspotFallback.associateIfCurrent(canJoin: { true }, scan: { nil })
    #expect(noMatch == .noMatch)
    let permission = AssociationPermission([true, true])
    var associations = 0
    let result = try await HotspotFallback.associateIfCurrent(
        canJoin: { await permission.next() }, scan: { { associations += 1 } })
    #expect(result == .joined && associations == 1)
}

@Test func hotspotSkipsScanningWhenProtectionIsAlreadyUnavailable() async throws {
    var scanned = false
    let result = try await HotspotFallback.associateIfCurrent(
        canJoin: { false },
        scan: {
            scanned = true
            return nil
        })
    #expect(result == .cancelled && !scanned)
}

@MainActor private final class FakeAudioOutput: SessionAudioOutput {
    var ids: [UInt32: String] = [1: "built-in"]
    var values: [UInt32: UInt32] = [1: 0]
    var selected: UInt32? = 1
    var supportsWrites = true
    var writes: [UInt32] = []

    func defaultOutput() -> UInt32? { selected }
    func uid(of device: UInt32) -> String? { ids[device] }
    func findOutput(uid: String) -> UInt32? { ids.first { $0.value == uid }?.key }
    func mute(of device: UInt32) -> UInt32? { values[device] }
    func canSetMute(on device: UInt32) -> Bool { supportsWrites }
    func setMute(_ value: UInt32, device: UInt32, uid: String) -> Bool {
        guard supportsWrites, ids[device] == uid else { return false }
        writes.append(value)
        return true
    }
}

@Test @MainActor func audioProvesDelayedMuteAndRestoreOnTheSameOutput() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let journal = root.appendingPathComponent("mute.json")
    let output = FakeAudioOutput()
    var audio = SessionAudioMute(journal: journal, output: output)
    let now = ContinuousClock.now
    #expect(audio.update(shouldMute: true, now: now) == nil)
    #expect(output.writes == [1])
    #expect(FileManager.default.fileExists(atPath: journal.path))
    #expect(audio.update(shouldMute: false, now: now + .seconds(1)) != nil)
    #expect(output.writes == [1])
    output.values[1] = 1
    #expect(audio.update(shouldMute: false, now: now + .seconds(2)) != nil)
    #expect(output.writes == [1, 0])
    output.values[1] = 0
    #expect(audio.update(shouldMute: false, now: now + .seconds(3)) == nil)
    #expect(!FileManager.default.fileExists(atPath: journal.path))
}

@Test @MainActor func audioLeavesPreMutedAndUnsupportedOutputsAlone() {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let journal = root.appendingPathComponent("mute.json")
    let output = FakeAudioOutput()
    output.values[1] = 1
    var audio = SessionAudioMute(journal: journal, output: output)
    #expect(audio.update(shouldMute: true) == nil)
    #expect(audio.update(shouldMute: false) == nil)
    output.values[1] = 0
    output.supportsWrites = false
    #expect(audio.update(shouldMute: true) != nil)
    #expect(output.writes.isEmpty && !FileManager.default.fileExists(atPath: journal.path))
}

@Test @MainActor func interruptedAudioWriteNeverUnmutesWithoutConfirmation() {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let journal = root.appendingPathComponent("mute.json")
    let output = FakeAudioOutput()
    var first = SessionAudioMute(journal: journal, output: output)
    _ = first.update(shouldMute: true)
    output.values[1] = 1
    var restarted = SessionAudioMute(journal: journal, output: output)
    #expect(restarted.update(shouldMute: false) != nil)
    #expect(output.writes == [1])
    #expect(FileManager.default.fileExists(atPath: journal.path))
}

@Test @MainActor func confirmedAudioRestoreWaitsForTheOriginalOutputUID() {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let journal = root.appendingPathComponent("mute.json")
    let output = FakeAudioOutput()
    var first = SessionAudioMute(journal: journal, output: output)
    _ = first.update(shouldMute: true)
    output.values[1] = 1
    _ = first.update(shouldMute: true)
    output.ids[1] = "other-output"
    var restarted = SessionAudioMute(journal: journal, output: output)
    #expect(restarted.update(shouldMute: false) != nil)
    #expect(output.writes == [1])
    output.ids[2] = "built-in"
    output.values[2] = 1
    #expect(restarted.update(shouldMute: false) != nil)
    #expect(output.writes == [1, 0])
    output.values[2] = 0
    #expect(restarted.update(shouldMute: false) == nil)
    #expect(!FileManager.default.fileExists(atPath: journal.path))
}

@Test @MainActor func anObservedManualAudioOverrideIsHonoredUntilWake() {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let journal = root.appendingPathComponent("mute.json")
    let output = FakeAudioOutput()
    var audio = SessionAudioMute(journal: journal, output: output)
    _ = audio.update(shouldMute: true)
    output.values[1] = 1
    #expect(audio.update(shouldMute: true) == nil)
    output.values[1] = 0
    #expect(audio.update(shouldMute: true) == nil)
    #expect(audio.update(shouldMute: true) == nil)
    #expect(output.writes == [1])
    _ = audio.update(shouldMute: false)
    _ = audio.update(shouldMute: true)
    #expect(output.writes == [1, 1])
}

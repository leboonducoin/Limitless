import Foundation
import LimitlessCore
import Testing

@testable import LimitlessApp

@Test func durationPresetsMatchTheCompactMenu() {
    #expect(SessionEnd.presetMinutes == [15, 30, 45, 60, 120, 240, 480, 720, 1440])
}

@Test @MainActor func uninstallErasesAllPreferencesAndOnlyItsOwnCacheAndWindowState() throws {
    let domain = "Limitless.test.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: domain))
    let library = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {
        defaults.removePersistentDomain(forName: domain)
        try? FileManager.default.removeItem(at: library)
    }
    defaults.set("saved", forKey: "userPolicy")
    defaults.set(true, forKey: "anotherPreference")
    for path in [
        "Caches/\(domain)", "Saved Application State/\(domain).savedState", "Caches/other-app",
    ] {
        try FileManager.default.createDirectory(
            at: library.appendingPathComponent(path), withIntermediateDirectories: true)
    }
    try AppModel.erasePreferences(defaults, domain: domain, library: library)
    #expect(defaults.persistentDomain(forName: domain)?.isEmpty != false)
    #expect(
        !FileManager.default.fileExists(
            atPath: library.appendingPathComponent("Caches/\(domain)").path))
    #expect(
        !FileManager.default.fileExists(
            atPath: library.appendingPathComponent("Saved Application State/\(domain).savedState")
                .path))
    #expect(
        FileManager.default.fileExists(
            atPath: library.appendingPathComponent("Caches/other-app").path))
    try AppModel.erasePreferences(defaults, domain: domain, library: library)
}

private func status(
    _ phase: SleepPhase, observed: SleepObservation, owned: Bool,
    fault: SleepFault? = nil
) throws -> ServiceStatus {
    ServiceStatus(
        policy: try UserPolicy(), power: PowerSnapshot(source: .unknown, battery: .unavailable),
        sleep: SleepReport(phase: phase, observed: observed, ownsGlobalHold: owned, fault: fault),
        sessions: [], sampledAt: Date())
}

@Test func unverifiedOrForeignStateNeverLooksInactiveOrSuccessfullyActive() throws {
    #expect(PowerPresentation(try status(.inactive, observed: .unknown, owned: false)) == .unknown)
    #expect(
        PowerPresentation(try status(.inactive, observed: .disabled, owned: false)) == .attention)
    #expect(PowerPresentation(try status(.active, observed: .disabled, owned: false)) == .attention)
    #expect(
        PowerPresentation(
            try status(.restoring, observed: .disabled, owned: true, fault: .restorationFailed))
            == .restoring)
    #expect(PowerPresentation(try status(.active, observed: .disabled, owned: true)) == .active)
    #expect(PowerPresentation(try status(.inactive, observed: .allowed, owned: false)) == .inactive)
}

@Test func preferenceDraftNeverPersistsAutomationOrAcceptsInvalidLimits() throws {
    var draft = PolicyDraft(
        try UserPolicy(
            mode: .external, batteryFloor: 35,
            maximumDuration: 7_200, allowsAutomation: true))
    #expect(try draft.policy(allowsAutomation: false).allowsAutomation == false)
    #expect(try draft.policy(allowsAutomation: false).maximumDuration == 7_200)
    draft.maximumMinutes = .infinity
    #expect(throws: PolicyError.invalidDuration) { try draft.policy(allowsAutomation: false) }
    draft.limitsDuration = false
    draft.batteryFloor = 51
    #expect(throws: PolicyError.invalidBatteryFloor) { try draft.policy(allowsAutomation: false) }
}

#if DEBUG
    @Test @MainActor func emptyTaskCountOnlyAppearsForProcessCompletion() {
        let model = AppModel.preview("inactive")
        #expect(model.taskCount == 0 && !model.showsTaskCount)
        model.stopChoice = .process
        #expect(model.showsTaskCount)
        model.stopChoice = .unlimited
        #expect(!model.showsTaskCount)
    }

    @Test @MainActor func startupNeverGrantsControlBeforeBuildVerification() async {
        let model = AppModel()
        #expect(model.buildTrust == .checking)
        #expect(!model.trustedBuild && !model.canControl)
        await model.prepareForLaunch()
        #expect(model.buildTrust == .untrusted)
        #expect(!model.trustedBuild && !model.canControl)
        #expect(model.status == nil && !model.removalComplete)
    }

    @Test @MainActor func previewCannotControlPowerOrAuthorizeAutomation() async {
        let model = AppModel.preview("active")
        let before = model.status
        #expect(model.isPreview && !model.canControl)
        await model.prepareForLaunch()
        #expect(model.buildTrust == .untrusted)
        await model.stopAll()
        await model.setAutomation(false)
        await model.registerHelper()
        await model.setLaunchAtLogin(true)
        #expect(await model.removeIntegration() == false)
        #expect(!model.removalComplete)
        #expect(model.status == before)
        #expect(model.loginStatus == .notRegistered)
    }
#endif

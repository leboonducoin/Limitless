import Foundation
import LimitlessCore
import LimitlessSystem
import Testing

@testable import LimitlessApp

@Test func durationPresetsMatchTheCompactMenu() {
    #expect(SessionEnd.presetMinutes == [15, 30, 45, 60, 120, 240, 480, 720, 1440])
}

@Test func multipleProcessIDsAreValidatedAndDeduplicated() throws {
    #expect(try ProcessSelection.parse("697;660;9931") == [697, 660, 9931])
    #expect(try ProcessSelection.parse(" 697 ; 660 ;697 ") == [697, 660])
    for invalid in ["", "0", "-2", "+12", "12;", ";12", "12;;34", "1,2", "12;word", "2147483648"] {
        #expect(throws: WorkError.invalidProcess) { try ProcessSelection.parse(invalid) }
    }
    #expect(throws: WorkError.invalidProcess) {
        try ProcessSelection.parse(Array(repeating: "12", count: 129).joined(separator: ";"))
    }
}

@Test @MainActor func processMonitoringWaitsUntilEverySelectedProcessHasEnded() throws {
    let first = Process()
    let second = Process()
    defer {
        for child in [first, second] where child.isRunning {
            child.terminate()
            child.waitUntilExit()
        }
    }
    for child in [first, second] {
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["60"]
        try child.run()
    }
    var followed = try [first, second].map { try ProcessIdentity(pid: $0.processIdentifier) }
    #if DEBUG
        let model = AppModel.preview("active", watchedProcesses: followed)
        #expect(model.taskCount == 2 && model.showsTaskCount)
        #expect(!model.pollWatchedProcesses())
        #expect(model.watchedProcesses?.map(\.pid) == followed.map(\.pid))
    #endif
    #expect(!ProcessSelection.allFinished(&followed))
    first.terminate()
    first.waitUntilExit()
    #expect(!ProcessSelection.allFinished(&followed) && followed.count == 1)
    #if DEBUG
        #expect(!model.pollWatchedProcesses())
        #expect(model.taskCount == 1)
        #expect(model.watchedProcesses?.map(\.pid) == [second.processIdentifier])
    #endif
    second.terminate()
    second.waitUntilExit()
    #expect(ProcessSelection.allFinished(&followed))
    #if DEBUG
        #expect(model.pollWatchedProcesses())
        #expect(model.taskCount == 0 && model.watchedProcesses?.isEmpty == true)
    #endif
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
    @Test @MainActor func setupHidesPowerControlsUntilTheHelperIsAvailable() {
        #expect(!AppModel().showsPowerControls)
        for state in ["setup", "removed"] {
            let model = AppModel.preview(state)
            #expect(!model.showsPowerControls && !model.canControl)
            #expect(model.trustedBuild)
        }
        #expect(AppModel.preview("inactive").showsPowerControls)
    }

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
        model.draft.batteryFloor = 42
        model.policyEdited()
        await model.checkForUpdates()
        await model.installUpdate()
        #expect(model.availableUpdate == nil && !model.updating)
        #expect(await model.removeIntegration() == false)
        #expect(!model.removalComplete)
        #expect(model.status == before)
        #expect(model.loginStatus == .notRegistered)
    }
#endif

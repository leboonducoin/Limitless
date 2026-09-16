import Foundation
import LimitlessCore
import Testing

@testable import LimitlessApp

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
    @Test @MainActor func previewCannotControlPowerOrAuthorizeAutomation() async {
        let model = AppModel.preview("active")
        let before = model.status
        #expect(model.isPreview && !model.canControl)
        await model.stopAll()
        await model.setAutomation(false)
        await model.registerHelper()
        await model.setLaunchAtLogin(true)
        #expect(model.status == before)
        #expect(model.loginStatus == .notRegistered)
    }
#endif

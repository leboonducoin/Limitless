import AppKit
import Foundation
import LimitlessCore
import LimitlessSystem
import Observation
import ServiceManagement

@MainActor @Observable final class AppModel {
    enum BuildTrust { case checking, trusted, untrusted }

    private(set) var status: ServiceStatus?
    private(set) var busy = false
    private(set) var connectionError: String?
    private(set) var helperStatus: SMAppService.Status = .notRegistered
    private(set) var loginStatus: SMAppService.Status = .notRegistered
    private(set) var buildTrust = BuildTrust.checking
    var trustedBuild: Bool { buildTrust == .trusted }
    private(set) var removalComplete = false
    var message: String?
    var draft = PolicyDraft()
    var stopChoice: StopChoice = .preset(60)
    var customDuration: Double = 90
    var durationUnit: DurationUnit = .minutes
    var stopDate = Date().addingTimeInterval(3_600)
    var processID = ""
    var confirmingRemoval = false
    var erasePreferencesOnRemoval = false
    private let preferences: UserDefaults
    private let helper: (any HelperInstallation)? =
        (Bundle.main.object(forInfoDictionaryKey: "LimitlessHelperInstallation") as? String)
        .flatMap(HelperInstallationKind.init(rawValue:))?.service
    private var client: ServiceClient?
    private var monitoring: Task<Void, Never>?
    private var watchedProcess: ProcessIdentity?
    private var refreshing = false
    private var revision = 0
    private var quitting = false
    private var baseline = PolicyDraft()
    private(set) var isPreview = false

    init(preferences: UserDefaults = .standard) {
        self.preferences = preferences
        if let data = preferences.data(forKey: "userPolicy"),
            let policy = try? JSONDecoder().decode(UserPolicy.self, from: data)
        {
            draft = PolicyDraft(policy)
            baseline = draft
        }
    }

    func prepareForLaunch() async {
        guard !isPreview, buildTrust == .checking else { return }
        guard helper != nil else {
            buildTrust = .untrusted
            return
        }
        let identity = try? await SignedIdentity.current(
            expectedIdentifier: LimitlessIdentity.application)
        buildTrust = identity == nil ? .untrusted : .trusted
    }

    var canControl: Bool {
        trustedBuild && !isPreview && helperStatus == .enabled && client != nil
            && connectionError == nil && !removalInProgress && !removalComplete
    }
    var removalInProgress: Bool { status.map { $0.removal != .none } ?? false }
    var ownSession: SessionSummary? {
        status?.sessions.first(where: { $0.belongsToClient && $0.kind == .manual })
    }
    var taskCount: Int { status?.sessions.filter { $0.kind == .task }.count ?? 0 }
    var presentation: PowerPresentation? {
        connectionError == nil ? status.map(PowerPresentation.init) : nil
    }
    var draftChanged: Bool { draft != baseline }

    func beginMonitoring() {
        guard monitoring == nil, !isPreview, !quitting else { return }
        monitoring = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                guard let self else { return }
                if !quitting {
                    if let watchedProcess, !watchedProcess.isAlive, ownSession != nil, !busy {
                        await stopManual()
                        message = "The followed process ended or became unreadable."
                    }
                    if tick % 5 == 0 { await refresh() }
                }
                tick &+= 1
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }

    func refresh() async {
        guard !isPreview, !busy, !refreshing, !quitting else { return }
        helperStatus = helper?.status ?? .notFound
        loginStatus = SMAppService.mainApp.status
        guard trustedBuild, helperStatus == .enabled else {
            if status != nil {
                connectionError =
                    "The helper is unavailable. The last power reading is no longer current."
            }
            await client?.close()
            client = nil
            watchedProcess = nil
            return
        }
        refreshing = true
        defer { refreshing = false }
        let currentRevision = revision
        do {
            if client == nil {
                let connected = try await ServiceClient(role: .application)
                guard currentRevision == revision, !quitting else {
                    await connected.close()
                    return
                }
                client = connected
            }
            guard let client else { return }
            let reply = try await client.send(.status)
            guard currentRevision == revision else { return }
            try accept(reply)
            connectionError = nil
        } catch {
            guard currentRevision == revision else { return }
            connectionError =
                "Connection unavailable. The last reading is no longer current. Reconnect to verify restoration."
            await client?.close()
            client = nil
            watchedProcess = nil
        }
    }

    private func accept(_ reply: ServiceReply) throws {
        guard let received = reply.status else { throw ServiceError.unavailable }
        if !draftChanged { draft = PolicyDraft(received.policy) }
        baseline = PolicyDraft(received.policy)
        status = received
        if ownSession == nil { watchedProcess = nil }
    }

    private func perform(_ operation: ServiceOperation) async -> Bool {
        guard canControl, !busy, let client else { return false }
        busy = true
        revision &+= 1
        message = nil
        defer { busy = false }
        do {
            try accept(await client.send(operation))
            return true
        } catch {
            message =
                "The request was not confirmed. Check the current state and your limits before retrying."
            if let reply = try? await client.send(.status) {
                try? accept(reply)
            } else {
                connectionError = "Connection lost. Power restoration has not been confirmed."
                await client.close()
                self.client = nil
                watchedProcess = nil
            }
            return false
        }
    }

    func startManual() async {
        do {
            let end: SessionEnd
            var process: ProcessIdentity?
            switch stopChoice {
            case .unlimited: end = .unlimited
            case .preset(let minutes): end = .after(seconds: Double(minutes) * 60)
            case .custom: end = .after(seconds: customDuration * durationUnit.seconds)
            case .date: end = .at(stopDate)
            case .process:
                guard let pid = Int32(processID) else { throw WorkError.invalidProcess }
                process = try ProcessIdentity(pid: pid)
                end = .unlimited
            }
            try end.validate(at: SystemClock.now())
            if await perform(.start(SessionRequest(end: end))), ownSession != nil {
                watchedProcess = process
            }
        } catch {
            message =
                "Choose a positive duration, a future date, or an available process owned by you."
        }
    }

    func stopManual() async {
        guard let session = ownSession else { return }
        if await perform(.stop(session.id)) { watchedProcess = nil }
    }

    func stopAll() async { _ = await perform(.stopAll) }
    func rearm() async { _ = await perform(.rearm) }
    func retryRestoration() async { _ = await perform(.retryRestoration) }

    func applyPolicy() async {
        do {
            let policy = try draft.policy(
                allowsAutomation: status?.policy.allowsAutomation ?? false)
            if await perform(.configure(policy)) {
                draft = PolicyDraft(status?.policy ?? policy)
                // Persist limits only, never automation authorization or an active demand.
                let saved = try draft.policy(allowsAutomation: false)
                preferences.set(try JSONEncoder().encode(saved), forKey: "userPolicy")
                message =
                    "Limits applied. Existing sessions remain bounded by their original deadlines."
            }
        } catch { message = "Use a battery floor from 0 to 50% and a positive, finite duration." }
    }

    func setAutomation(_ enabled: Bool) async {
        guard let policy = status?.policy else { return }
        do {
            let updated = try UserPolicy(
                mode: policy.mode, batteryFloor: policy.batteryFloor,
                maximumDuration: policy.maximumDuration, allowsAutomation: enabled)
            _ = await perform(.configure(updated))
        } catch { message = "The automation limits could not be validated." }
    }

    func registerHelper() async {
        guard trustedBuild, !isPreview, !busy, !removalComplete, let helper else { return }
        busy = true
        do { try await helper.register() } catch {
            message =
                "The helper could not be enabled. Complete the macOS approval before retrying."
        }
        helperStatus = helper.status
        busy = false
        await refresh()
    }

    func setLaunchAtLogin(_ enabled: Bool) async {
        guard trustedBuild, !isPreview, !busy, !removalComplete else { return }
        busy = true
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try await SMAppService.mainApp.unregister()
            }
        } catch {
            message = "The login setting could not be changed. Check Login Items & Extensions."
        }
        loginStatus = SMAppService.mainApp.status
        busy = false
    }

    func openLoginSettings() {
        guard !isPreview else { return }
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Shared by the native settings action and the signed app's Homebrew removal hook.
    /// No app files, external CLI links or user-created skill copies are deleted here.
    func removeIntegration(erasePreferences: Bool = false) async -> Bool {
        guard trustedBuild, !isPreview, !busy, let helper else {
            message = "Removal requires a correctly signed Limitless installation."
            return false
        }
        quitting = true
        busy = true
        revision &+= 1
        defer { busy = false }
        while refreshing { try? await Task.sleep(for: .milliseconds(50)) }
        do {
            helperStatus = helper.status
            let filesRemoved =
                try SecureOwnershipJournal.isStateDirectoryAbsent()
                && InstalledHelperFiles.areAbsent()
            if helperStatus == .enabled, !filesRemoved {
                if client == nil { client = try await ServiceClient(role: .application) }
                guard let client else { throw ServiceError.unavailable }
                try accept(await client.send(.prepareRemoval))
                guard let status, status.removal == .ready, status.canRemoveService,
                    try SecureOwnershipJournal.isStateDirectoryAbsent()
                else { throw ServiceError.restorationRequired }
                if try !InstalledHelperFiles.areAbsent() {
                    // Unlinking the executable can invalidate its XPC signature before a reply.
                    // Only proven file absence permits unregistration after this request.
                    _ = try? await client.send(.finishRemoval)
                }
            } else {
                guard try SecureOwnershipJournal.isStateDirectoryAbsent(),
                    try InstalledHelperFiles.areAbsent()
                else {
                    throw ServiceError.restorationRequired
                }
            }
            if helper.status != .notRegistered { try await helper.unregister() }
            guard helper.status == .notRegistered else { throw ServiceError.unavailable }
            await client?.close()
            client = nil
            // A login item never registered with ServiceManagement reports notFound.
            let absentLoginStates: [SMAppService.Status] = [.notRegistered, .notFound]
            if !absentLoginStates.contains(SMAppService.mainApp.status) {
                try await SMAppService.mainApp.unregister()
            }
            guard absentLoginStates.contains(SMAppService.mainApp.status),
                try SecureOwnershipJournal.isStateDirectoryAbsent(),
                try InstalledHelperFiles.areAbsent()
            else { throw ServiceError.restorationRequired }
            if erasePreferences {
                preferences.removePersistentDomain(forName: LimitlessIdentity.application)
            }
            helperStatus = helper.status
            loginStatus = SMAppService.mainApp.status
            status = nil
            watchedProcess = nil
            connectionError = nil
            removalComplete = true
            monitoring?.cancel()
            message =
                "The power helper and login item are removed. Quit Limitless, then use Homebrew or move the app to the Trash."
            return true
        } catch {
            quitting = false
            await client?.close()
            client = nil
            connectionError =
                "Removal was not confirmed. Reconnect before trusting the current state."
            helperStatus = helper.status
            loginStatus = SMAppService.mainApp.status
            message =
                "Removal is incomplete. Keep the app installed and retry. If the helper is unavailable while its state directory remains, restore the signed installation and enable the helper before retrying."
            return false
        }
    }

    func prepareToQuit() async -> Bool {
        if isPreview { return true }
        quitting = true
        while busy || refreshing { try? await Task.sleep(for: .milliseconds(50)) }
        if ownSession != nil { await stopManual() }
        let unresolved =
            (status?.sleep.ownsGlobalHold == true)
            && (connectionError != nil || status?.sleep.fault != nil || ownSession != nil)
        if unresolved {
            quitting = false
            return false
        }
        monitoring?.cancel()
        await client?.close()
        return true
    }
}

#if DEBUG
    extension AppModel {
        /// Read-only presentation fixtures. Every mutation path still rejects isPreview.
        static func preview(_ state: String) -> AppModel {
            let model = AppModel()
            model.isPreview = true
            model.buildTrust = .untrusted
            model.helperStatus = .enabled
            let active = state == "active"
            let waiting = state == "suspended"
            let failed = state == "restoration"
            let unknown = state == "unknown"
            let policy = try! UserPolicy(mode: waiting ? .external : .all, allowsAutomation: true)
            let session = SessionSummary(
                id: UUID(), kind: .manual, end: .after(seconds: 3_600),
                startedAt: Date().addingTimeInterval(-900), remainingSeconds: 2_700,
                suspension: waiting ? .powerSource : nil, belongsToClient: true)
            model.status = ServiceStatus(
                policy: policy,
                power: PowerSnapshot(
                    source: .battery, battery: .available(percent: 76, isDischarging: true)),
                sleep: SleepReport(
                    phase: active ? .active : (failed ? .restoring : .inactive),
                    observed: unknown ? .unknown : (active || failed ? .disabled : .allowed),
                    ownsGlobalHold: active || failed, fault: failed ? .restorationFailed : nil),
                sessions: active || waiting ? [session] : [], sampledAt: Date())
            model.draft = PolicyDraft(policy)
            model.baseline = model.draft
            return model
        }
    }
#endif

import AppKit
import Foundation
import LimitlessCore
import LimitlessSystem
import LocalAuthentication
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
    private(set) var removalStep: String?
    private(set) var availableUpdate: GitHubUpdate.Release?
    private(set) var updating = false
    private(set) var updateMessage: String?
    private(set) var hasTouchID = false
    var automaticUpdates: Bool {
        didSet {
            guard !isPreview else { return }
            preferences.set(automaticUpdates, forKey: "automaticUpdates")
        }
    }
    var message: String?
    var pendingSudoTouchID: Bool?
    var draft = PolicyDraft()
    var stopChoice: StopChoice = .preset(60)
    var customDuration: Double = 90
    var durationUnit: DurationUnit = .minutes
    var stopDate = Date().addingTimeInterval(3_600)
    var processID = "" {
        didSet {
            let ids = Set(
                processID.split(separator: ";").compactMap {
                    Int32($0.trimmingCharacters(in: .whitespacesAndNewlines))
                })
            selectedProcesses = selectedProcesses.filter { ids.contains($0.key) }
        }
    }
    private(set) var processes: [RunningProcess] = []
    var processSearch = ""
    private(set) var processListError: String?
    private var selectedProcesses: [Int32: ProcessIdentity] = [:]
    private let preferences: UserDefaults
    private let helper: (any HelperInstallation)? =
        (Bundle.main.object(forInfoDictionaryKey: "LimitlessHelperInstallation") as? String)
        .flatMap(HelperInstallationKind.init(rawValue:))?.service
    private var client: ServiceClient?
    private var restoredAutomationPreference = false
    private var monitoring: Task<Void, Never>?
    private(set) var watchedProcesses: [ProcessIdentity]?
    private var policyApplication: Task<Void, Never>?
    private var updateMonitoring: Task<Void, Never>?
    private var updateInstallation: Task<Void, Never>?
    private var updateSchedule: UpdateSchedule {
        didSet {
            guard !isPreview, let data = try? JSONEncoder().encode(updateSchedule) else { return }
            preferences.set(data, forKey: "updateSchedule")
        }
    }
    private var statusReceivedAt = ContinuousClock.now
    private var refreshing = false
    private var revision = 0
    private var quitting = false
    private var baseline = PolicyDraft()
    private(set) var isPreview = false

    init(preferences: UserDefaults = .standard) {
        self.preferences = preferences
        let authentication = LAContext()
        hasTouchID =
            authentication.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            && authentication.biometryType == .touchID
        updateSchedule =
            preferences.data(forKey: "updateSchedule").flatMap {
                try? JSONDecoder().decode(UpdateSchedule.self, from: $0)
            } ?? UpdateSchedule()
        automaticUpdates = preferences.bool(forKey: "automaticUpdates")
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
    var showsPowerControls: Bool {
        canControl || (isPreview && helperStatus == .enabled && !removalComplete)
    }
    var showsPowerSource: Bool { showsPowerControls && status?.power.battery != .notPresent }
    var showsBatteryLimit: Bool { showsPowerSource && draft.mode != .external }
    var showsSudoTouchID: Bool {
        showsPowerControls
            && (hasTouchID || status?.sudoTouchID == .enabled || status?.sudoTouchID == .external)
    }
    var removalInProgress: Bool { status.map { $0.removal != .none } ?? false }
    var ownSession: SessionSummary? {
        status?.sessions.first(where: { $0.belongsToClient && $0.kind == .manual })
    }
    var taskCount: Int {
        (status?.sessions.filter { $0.kind != .manual }.count ?? 0)
            + (watchedProcesses?.count ?? 0)
    }
    var showsTaskCount: Bool { taskCount > 0 || stopChoice == .process }
    var presentation: PowerPresentation? {
        connectionError == nil ? status.map(PowerPresentation.init) : nil
    }
    var draftChanged: Bool { draft != baseline }
    private var readyToUpdate: Bool {
        guard connectionError == nil, !removalComplete else { return false }
        guard let status else { return helperStatus == .notRegistered }
        return status.sessions.isEmpty && !status.sleep.ownsGlobalHold
            && status.sleep.observed == .allowed
            && (status.sleep.phase == .inactive || status.sleep.phase == .blocked)
    }

    func remainingSeconds(_ session: SessionSummary) -> Double? {
        guard let remaining = session.remainingSeconds else { return nil }
        let elapsed = statusReceivedAt.duration(to: .now).components
        return max(
            0, ceil(remaining - Double(elapsed.seconds) - Double(elapsed.attoseconds) / 1e18))
    }

    func refreshProcesses() {
        do {
            processes = try RunningProcess.snapshot()
            processListError = nil
        } catch {
            processes = []
            processListError = "Processes unavailable. Enter a PID or refresh."
        }
    }

    func selectProcess(_ process: RunningProcess) {
        var ids = (try? ProcessSelection.parse(processID)) ?? []
        if ids.contains(process.id) {
            ids.removeAll { $0 == process.id }
        } else {
            ids.append(process.id)
        }
        processID = ids.map(String.init).joined(separator: ";")
        if ids.contains(process.id) { selectedProcesses[process.id] = process.identity }
    }

    func isSelected(_ process: RunningProcess) -> Bool {
        ((try? ProcessSelection.parse(processID)) ?? []).contains(process.id)
    }

    func pollWatchedProcesses() -> Bool {
        guard var followed = watchedProcesses else { return false }
        let completed = ProcessSelection.allFinished(&followed)
        if followed != watchedProcesses { watchedProcesses = followed }
        return completed
    }

    func beginMonitoring() {
        guard monitoring == nil, !isPreview, !quitting else { return }
        if trustedBuild {
            updateMonitoring = Task { [weak self] in
                while !Task.isCancelled {
                    await self?.checkForUpdates()
                    let delay = max(
                        60,
                        self?.updateSchedule.nextCheck.timeIntervalSinceNow
                            ?? UpdateSchedule.interval)
                    do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                }
            }
        }
        monitoring = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                guard let self else { return }
                if !quitting {
                    if pollWatchedProcesses(), ownSession != nil, !busy {
                        await stopManual()
                    }
                    if tick % 5 == 0 { await refresh() }
                    if automaticUpdates, availableUpdate != nil,
                        Date() >= updateSchedule.nextDownload, !busy, !updating,
                        readyToUpdate
                    {
                        requestUpdate()
                    }
                }
                tick &+= 1
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }

    func checkForUpdates() async {
        guard trustedBuild, !isPreview, !quitting, !updating,
            updateSchedule.beginCheck()
        else { return }
        do {
            availableUpdate = try await GitHubUpdate.latest(
                currentVersion: LimitlessIdentity.version)
            updateSchedule.checked()
        } catch UpdateError.rateLimited(let until) {
            updateSchedule.failed(download: false, retryAfter: until)
        } catch {
            updateSchedule.failed(download: false)
        }
    }

    func installUpdate() async {
        guard trustedBuild, !isPreview, !quitting, !updating, !busy,
            let availableUpdate
        else { return }
        guard readyToUpdate else {
            updateMessage = "Stop the current sessions before updating."
            return
        }
        guard updateSchedule.beginDownload() else {
            updateMessage = "Update postponed. Please try again later."
            return
        }
        updating = true
        updateMessage = "Downloading update…"
        var staged: GitHubUpdate.Staged?
        var launched = false
        defer {
            updating = false
            if !launched, let staged { try? FileManager.default.removeItem(at: staged.directory) }
        }
        do {
            let identity = try await SignedIdentity.current(
                expectedIdentifier: LimitlessIdentity.application)
            let candidate = try await GitHubUpdate.stage(
                availableUpdate, identity: identity, installedApp: Bundle.main.bundleURL)
            staged = candidate
            guard !quitting else { return }
            updateMessage = "Installing update…"
            guard await removeIntegration(forUpdate: true) else {
                updateMessage = message
                return
            }
            try GitHubUpdate.launchInstaller(candidate)
            launched = true
            NSApp.terminate(nil)
        } catch {
            if case UpdateError.rateLimited(let until) = error {
                updateSchedule.failed(download: true, retryAfter: until)
                updateMessage = "Update postponed. Please try again later."
            } else {
                updateSchedule.failed(download: true)
                updateMessage = error.localizedDescription
            }
            if removalComplete {
                quitting = false
                removalComplete = false
                monitoring = nil
                beginMonitoring()
            }
        }
    }

    func requestUpdate() {
        guard updateInstallation == nil else { return }
        updateInstallation = Task { [weak self] in
            await self?.installUpdate()
            self?.updateInstallation = nil
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
            watchedProcesses = nil
            return
        }
        do {
            try completeLoginSetup(helperStatus: helperStatus) {
                if loginStatus != .enabled && loginStatus != .requiresApproval {
                    try SMAppService.mainApp.register()
                }
            }
        } catch {
            message = "Launch at login could not be enabled. Check Login Items & Extensions."
        }
        loginStatus = SMAppService.mainApp.status
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
                restoredAutomationPreference = false
            }
            guard let client else { return }
            var reply = try await client.send(.status)
            guard currentRevision == revision, !busy, !quitting else { return }
            if let received = reply.status, received.sleep.fault != nil {
                preferences.set(false, forKey: "allowsAutomation")
            }
            if !restoredAutomationPreference {
                restoredAutomationPreference = true
                if let received = reply.status, preferences.bool(forKey: "allowsAutomation"),
                    Bundle.main.bundleURL.standardizedFileURL.path == "/Applications/Limitless.app"
                {
                    let saved =
                        preferences.data(forKey: "userPolicy").flatMap {
                            try? JSONDecoder().decode(UserPolicy.self, from: $0)
                        } ?? received.policy
                    if let restored = try received.automationPolicyToRestore(saved) {
                        _ = try await client.send(.installCLI)
                        guard currentRevision == revision, !busy, !quitting else { return }
                        reply = try await client.send(.configure(restored))
                    }
                }
            }
            guard currentRevision == revision, !busy, !quitting else { return }
            if let received = reply.status, received.power.battery == .notPresent,
                received.policy.mode != .all, received.removal == .none
            {
                let policy = received.policy
                reply = try await client.send(
                    .configure(
                        try UserPolicy(
                            mode: .all,
                            batteryFloor: policy.batteryFloor,
                            maximumDuration: policy.maximumDuration,
                            allowsAutomation: policy.allowsAutomation)))
            }
            guard currentRevision == revision else { return }
            try accept(reply)
            connectionError = nil
        } catch {
            guard currentRevision == revision else { return }
            connectionError =
                "Connection unavailable. The last reading is no longer current. Reconnect to verify restoration."
            await client?.close()
            client = nil
            watchedProcesses = nil
        }
    }

    private func accept(_ reply: ServiceReply) throws {
        guard let received = reply.status else { throw ServiceError.unavailable }
        if !draftChanged { draft = PolicyDraft(received.policy) }
        baseline = PolicyDraft(received.policy)
        status = received
        statusReceivedAt = .now
        if ownSession == nil { watchedProcesses = nil }
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
                watchedProcesses = nil
            }
            return false
        }
    }

    func startManual() async {
        do {
            let end: SessionEnd
            var followed: [ProcessIdentity] = []
            switch stopChoice {
            case .unlimited: end = .unlimited
            case .preset(let minutes): end = .after(seconds: Double(minutes) * 60)
            case .custom: end = .after(seconds: customDuration * durationUnit.seconds)
            case .date: end = .at(stopDate)
            case .process:
                followed = try ProcessSelection.parse(processID).map { pid in
                    let identity = try selectedProcesses[pid] ?? ProcessIdentity(pid: pid)
                    guard identity.isAlive else { throw WorkError.processUnavailable }
                    return identity
                }
                end = .unlimited
            }
            try end.validate(at: SystemClock.now())
            if await perform(.start(SessionRequest(end: end))), ownSession != nil {
                watchedProcesses = followed.isEmpty ? nil : followed
            }
        } catch {
            message =
                "Choose a valid duration, future date, or available PIDs separated by semicolons."
        }
    }

    func stopManual() async {
        guard let session = ownSession else { return }
        if await perform(.stop(session.id)) { watchedProcesses = nil }
    }

    func stopAll() async { _ = await perform(.stopAll) }
    func rearm() async { _ = await perform(.rearm) }
    func retryRestoration() async { _ = await perform(.retryRestoration) }

    func applyPolicy() async {
        let submitted = draft
        do {
            let policy = try submitted.policy(
                allowsAutomation: status?.policy.allowsAutomation ?? false)
            if await perform(.configure(policy)) {
                let applied = PolicyDraft(status?.policy ?? policy)
                if draft == submitted { draft = applied }
                let saved = try applied.policy(allowsAutomation: false)
                preferences.set(try JSONEncoder().encode(saved), forKey: "userPolicy")
                message = nil
            }
        } catch { message = "Use a battery floor from 0 to 50% and a positive, finite duration." }
    }

    func policyEdited() {
        guard !isPreview, !quitting, draftChanged, policyApplication == nil else { return }
        policyApplication = Task { [weak self] in
            guard let self else { return }
            defer { policyApplication = nil }
            while draftChanged, !quitting {
                guard canControl else { return }
                if busy {
                    do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
                    continue
                }
                let submitted = draft
                await applyPolicy()
                if draft == submitted { return }
            }
        }
    }

    func setAutomation(_ enabled: Bool) async {
        guard let policy = status?.policy else { return }
        if enabled {
            guard Bundle.main.bundleURL.standardizedFileURL.path == "/Applications/Limitless.app"
            else {
                message = "Move Limitless to Applications to enable the CLI."
                return
            }
            guard await perform(.installCLI) else {
                message =
                    "The limitless command could not be installed. An existing command was left unchanged."
                return
            }
        }
        do {
            let updated = try UserPolicy(
                mode: policy.mode, batteryFloor: policy.batteryFloor,
                maximumDuration: policy.maximumDuration, allowsAutomation: enabled)
            if await perform(.configure(updated)) {
                preferences.set(enabled, forKey: "allowsAutomation")
            }
        } catch { message = "The automation limits could not be validated." }
    }

    func setSudoTouchID(_ enabled: Bool) async {
        guard canControl, !busy, !enabled || hasTouchID
        else { return }
        if !(await perform(.setSudoTouchID(enabled)))
            || (enabled
                ? status?.sudoTouchID != .enabled && status?.sudoTouchID != .external
                : status?.sudoTouchID != .disabled)
        {
            message =
                "Touch ID could not be changed. Check the current sudo setting before retrying."
        }
    }

    func registerHelper() async {
        guard trustedBuild, !isPreview, !busy, !removalComplete, let helper else { return }
        busy = true
        do {
            try await helper.register()
            preferences.set(true, forKey: "enableLoginAfterHelperApproval")
        } catch {
            message =
                "The helper could not be enabled. Complete the macOS approval before retrying."
        }
        helperStatus = helper.status
        busy = false
        await refresh()
    }

    func setLaunchAtLogin(_ enabled: Bool) async {
        guard trustedBuild, !isPreview, !busy, !removalComplete else { return }
        preferences.removeObject(forKey: "enableLoginAfterHelperApproval")
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

    func completeLoginSetup(
        helperStatus: SMAppService.Status, register: () throws -> Void
    ) throws {
        guard helperStatus == .enabled,
            preferences.bool(forKey: "enableLoginAfterHelperApproval")
        else { return }
        preferences.removeObject(forKey: "enableLoginAfterHelperApproval")
        try register()
    }

    func openLoginSettings() {
        guard !isPreview else { return }
        SMAppService.openSystemSettingsLoginItems()
    }

    func removeIntegration(forUpdate: Bool = false) async -> Bool {
        guard trustedBuild, !isPreview, !busy, let helper else {
            message = "Removal requires a correctly signed Limitless installation."
            return false
        }
        quitting = true
        busy = true
        removalStep = "Restoring normal sleep…"
        revision &+= 1
        defer {
            busy = false
            removalStep = nil
        }
        while refreshing { try? await Task.sleep(for: .milliseconds(50)) }
        do {
            helperStatus = helper.status
            let filesRemoved =
                try SecureOwnershipJournal.isStateDirectoryAbsent()
                && InstalledHelperFiles.areAbsent()
            if helperStatus == .enabled, !filesRemoved {
                if client == nil { client = try await ServiceClient(role: .application) }
                guard let client else { throw ServiceError.unavailable }
                try accept(await client.send(forUpdate ? .prepareUpdate : .prepareRemoval))
                guard let status, status.removal == .ready, status.canRemoveService,
                    try SecureOwnershipJournal.isStateDirectoryAbsent()
                else { throw ServiceError.restorationRequired }
                if try !InstalledHelperFiles.areAbsent() {
                    _ = try? await client.send(.finishRemoval)
                }
            } else {
                guard try SecureOwnershipJournal.isStateDirectoryAbsent(),
                    try InstalledHelperFiles.areAbsent()
                else {
                    throw ServiceError.restorationRequired
                }
            }
            removalStep = "Removing the helper…"
            if !forUpdate, try InstalledCLI.isAppOwnedLinkPresent() {
                throw ServiceError.restorationRequired
            }
            if !helper.removalIsConfirmed { try await helper.unregister() }
            guard helper.removalIsConfirmed else { throw ServiceError.unavailable }
            await client?.close()
            client = nil
            removalStep = "Removing the login item…"
            let absentLoginStates: [SMAppService.Status] = [.notRegistered, .notFound]
            if !forUpdate, !absentLoginStates.contains(SMAppService.mainApp.status) {
                try await SMAppService.mainApp.unregister()
            }
            guard forUpdate || absentLoginStates.contains(SMAppService.mainApp.status),
                helper.removalIsConfirmed
            else { throw ServiceError.restorationRequired }
            if !forUpdate {
                removalStep = "Removing preferences…"
                for provider in AgentSetup.providers {
                    try AgentSetup.configure(
                        provider, remove: true,
                        resources: Bundle.main.bundleURL.appendingPathComponent(
                            "Contents/Resources/limitless-skill"))
                }
                try Self.erasePreferences(
                    preferences, domain: LimitlessIdentity.application,
                    library: FileManager.default.url(
                        for: .libraryDirectory, in: .userDomainMask,
                        appropriateFor: nil, create: false))
            }
            helperStatus = helper.status
            loginStatus = SMAppService.mainApp.status
            status = nil
            watchedProcesses = nil
            connectionError = nil
            removalComplete = true
            monitoring?.cancel()
            updateMonitoring?.cancel()
            message =
                "Helper, login item and preferences removed."
            return true
        } catch {
            quitting = false
            if forUpdate, error as? ServiceError == .sessionRejected {
                if let reply = try? await client?.send(.status) {
                    try? accept(reply)
                } else {
                    connectionError = "Reconnect before retrying the update."
                }
                message = "Update postponed until current sessions end."
                return false
            }
            await client?.close()
            client = nil
            connectionError =
                "Removal was not confirmed. Reconnect before trusting the current state."
            helperStatus = helper.status
            loginStatus = SMAppService.mainApp.status
            message =
                "\(removalStep ?? "Uninstall") failed: \(error.localizedDescription) Keep Limitless installed and retry."
            return false
        }
    }

    static func erasePreferences(_ defaults: UserDefaults, domain: String, library: URL) throws {
        defaults.removePersistentDomain(forName: domain)
        guard defaults.synchronize() else { throw ServiceError.unavailable }
        for relative in ["Caches/\(domain)", "Saved Application State/\(domain).savedState"] {
            do {
                try FileManager.default.removeItem(at: library.appendingPathComponent(relative))
            } catch let error as CocoaError where error.code == .fileNoSuchFile {
            }
        }
    }

    func prepareToQuit() async -> Bool {
        if isPreview { return true }
        quitting = true
        if !removalComplete { updateInstallation?.cancel() }
        while busy || refreshing || updating { try? await Task.sleep(for: .milliseconds(50)) }
        if ownSession != nil { await stopManual() }
        let unresolved =
            (status?.sleep.ownsGlobalHold == true)
            && (connectionError != nil || status?.sleep.fault != nil || ownSession != nil)
        if unresolved {
            quitting = false
            return false
        }
        monitoring?.cancel()
        updateMonitoring?.cancel()
        await client?.close()
        return true
    }
}

#if DEBUG
    extension AppModel {
        static func preview(_ state: String, watchedProcesses: [ProcessIdentity]? = nil) -> AppModel
        {
            let model = AppModel()
            model.isPreview = true
            model.buildTrust = .untrusted
            model.helperStatus = .enabled
            model.hasTouchID = state != "desktop"
            let active = state == "active" || state == "process"
            let waiting = state == "suspended"
            let failed = state == "restoration"
            let unknown = state == "unknown"
            let policy = try! UserPolicy(
                mode: waiting || state == "external" ? .external : .all,
                allowsAutomation: true)
            let session = SessionSummary(
                id: UUID(), kind: .manual, end: .after(seconds: 3_600),
                startedAt: Date().addingTimeInterval(-900), remainingSeconds: 2_700,
                suspension: waiting ? .powerSource : nil, belongsToClient: true)
            model.status = ServiceStatus(
                policy: policy,
                power: PowerSnapshot(
                    source: state == "desktop" ? .external : .battery,
                    battery: state == "desktop"
                        ? .notPresent
                        : (state == "battery-unknown"
                            ? .unavailable : .available(percent: 76, isDischarging: true))),
                sleep: SleepReport(
                    phase: active ? .active : (failed ? .restoring : .inactive),
                    observed: unknown ? .unknown : (active || failed ? .disabled : .allowed),
                    ownsGlobalHold: active || failed, fault: failed ? .restorationFailed : nil),
                sessions: active || waiting ? [session] : [], sampledAt: Date(),
                sudoTouchID: state == "touch-id-external" ? .external : .disabled)
            model.draft = PolicyDraft(policy)
            model.baseline = model.draft
            model.watchedProcesses = watchedProcesses
            if state == "process" {
                model.stopChoice = .process
                model.watchedProcesses =
                    watchedProcesses
                    ?? (try? RunningProcess.snapshot())?.prefix(3).map(\.identity) ?? []
            }
            if state == "setup" || state == "removed" {
                model.buildTrust = .trusted
                model.helperStatus = .notRegistered
                model.status = nil
                model.removalComplete = state == "removed"
            }
            return model
        }
    }
#endif

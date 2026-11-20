import AppKit
import Foundation
import LimitlessCore
import LimitlessSystem
import LocalAuthentication
import Observation
import ServiceManagement
import UserNotifications

@MainActor @Observable final class AppModel {
    enum BuildTrust { case checking, trusted, untrusted }
    static let updateHelperRecoveryKey = "restoreHelperAfterUpdate"
    static let updateBackupKey = "updateBackup"
    struct UpdateBackup: Codable, Equatable {
        let name: String
        let helperRequired: Bool

        func canRetire(after reading: ServiceStatus?) -> Bool {
            if !helperRequired { return true }
            guard let reading, reading.policyConfigured, reading.removal == .none,
                reading.sleep.fault == nil
            else { return false }
            let sleep = reading.sleep
            return (sleep.phase == .inactive && sleep.observed == .allowed && !sleep.ownsGlobalHold)
                || (sleep.phase == .active && sleep.observed == .disabled && sleep.ownsGlobalHold)
        }
    }
    private static let sessionNotificationsKey = "sessionNotifications"

    private(set) var status: ServiceStatus?
    private(set) var busy = false
    private(set) var extendingSession = false
    private(set) var stoppingSessions = false
    private var pendingExtensions = 0
    private(set) var sudoTouchIDBusy = false
    private(set) var connectionError: String? {
        didSet {
            if connectionError != oldValue { updateEnvironment() }
        }
    }
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
            if !isPreview, automaticUpdates { requestAutomaticUpdateIfReady() }
        }
    }
    private var updatesConsentRecorded = false
    private var pendingLoginSetup = false
    var message: String?
    private(set) var batteryNotice: String?
    private(set) var sudoTouchIDError: ServiceError?
    var pendingSudoTouchID: Bool?
    var draft = PolicyDraft()
    var optionsExpanded = false
    var panelVisible = false
    var favoriteMinutes: Int {
        didSet {
            if !isPreview { preferences.set(favoriteMinutes, forKey: "favoriteMinutes") }
        }
    }
    var menuBarStyle: MenuBarStyle {
        didSet {
            if !isPreview { preferences.set(menuBarStyle.rawValue, forKey: "menuBarStyle") }
        }
    }
    private(set) var sessionNotifications: Bool
    private(set) var lastSessionMessage: String?
    private var sessionNotices = SessionNotices()
    private(set) var lidDisplayState = LidDisplayState.unknown
    private(set) var audioMessage: String?
    private(set) var hotspotMessage: String?
    private(set) var hotspotConfigured: Bool
    private(set) var hotspotEnabled: Bool
    private var hotspotWithdrawalPending = false
    var muteWhenScreenSleeps: Bool {
        didSet {
            if !isPreview {
                preferences.set(muteWhenScreenSleeps, forKey: "muteWhenScreenSleeps")
                updateEnvironment()
            }
        }
    }
    var muteWithClosedLid: Bool {
        didSet {
            if !isPreview {
                preferences.set(muteWithClosedLid, forKey: "muteWithClosedLid")
                updateEnvironment()
            }
        }
    }
    private var screensAsleep = false
    @ObservationIgnored private var audio = SessionAudioMute()
    private let hotspot = HotspotFallback()
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
    private let helper: (any HelperInstallation)?
    private var client: ServiceClient?
    private var monitoring: Task<Void, Never>?
    private var processMonitoring: Task<Void, Never>?
    private(set) var watchedProcesses: [ProcessIdentity]?
    private var policyApplication: Task<Void, Never>?
    private var verifiedPrivateCLI = false
    private(set) var cliMigrationRequired = false
    private var updateMonitoring: Task<Void, Never>?
    private var updateInstallation: Task<Void, Never>?
    private var retiringUpdateBackup = false
    private var checkingUpdates = false
    private var persistsUpdateSchedule = false
    private var updateSchedule: UpdateSchedule {
        didSet {
            if persistsUpdateSchedule { UpdatePreferences.saveSchedule(updateSchedule) }
        }
    }
    private var statusReceivedAt = ContinuousClock.now
    private var refreshing = false
    private var revision = 0
    private var quitting = false
    private var baseline = PolicyDraft()
    private(set) var isPreview = false

    init(
        preferences: UserDefaults = .standard,
        helper: (any HelperInstallation)? =
            (Bundle.main.object(
                forInfoDictionaryKey: "LimitlessHelperInstallation") as? String)
            .flatMap(HelperInstallationKind.init(rawValue:))?.service,
        buildTrust: BuildTrust = .checking,
        updateSchedule: UpdateSchedule = UpdateSchedule()
    ) {
        self.preferences = preferences
        self.helper = helper
        self.buildTrust = buildTrust
        let savedFavorite = preferences.integer(forKey: "favoriteMinutes")
        favoriteMinutes = SessionEnd.presetMinutes.contains(savedFavorite) ? savedFavorite : 60
        menuBarStyle =
            preferences.string(forKey: "menuBarStyle").flatMap(MenuBarStyle.init(rawValue:))
            ?? .remainingTime
        sessionNotifications =
            preferences.object(forKey: Self.sessionNotificationsKey) as? Bool ?? true
        let muteWhenScreenSleeps = preferences.bool(forKey: "muteWhenScreenSleeps")
        self.muteWhenScreenSleeps = muteWhenScreenSleeps
        muteWithClosedLid =
            preferences.object(forKey: "muteWithClosedLid") as? Bool
            ?? muteWhenScreenSleeps
        hotspotConfigured = false
        hotspotEnabled = false
        let authentication = LAContext()
        hasTouchID =
            authentication.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            && authentication.biometryType == .touchID
        self.updateSchedule = updateSchedule
        automaticUpdates = false
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
        if trustedBuild, let network = HotspotCredentials.read() {
            hotspotConfigured = true
            hotspotEnabled = network.automaticJoin == true
        }
        if trustedBuild {
            if let enabled = UpdatePreferences.readConsent() {
                updatesConsentRecorded = true
                automaticUpdates = enabled
            }
            if let schedule = UpdatePreferences.readSchedule() { updateSchedule = schedule }
            persistsUpdateSchedule = true
        }
        if trustedBuild, !InstalledCLI.sharedPathIsProtected {
            do {
                cliMigrationRequired =
                    try InstalledCLI.isAppOwnedLinkPresent()
                    || !AgentSetup.legacyProviders().isEmpty
            } catch {
                cliMigrationRequired = true
            }
        }
    }

    func restoreUpdateHelperIfNeeded(confirmReady: (() async -> Bool)? = nil) async {
        guard preferences.bool(forKey: Self.updateHelperRecoveryKey), trustedBuild, !isPreview,
            let helper
        else { return }
        do {
            if [.notRegistered, .notFound].contains(helper.status) {
                try await helper.register()
            }
            helperStatus = helper.status
            guard helperStatus == .enabled || helperStatus == .requiresApproval else {
                throw ServiceError.unavailable
            }
            if helperStatus == .enabled {
                let ready =
                    if let confirmReady { await confirmReady() } else {
                        await resumeUpdateAdmission()
                    }
                guard ready else { throw ServiceError.restorationRequired }
            }
            clearUpdateHelperRecovery()
        } catch {
            helperStatus = helper.status
            message =
                "Power helper recovery could not be confirmed. Check its status before starting a session."
        }
    }

    private func resumeUpdateAdmission() async -> Bool {
        guard let recovery = try? await ServiceClient(role: .application) else { return false }
        var reading = try? await recovery.send(.status).status
        if let current = reading, current.removal != .none {
            reading = try? await recovery.send(.cancelUpdate).status
        }
        await recovery.close()
        return reading?.removal == RemovalState.none
    }

    private func clearUpdateHelperRecovery() {
        preferences.removeObject(forKey: Self.updateHelperRecoveryKey)
        _ = preferences.synchronize()
    }

    func retireUpdateBackupIfReady() async {
        guard trustedBuild, !isPreview, !quitting, !retiringUpdateBackup,
            let data = preferences.data(forKey: Self.updateBackupKey),
            let backup = try? JSONDecoder().decode(UpdateBackup.self, from: data),
            backup.canRetire(after: canControl ? status : nil)
        else { return }
        retiringUpdateBackup = true
        defer { retiringUpdateBackup = false }
        do {
            try await GitHubUpdate.retirePreviousApplication(named: backup.name)
            if preferences.data(forKey: Self.updateBackupKey) == data {
                preferences.removeObject(forKey: Self.updateBackupKey)
            }
        } catch {
            updateMessage =
                "The previous app is still available. Update recovery could not be cleared."
        }
    }

    var canControl: Bool {
        trustedBuild && !isPreview && helperStatus == .enabled && client != nil && status != nil
            && connectionError == nil && !removalInProgress && !removalComplete
    }
    var showsPowerControls: Bool {
        canControl || (isPreview && helperStatus == .enabled && !removalComplete)
    }
    var canEditPowerPolicy: Bool { showsPowerControls && status?.policyConfigured == true }
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
    var canExtendSession: Bool {
        guard let session = ownSession, !stoppingSessions, watchedProcesses == nil,
            status?.sleep.fault == nil, remainingSeconds(session).map({ $0 > 0 }) == true
        else { return false }
        if case .unlimited = session.end { return false }
        return true
    }
    var canStartFavorite: Bool {
        guard showsPowerControls, !busy, !updating else { return false }
        return canExtendSession || canStartManualSession
    }
    var hasOnlyAgentSessions: Bool {
        guard let sessions = status?.sessions, !sessions.isEmpty else { return false }
        return sessions.allSatisfy { $0.kind == .agent }
    }
    var canStartManualSession: Bool {
        guard showsPowerControls, !busy, !updating, let status, status.policyConfigured,
            status.sleep.fault == nil
        else { return false }
        return hasOnlyAgentSessions && presentation == .active
            || (status.sessions.isEmpty && status.sleep.phase == .inactive
                && status.sleep.observed == .allowed)
    }
    func copyDiagnostic() {
        let reading = connectionError == nil ? status?.diagnosticSummary : nil
        let report = """
            Limitless \(LimitlessIdentity.version), protocol \(ServiceWire.version)
            \(ProcessInfo.processInfo.operatingSystemVersionString)
            \(reading ?? "No current reading from the power helper.")
            """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
    }
    var menuBarTime: MenuBarTime? {
        guard menuBarStyle != .icon, presentation == .active, let status,
            let remaining = protectionRemainingSeconds, remaining.isFinite, remaining > 0
        else { return nil }
        if menuBarStyle == .endTime, let latest = status.protectionRemainingSeconds {
            let end = status.sampledAt.timeIntervalSinceReferenceDate + latest
            return .end(at: Date(timeIntervalSinceReferenceDate: (end / 60).rounded() * 60))
        }
        return .remaining(seconds: remaining)
    }
    var protectionRemainingSeconds: Double? {
        currentRemainingSeconds(status?.protectionRemainingSeconds)
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
        guard connectionError == nil, !removalComplete, !cliMigrationRequired,
            preferences.object(forKey: Self.updateBackupKey) == nil
        else { return false }
        guard let status else { return helperStatus == .notRegistered }
        return status.sessions.isEmpty && !status.sleep.ownsGlobalHold
            && status.sleep.observed == .allowed
            && (status.sleep.phase == .inactive || status.sleep.phase == .blocked)
    }
    func canInstallAvailableUpdate(manual: Bool = false) -> Bool {
        !busy && !sudoTouchIDBusy && !updating && readyToUpdate && !needsManualUpdate
            && updateSchedule.canBeginDownload(manual: manual)
    }
    var needsManualUpdate: Bool {
        availableUpdate != nil && !isPreview && !GitHubUpdate.canReplaceInstalledApplication
    }
    var showsUpdateButton: Bool {
        availableUpdate != nil && !needsManualUpdate && !automaticUpdates
            && updateSchedule.canBeginDownload()
    }
    func updateInstallBlockMessage(manual: Bool = false) -> String {
        if cliMigrationRequired { return "Finish CLI migration before updating again." }
        if needsManualUpdate { return "Download the update and replace Limitless in Applications." }
        if preferences.object(forKey: Self.updateBackupKey) != nil {
            return "Waiting for the previous update to be confirmed."
        }
        return !updateSchedule.canBeginDownload(manual: manual)
            ? "Update postponed. Please try again later."
            : "Stop current sessions to install the update."
    }

    func remainingSeconds(_ session: SessionSummary) -> Double? {
        currentRemainingSeconds(session.remainingSeconds)
    }

    private func currentRemainingSeconds(_ remaining: Double?) -> Double? {
        guard let remaining else { return nil }
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
                    await self?.refresh()
                    _ = await self?.checkForUpdates()
                    let delay = max(
                        60,
                        self?.updateSchedule.nextCheck.timeIntervalSinceNow
                            ?? UpdateSchedule.interval)
                    do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                }
            }
        }
        monitoring = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if !quitting {
                    await refresh()
                    if status == nil || connectionError != nil { updateEnvironment() }
                    requestAutomaticUpdateIfReady()
                }
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
            }
        }
    }

    private func monitorProcesses() {
        processMonitoring?.cancel()
        guard watchedProcesses != nil else { return }
        processMonitoring = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, watchedProcesses != nil, ownSession != nil else { return }
                if !quitting, pollWatchedProcesses(), !busy {
                    await stopManual()
                    if ownSession == nil { return }
                }
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }

    func checkForUpdates(manual: Bool = false) async -> Bool? {
        if manual { updateMessage = nil }
        guard trustedBuild, !isPreview, !quitting, !updating else { return nil }
        guard !checkingUpdates else {
            if manual { updateMessage = "An update check is already in progress." }
            return nil
        }
        guard updateSchedule.beginCheck(manual: manual) else {
            if manual, let next = updateSchedule.nextManualCheck() {
                updateMessage =
                    "The next update check is available after \(next.formatted(date: .omitted, time: .shortened))."
            }
            return nil
        }
        checkingUpdates = true
        defer { checkingUpdates = false }
        do {
            let update = try await GitHubUpdate.latest(
                currentVersion: LimitlessIdentity.version)
            recordDetectedUpdate(update, manual: manual)
            return update != nil
        } catch let error as UpdateError {
            if case .rateLimited(let until) = error {
                updateSchedule.failed(download: false, retryAfter: until)
            } else {
                updateSchedule.failed(download: false)
            }
            if manual { updateMessage = error.localizedDescription }
        } catch {
            updateSchedule.failed(download: false)
            if manual {
                updateMessage = "Could not reach GitHub. Check your connection and try again."
            }
        }
        return nil
    }

    @discardableResult
    func recordDetectedUpdate(_ update: GitHubUpdate.Release?, manual: Bool) -> Bool {
        availableUpdate = update
        updateSchedule.checked()
        return !manual && requestAutomaticUpdateIfReady()
    }

    @discardableResult
    func requestAutomaticUpdateIfReady() -> Bool {
        guard automaticUpdates, availableUpdate != nil, canInstallAvailableUpdate() else {
            return false
        }
        return requestUpdate()
    }

    func installUpdate(manual: Bool = false) async {
        guard trustedBuild, !isPreview, !quitting, !updating, !busy, !sudoTouchIDBusy,
            let availableUpdate
        else { return }
        guard !needsManualUpdate else {
            updateMessage = updateInstallBlockMessage()
            return
        }
        guard readyToUpdate else {
            updateMessage = updateInstallBlockMessage(manual: manual)
            return
        }
        guard updateSchedule.beginDownload(manual: manual) else {
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
            let installedApp = try await GitHubUpdate.currentInstalledApplication(
                identity: identity)
            let candidate = try await GitHubUpdate.stage(
                availableUpdate, identity: identity, installedApp: installedApp)
            staged = candidate
            updateSchedule.downloaded()
            guard !quitting else { return }
            updateMessage = "Installing update…"
            if helper?.status == .enabled {
                preferences.set(true, forKey: Self.updateHelperRecoveryKey)
                guard preferences.synchronize() else { throw ServiceError.unavailable }
            }
            guard await removeIntegration(forUpdate: true) else {
                updateMessage = message
                await Task { await restoreUpdateHelperIfNeeded() }.value
                await refresh()
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
            }
            await Task { await restoreUpdateHelperIfNeeded() }.value
            beginMonitoring()
        }
    }

    @discardableResult
    func requestUpdate(manual: Bool = false) -> Bool {
        guard updateInstallation == nil else { return false }
        updateInstallation = Task { [weak self] in
            await self?.installUpdate(manual: manual)
            self?.updateInstallation = nil
        }
        return true
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
            }
            guard let client else { return }
            var reply = try await client.send(.status)
            guard currentRevision == revision, !busy, !quitting else { return }
            if let received = reply.status, !received.policyConfigured, received.removal == .none {
                reply = try await client.send(.restorePolicy)
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
                            allowsAutomation: policy.allowsAutomation,
                            keepsDisplayAwake: policy.keepsDisplayAwake)))
            }
            guard currentRevision == revision else { return }
            try accept(reply)
            connectionError = nil
            if status?.policy.allowsAutomation == true, !verifiedPrivateCLI,
                !InstalledCLI.sharedPathIsProtected
            {
                verifiedPrivateCLI = true
                Task {
                    do { try await InstalledCLI.refreshPrivateCopy() } catch {
                        self.message =
                            "The private CLI could not be refreshed. Enable CLI access again."
                    }
                }
            }
            if !updating, reply.status?.removal == RemovalState.none,
                reply.status?.policyConfigured == true,
                preferences.bool(forKey: Self.updateHelperRecoveryKey)
            {
                clearUpdateHelperRecovery()
            }
            if preferences.object(forKey: Self.updateBackupKey) != nil {
                Task { await retireUpdateBackupIfReady() }
            }
        } catch {
            guard currentRevision == revision else { return }
            connectionError =
                "Connection unavailable. The last reading is no longer current. Reconnect to verify restoration."
            await client?.close()
            client = nil
            watchedProcesses = nil
        }
    }

    func accept(_ reply: ServiceReply) throws {
        guard let received = reply.status else { throw ServiceError.unavailable }
        updateSessionNotices(received)
        if received.batteryCutoff != status?.batteryCutoff {
            batteryNotice = received.batteryCutoff.map { cutoff in
                reply.startedSession == cutoff.sessionID
                    ? "Battery at \(cutoff.percent)%. Charge above \(cutoff.limit)% to start."
                    : "Session ended at \(cutoff.percent)% battery (limit: \(cutoff.limit)%)."
            }
        }
        if received.policyConfigured {
            let receivedDraft = PolicyDraft(received.policy)
            if !draftChanged, draft != receivedDraft { draft = receivedDraft }
            if baseline != receivedDraft { baseline = receivedDraft }
        }
        status = received
        statusReceivedAt = .now
        if ownSession == nil { watchedProcesses = nil }
        updateEnvironment()
    }

    func setScreensAsleep(_ asleep: Bool) {
        screensAsleep = asleep
        updateEnvironment()
    }

    func updateEnvironment() {
        guard trustedBuild, !isPreview,
            Bundle.main.bundleIdentifier == LimitlessIdentity.application
        else { return }
        let active = !quitting && presentation == .active
        lidDisplayState = active ? .read() : .unknown
        audioMessage = audio.update(
            shouldMute: lidDisplayState.shouldMuteAudio(
                active: active, screenAsleep: screensAsleep, muteOnSleep: muteWhenScreenSleeps,
                muteOnLidClose: muteWithClosedLid))
        hotspot.update(
            eligible: active && !stoppingSessions && hotspotEnabled && !hotspotWithdrawalPending
        ) { [weak self] in
            await self?.canJoinHotspot() ?? false
        }
        hotspotMessage = hotspot.message
    }

    private func canJoinHotspot() async -> Bool {
        guard hotspotEnabled, !hotspotWithdrawalPending, canControl, !busy, !quitting,
            !stoppingSessions, let client
        else { return false }
        let startingRevision = revision
        let reading = try? await client.send(.status).status
        guard startingRevision == revision, hotspotEnabled, !hotspotWithdrawalPending,
            canControl, !quitting,
            !stoppingSessions, let reading
        else { return false }
        return PowerPresentation(reading) == .active
            && reading.sessions.contains { $0.suspension == nil }
    }

    func saveHotspot(name: String, password: String) -> Bool {
        guard trustedBuild, !isPreview else { return false }
        let network = HotspotCredentials.Network(
            ssid: name, password: password, automaticJoin: hotspotEnabled)
        guard network.isValid else {
            message = "Enter your hotspot name and its password (at least eight characters)."
            return false
        }
        guard HotspotCredentials.save(network) else {
            message = "The hotspot details could not be saved in Keychain."
            return false
        }
        hotspotConfigured = true
        hotspotWithdrawalPending = false
        hotspot.update(eligible: false)
        updateEnvironment()
        message = "Hotspot details saved in Keychain."
        return true
    }

    func setHotspotEnabled(_ enabled: Bool) {
        guard trustedBuild, !isPreview, hotspotConfigured else { return }
        if !enabled {
            hotspotWithdrawalPending = true
            hotspot.update(eligible: false)
        }
        guard let network = HotspotCredentials.read(),
            HotspotCredentials.save(
                .init(ssid: network.ssid, password: network.password, automaticJoin: enabled))
        else {
            message =
                enabled
                ? "Hotspot fallback could not be enabled. Unlock Keychain and try again."
                : "Hotspot fallback is paused. Unlock Keychain and retry to turn it off."
            return
        }
        hotspotWithdrawalPending = false
        hotspotEnabled = enabled
        if enabled { hotspot.requestLocationAccess() }
        updateEnvironment()
    }

    func forgetHotspot() {
        guard trustedBuild, !isPreview else { return }
        hotspotWithdrawalPending = true
        hotspot.update(eligible: false)
        guard removeHotspotConfiguration() else {
            message = "The hotspot details could not be removed from Keychain."
            return
        }
        message = nil
    }

    private func removeHotspotConfiguration() -> Bool {
        guard HotspotCredentials.remove() else { return false }
        hotspotConfigured = false
        hotspotEnabled = false
        hotspotWithdrawalPending = false
        return true
    }

    var shouldRequestInitialSessionNotifications: Bool {
        trustedBuild && !isPreview && sessionNotifications
            && preferences.object(forKey: Self.sessionNotificationsKey) == nil
    }

    func setSessionNotifications(_ enabled: Bool) async {
        guard !isPreview, Bundle.main.bundleURL.pathExtension == "app" else { return }
        sessionNotifications = enabled
        preferences.set(enabled, forKey: Self.sessionNotificationsKey)
        guard enabled else { return }
        let outcome = try? await UNUserNotificationCenter.current().requestAuthorization(options: [
            .alert
        ])
        if outcome != true, sessionNotifications {
            sessionNotifications = false
            preferences.set(false, forKey: Self.sessionNotificationsKey)
            message =
                "Allow notifications for Limitless in System Settings to receive session alerts."
        }
    }

    private func updateSessionNotices(_ received: ServiceStatus) {
        if let status {
            let previous = Set(status.recentEndings.map(\.id))
            if let ending = received.recentEndings.last(where: { !previous.contains($0.id) }) {
                let text = ending.reason.summary
                lastSessionMessage = text
                if received.sessions.isEmpty {
                    notify(title: "Limitless session ended", body: text)
                }
            }
        }
        if sessionNotifications, sessionNotices.shouldRemind(received) {
            notify(title: "Limitless session ending soon", body: "Five minutes or less remain.")
        }
    }

    private func notify(title: String, body: String) {
        guard sessionNotifications, !isPreview, Bundle.main.bundleURL.pathExtension == "app" else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    private func perform(_ operation: ServiceOperation, authorization: Data? = nil) async -> Bool {
        guard canControl, !busy, let client else { return false }
        busy = true
        revision &+= 1
        message = nil
        defer { busy = false }
        do {
            try accept(await client.send(operation, authorization: authorization))
            return true
        } catch {
            reportOperationError(error)
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

    func reportOperationError(_ error: any Error) {
        switch error as? ServiceError {
        case .sudoTouchIDPermissionDenied, .sudoTouchIDFailed:
            sudoTouchIDError = error as? ServiceError
        case .thermalCritical:
            message = "The Mac is too hot to start a session. Let it cool down and try again."
        default:
            message =
                "The request was not confirmed. Check the current state and your limits before retrying."
        }
    }

    var sudoTouchIDNeedsPermission: Bool { sudoTouchIDError == .sudoTouchIDPermissionDenied }

    var sudoTouchIDMessage: String? {
        switch sudoTouchIDError {
        case .sudoTouchIDPermissionDenied:
            "In Full Disk Access, enable the entry ending in “Limitless.sudo.helper”, then try again."
        case .sudoTouchIDFailed:
            "Touch ID could not be changed. Check your sudo configuration before retrying."
        default: nil
        }
    }

    func startFavorite() async {
        guard canStartFavorite else { return }
        if canExtendSession {
            await extendSession()
        } else {
            await startManual(choice: .preset(favoriteMinutes))
        }
    }

    func startManual(choice: StopChoice? = nil) async {
        guard canStartManualSession else { return }
        do {
            let end: SessionEnd
            var followed: [ProcessIdentity] = []
            switch choice ?? stopChoice {
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
            let now = try SystemClock.now()
            try end.validate(at: now)
            #if DEBUG
                if isPreview, showsPowerControls, status?.sessions.isEmpty == true, followed.isEmpty
                {
                    simulateSession(end)
                    return
                }
            #endif
            if await perform(.start(SessionRequest(end: end))), ownSession != nil {
                watchedProcesses = followed.isEmpty ? nil : followed
                monitorProcesses()
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

    func extendSession() async {
        #if DEBUG
            if isPreview, canExtendSession, let session = ownSession,
                let remaining = remainingSeconds(session)
            {
                simulateSession(.after(seconds: remaining + 900))
                return
            }
        #endif
        guard canControl, canExtendSession, !busy || extendingSession else { return }
        pendingExtensions += 1
        guard !extendingSession, let id = ownSession?.id else { return }
        extendingSession = true
        defer {
            extendingSession = false
            pendingExtensions = 0
        }
        while pendingExtensions > 0, ownSession?.id == id, !quitting {
            pendingExtensions -= 1
            guard await perform(.extend(id)) else { return }
        }
    }

    func stopAll() async {
        #if DEBUG
            if isPreview {
                if status?.sessions.isEmpty == false { simulateSession(nil) }
                return
            }
        #endif
        guard !stoppingSessions else { return }
        stoppingSessions = true
        updateEnvironment()
        defer {
            stoppingSessions = false
            updateEnvironment()
        }
        pendingExtensions = 0
        while extendingSession { try? await Task.sleep(for: .milliseconds(20)) }
        let allowedAutomation = status?.policy.allowsAutomation == true
        if await perform(.stopAll), allowedAutomation, status?.policy.allowsAutomation == false {
            message = "Work stopped. Re-enable CLI & AI tasks to start new automated work."
        }
    }
    func rearm() async {
        if await perform(.rearm), status?.policyConfigured == false { await refresh() }
    }
    func retryRestoration() async { _ = await perform(.retryRestoration) }

    func applyPolicy() async {
        let submitted = draft
        do {
            let policy = try submitted.policy(
                allowsAutomation: status?.policy.allowsAutomation ?? false)
            if await perform(.configure(policy)) {
                let applied = PolicyDraft(status?.policy ?? policy)
                if draft == submitted { draft = applied }
                message = nil
            }
        } catch { message = "Use a battery floor from 0 to 80% and a positive, finite duration." }
    }

    func policyEdited() {
        guard !isPreview, canEditPowerPolicy, !quitting, draftChanged, policyApplication == nil
        else { return }
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

    func setAutomation(_ enabled: Bool, migrateLegacy: Bool = false) async {
        guard canControl, status?.policyConfigured == true else { return }
        guard enabled else {
            _ = await perform(.setAutomation(false))
            return
        }
        guard !cliMigrationRequired || migrateLegacy else { return }
        guard
            let identity = try? await SignedIdentity.current(
                expectedIdentifier: LimitlessIdentity.application),
            (try? await GitHubUpdate.currentInstalledApplication(identity: identity)) != nil
        else {
            message = "Move Limitless to Applications to enable the CLI."
            return
        }
        do {
            try await AdministratorAuthorization.withGrant { grant in
                var privateResources: URL?
                if !InstalledCLI.sharedPathIsProtected {
                    privateResources = try await InstalledCLI.refreshPrivateCopy()
                    self.verifiedPrivateCLI = true
                }
                guard await self.perform(.installCLI, authorization: grant) else {
                    self.message =
                        "The limitless command could not be installed. An existing command was left unchanged."
                    return
                }
                if migrateLegacy {
                    if let privateResources {
                        guard try !InstalledCLI.isAppOwnedLinkPresent()
                        else { throw ServiceError.restorationRequired }
                        for provider in try AgentSetup.legacyProviders() {
                            try AgentSetup.configure(provider, resources: privateResources)
                        }
                        guard try AgentSetup.legacyProviders().isEmpty
                        else { throw ServiceError.restorationRequired }
                    } else if !InstalledCLI.sharedPathIsProtected {
                        throw ServiceError.restorationRequired
                    }
                    self.cliMigrationRequired = false
                }
                guard !self.cliMigrationRequired else { return }
                _ = await self.perform(.setAutomation(true), authorization: grant)
            }
        } catch {
            message =
                error as? ServiceError == .unauthorized
                ? "Administrator approval is needed to enable CLI and AI tasks."
                : migrateLegacy
                    ? "CLI migration could not finish. Check your agent settings and retry."
                    : "The private CLI could not be verified. Keep the signed app in Applications."
        }
    }

    func setSudoTouchID(_ enabled: Bool) async {
        guard canControl, !busy, !sudoTouchIDBusy, !updating, !quitting, !enabled || hasTouchID
        else { return }
        sudoTouchIDBusy = true
        sudoTouchIDError = nil
        do {
            try await SudoInstallation.ensureInstalled()
            guard !quitting else { throw CancellationError() }
            let reply = try await AdministratorAuthorization.withGrant { grant in
                guard !self.quitting else { throw CancellationError() }
                let client = try await ServiceClient(role: .application, sudo: true)
                do {
                    let reply = try await client.send(
                        .setSudoTouchID(enabled), authorization: grant)
                    await client.close()
                    return reply
                } catch {
                    await client.close()
                    throw error
                }
            }
            guard
                enabled
                    ? reply.sudoTouchID == .enabled || reply.sudoTouchID == .external
                    : reply.sudoTouchID == .disabled
            else { throw ServiceError.sudoTouchIDFailed }
        } catch {
            reportOperationError(
                error as? ServiceError == .sudoTouchIDPermissionDenied
                    ? ServiceError.sudoTouchIDPermissionDenied : ServiceError.sudoTouchIDFailed)
        }
        sudoTouchIDBusy = false
        await refresh()
    }

    func registerHelper() async {
        guard trustedBuild, !isPreview, !busy, !removalComplete, let helper else { return }
        busy = true
        do {
            try await helper.register()
            pendingLoginSetup = true
            if !updatesConsentRecorded { setAutomaticUpdates(true) }
        } catch {
            message =
                "The helper could not be enabled. Complete the macOS approval before retrying."
        }
        helperStatus = helper.status
        if helperStatus == .enabled || helperStatus == .requiresApproval {
            clearUpdateHelperRecovery()
        }
        busy = false
        await refresh()
    }

    func setLaunchAtLogin(_ enabled: Bool) async {
        guard trustedBuild, !isPreview, !busy, !removalComplete else { return }
        pendingLoginSetup = false
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
        helperStatus: SMAppService.Status,
        register: () throws -> Void
    ) throws {
        guard helperStatus == .enabled, pendingLoginSetup else { return }
        pendingLoginSetup = false
        try register()
    }

    func setAutomaticUpdates(_ enabled: Bool) {
        if isPreview {
            automaticUpdates = enabled
            return
        }
        guard trustedBuild else { return }
        guard UpdatePreferences.saveConsent(enabled) else {
            if !enabled { automaticUpdates = false }
            updateMessage = "The update setting could not be saved. Unlock Keychain and try again."
            return
        }
        updatesConsentRecorded = true
        automaticUpdates = enabled
    }

    func openLoginSettings() {
        guard !isPreview else { return }
        SMAppService.openSystemSettingsLoginItems()
    }

    func openPrivacySettings() {
        guard !isPreview else { return }
        let workspace = NSWorkspace.shared
        if workspace.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        ) {
            return
        }
        if let settings = workspace.urlForApplication(
            withBundleIdentifier: "com.apple.systempreferences")
        {
            workspace.open(settings)
        }
    }

    func removeIntegration(forUpdate: Bool = false) async -> Bool {
        guard trustedBuild, !isPreview, !busy, !sudoTouchIDBusy, let helper else {
            message = "Removal requires a correctly signed Limitless installation."
            return false
        }
        do {
            let requiresApproval =
                !forUpdate || helper.status == .enabled || SudoInstallation.isRegistered
            if !requiresApproval {
                return await removeAuthorizedIntegration(
                    helper: helper, forUpdate: forUpdate, authorization: nil)
            }
            return try await AdministratorAuthorization.withGrant { grant in
                await self.removeAuthorizedIntegration(
                    helper: helper, forUpdate: forUpdate, authorization: grant)
            }
        } catch {
            message = "Administrator approval is needed before removing system components."
            return false
        }
    }

    private func removeAuthorizedIntegration(
        helper: any HelperInstallation, forUpdate: Bool, authorization: Data?
    ) async -> Bool {
        guard !busy, !sudoTouchIDBusy else { return false }
        quitting = true
        updateEnvironment()
        if forUpdate, let audioMessage {
            quitting = false
            message = audioMessage
            return false
        }
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
            let prepared = helperStatus == .enabled && !filesRemoved
            if prepared {
                if client == nil { client = try await ServiceClient(role: .application) }
                guard let client else { throw ServiceError.unavailable }
                try accept(
                    await client.send(
                        forUpdate ? .prepareUpdate : .prepareRemoval, authorization: authorization))
                guard let status, status.removal == .ready, status.canRemoveService,
                    try forUpdate || SecureOwnershipJournal.isStateDirectoryAbsent()
                else { throw ServiceError.restorationRequired }
            } else {
                guard try SecureOwnershipJournal.isStateDirectoryAbsent(),
                    try InstalledHelperFiles.areAbsent()
                else {
                    throw ServiceError.restorationRequired
                }
            }
            if !forUpdate {
                updateEnvironment()
                if let audioMessage {
                    quitting = false
                    message = audioMessage
                    return false
                }
                if !removeHotspotConfiguration() {
                    quitting = false
                    message =
                        "The hotspot details could not be removed from Keychain. Unlock it and retry."
                    return false
                }
                guard UpdatePreferences.remove() else {
                    quitting = false
                    message = "The saved update settings could not be removed from Keychain."
                    return false
                }
            }
            removalStep = "Removing the sudo component…"
            try await SudoInstallation.remove(forUpdate: forUpdate, authorization: authorization)
            if try (forUpdate && prepared) || !InstalledHelperFiles.areAbsent() {
                await client?.close()
                client = try await ServiceClient(role: .application)
                _ = try await client?.send(
                    forUpdate ? .prepareUpdate : .prepareRemoval, authorization: authorization)
                _ = try await client?.send(.finishRemoval, authorization: authorization)
            }
            removalStep = "Removing the helper…"
            guard try SecureOwnershipJournal.isStateDirectoryAbsent() else {
                throw ServiceError.restorationRequired
            }
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
                helper.removalIsConfirmed,
                try InstalledHelperFiles.areAbsent(kind: .sudo), !SudoInstallation.isRegistered
            else { throw ServiceError.restorationRequired }
            if !forUpdate {
                removalStep = "Removing preferences…"
                for provider in AgentSetup.providers {
                    try AgentSetup.configure(
                        provider, remove: true,
                        resources: Bundle.main.bundleURL.appendingPathComponent(
                            "Contents/Resources/limitless-skill"))
                }
                try await InstalledCLI.removePrivateCopy()
                let library = try FileManager.default.url(
                    for: .libraryDirectory, in: .userDomainMask,
                    appropriateFor: nil, create: false)
                try Self.erasePreferences(
                    preferences, domain: LimitlessIdentity.application, library: library)
                guard
                    let sudoPreferences = UserDefaults(suiteName: LimitlessIdentity.sudoApplication)
                else {
                    throw ServiceError.unavailable
                }
                try Self.erasePreferences(
                    sudoPreferences, domain: LimitlessIdentity.sudoApplication, library: library)
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
            if error as? ServiceError == .sudoTouchIDPermissionDenied
                || error as? ServiceError == .sudoTouchIDFailed
            {
                reportOperationError(error)
            }
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
        updateEnvironment()
        if !removalComplete { updateInstallation?.cancel() }
        while busy || refreshing || updating { try? await Task.sleep(for: .milliseconds(50)) }
        if ownSession != nil { await stopManual() }
        let unresolved =
            (status?.sleep.ownsGlobalHold == true)
            && (connectionError != nil || status?.sleep.fault != nil || ownSession != nil)
        if unresolved || audioMessage != nil {
            quitting = false
            return false
        }
        monitoring?.cancel()
        processMonitoring?.cancel()
        updateMonitoring?.cancel()
        await client?.close()
        return true
    }
}

#if DEBUG
    extension AppModel {
        private func simulateSession(_ end: SessionEnd?) {
            guard isPreview, let status else { return }
            let previous = ownSession
            let now = Date.now
            let sessions: [SessionSummary] =
                end.map { end in
                    let remaining: Double? =
                        switch end {
                        case .unlimited: nil
                        case .after(let seconds): seconds
                        case .at(let date): date.timeIntervalSince(now)
                        }
                    return [
                        SessionSummary(
                            id: previous?.id ?? UUID(), kind: .manual, end: end,
                            startedAt: previous?.startedAt ?? now, remainingSeconds: remaining,
                            suspension: nil, belongsToClient: true)
                    ]
                } ?? []
            let active = !sessions.isEmpty
            let simulated = ServiceStatus(
                policy: status.policy, power: status.power,
                sleep: SleepReport(
                    phase: active ? .active : .inactive, observed: active ? .disabled : .allowed,
                    ownsGlobalHold: active, fault: nil),
                sessions: sessions, sampledAt: now, sudoTouchID: status.sudoTouchID)
            try? accept(ServiceReply(status: simulated))
        }

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
            var registry = SessionRegistry(policy: policy)
            if state == "battery-low" {
                let now = try! SystemClock.now()
                try! registry.start(.init(), owner: UUID(), kind: .manual, now: now)
                _ = registry.evaluate(
                    power: .init(
                        source: .battery, battery: .available(percent: 18, isDischarging: true)),
                    now: now)
            }
            let session = SessionSummary(
                id: UUID(), kind: .manual, end: .after(seconds: 3_600),
                startedAt: Date().addingTimeInterval(-900), remainingSeconds: 2_700,
                suspension: waiting ? .powerSource : nil, belongsToClient: true)
            let previewStatus = ServiceStatus(
                policy: policy,
                power: PowerSnapshot(
                    source: state == "desktop" ? .external : .battery,
                    battery: state == "desktop"
                        ? .notPresent
                        : (state == "battery-unknown"
                            ? .unavailable
                            : .available(
                                percent: state == "battery-low" ? 18 : 76, isDischarging: true))),
                sleep: SleepReport(
                    phase: active ? .active : (failed ? .restoring : .inactive),
                    observed: unknown ? .unknown : (active || failed ? .disabled : .allowed),
                    ownsGlobalHold: active || failed, fault: failed ? .restorationFailed : nil),
                sessions: active || waiting ? [session] : [], sampledAt: Date(),
                sudoTouchID: state == "touch-id-external" ? .external : .disabled,
                batteryCutoff: registry.batteryCutoff)
            try! model.accept(ServiceReply(status: previewStatus))
            if state == "touch-id-permission" {
                model.reportOperationError(ServiceError.sudoTouchIDPermissionDenied)
            }
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

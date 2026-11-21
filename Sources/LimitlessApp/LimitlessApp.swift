import AppKit
import Carbon
import Darwin
import LimitlessCore
import LimitlessSystem
import Observation
import SwiftUI

@main
enum LimitlessApp {
    @MainActor static func main() {
        guard geteuid() != 0 else { exit(1) }
        if CommandLine.arguments.dropFirst().first == "--finish-update" {
            let args = Array(CommandLine.arguments.dropFirst())
            guard args.count == 4, let parent = Int32(args[2]), ["0", "1"].contains(args[3])
            else { exit(64) }
            let helperRequired = args[3] == "1"
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
            Task {
                do {
                    guard try UpdatePreferences.readBackup() == nil else {
                        throw UpdateError.busy
                    }
                    let installer = try ProcessIdentity.current()
                    let installed = try await GitHubUpdate.finish(
                        app: URL(fileURLWithPath: args[1]), parentPID: parent
                    ) { backupURL in
                        guard try UpdatePreferences.readBackup() == nil else {
                            throw UpdateError.busy
                        }
                        let pendingRecovery = try UpdatePreferences.helperRecovery() != nil
                        let backup = AppModel.UpdateBackup(
                            name: backupURL.lastPathComponent,
                            helperRequired: helperRequired || pendingRecovery,
                            installer: installer)
                        return try UpdatePreferences.reserveBackup(backup)
                    }
                    let configuration = NSWorkspace.OpenConfiguration()
                    configuration.createsNewApplicationInstance = true
                    try GitHubUpdate.requireProtectedLaunchPath(installed.app)
                    do {
                        _ = try await NSWorkspace.shared.openApplication(
                            at: installed.app, configuration: configuration)
                    } catch {
                        try GitHubUpdate.requireProtectedLaunchPath(installed.backup)
                        _ = try FileManager.default.replaceItemAt(
                            installed.app, withItemAt: installed.backup,
                            options: .usingNewMetadataOnly)
                        _ = UpdatePreferences.clearReceipt(installed.receipt)
                        throw error
                    }
                    try? FileManager.default.removeItem(at: installed.staging)
                    GitHubUpdate.retireInstallerCopy()
                    exit(0)
                } catch {
                    let configuration = NSWorkspace.OpenConfiguration()
                    configuration.createsNewApplicationInstance = true
                    if let recoveryApp = await GitHubUpdate.recoveryApplication() {
                        _ = try? await NSWorkspace.shared.openApplication(
                            at: recoveryApp, configuration: configuration)
                    }
                    let alert = NSAlert()
                    alert.messageText = "Update incomplete"
                    alert.informativeText = error.localizedDescription
                    alert.addButton(withTitle: "OK")
                    app.activate()
                    alert.runModal()
                    exit(1)
                }
            }
            app.run()
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSMenuItemValidation {
    let model: AppModel
    private var terminating = false
    private var statusItem: NSStatusItem?
    private var lastPresentation: PowerPresentation?
    private var lastMenuBarTime: MenuBarTime?
    #if DEBUG
        private var previewTick: Task<Void, Never>?
    #endif
    private let activeMark = StatusMark()
    private var commandClick = StatusCommandClick()
    private var closesPanelOnStatusClick = false
    private var statusClickMonitors: [Any] = []
    private let popover = NSPopover()
    private var removalWindow: NSWindow?

    override init() {
        #if DEBUG
            let arguments = CommandLine.arguments
            let preview =
                arguments.firstIndex(of: "--preview").flatMap {
                    $0 + 1 < arguments.count ? arguments[$0 + 1] : nil
                } ?? Bundle.main.object(forInfoDictionaryKey: "LimitlessPreviewState") as? String
            if let preview {
                model = AppModel.preview(preview)
            } else {
                model = AppModel()
            }
        #else
            model = AppModel()
        #endif
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.applicationIconImage = BrandArt.appIcon(size: 256)
        #if DEBUG
            if model.isPreview, CommandLine.arguments.contains("--light") {
                NSApp.appearance = NSAppearance(
                    named: CommandLine.arguments.contains("--contrast")
                        ? .accessibilityHighContrastAqua : .aqua)
            }
        #endif
        installStatusItem()
        Task {
            await model.prepareForLaunch()
            await model.restoreUpdateHelperIfNeeded()
            if model.trustedBuild && !model.isPreview {
                let workspace = NSWorkspace.shared.notificationCenter
                workspace.addObserver(
                    self, selector: #selector(screensSlept),
                    name: NSWorkspace.screensDidSleepNotification, object: nil)
                workspace.addObserver(
                    self, selector: #selector(screensWoke),
                    name: NSWorkspace.screensDidWakeNotification, object: nil)
                NotificationCenter.default.addObserver(
                    self, selector: #selector(displaysChanged),
                    name: NSApplication.didChangeScreenParametersNotification, object: nil)
                model.updateEnvironment()
            }
            model.beginMonitoring()
            await model.retireUpdateBackupIfReady()
            if model.shouldRequestInitialSessionNotifications {
                await model.setSessionNotifications(true)
            }
        }
    }

    @objc private func screensSlept(_ notice: Notification) { model.setScreensAsleep(true) }
    @objc private func screensWoke(_ notice: Notification) { model.setScreensAsleep(false) }
    @objc private func displaysChanged(_ notice: Notification) { model.updateEnvironment() }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = LimitlessIdentity.application
        statusItem = item
        item.button?.image = BrandArt.menuIdle
        item.button?.setAccessibilityLabel("Limitless: Setup required")
        item.button?.target = self
        item.button?.action = #selector(clickStatusItem)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.setAccessibilityHelp(
            "Click to open. Command-click to start your favorite or add 15 minutes. Right-click for app actions."
        )
        if let button = item.button {
            activeMark.image = BrandArt.menuOrange
            activeMark.isHidden = true
            activeMark.setAccessibilityElement(false)
            activeMark.frame = NSRect(
                x: max(0, button.bounds.midX + 3),
                y: button.bounds.midY + (button.isFlipped ? 3 : -10),
                width: 8, height: 7)
            activeMark.autoresizingMask = [
                .minXMargin, .maxXMargin, .minYMargin, .maxYMargin,
            ]
            button.addSubview(activeMark)
        }
        let statusMouseEvents: NSEvent.EventTypeMask = [
            .leftMouseDown, .leftMouseUp, .leftMouseDragged,
        ]
        let local = NSEvent.addLocalMonitorForEvents(matching: statusMouseEvents) {
            [weak self] event in
            MainActor.assumeIsolated { self?.trackStatusClick(event) }
            return event
        }
        let global = NSEvent.addGlobalMonitorForEvents(
            matching: statusMouseEvents.union(.rightMouseDown)
        ) { [weak self] event in
            MainActor.assumeIsolated { self?.handleGlobalMouseEvent(event) }
        }
        statusClickMonitors = [local, global].compactMap { $0 }
        popover.delegate = self
        popover.animates = false
        let host = NSHostingController(
            rootView: MenuPanel(model: model).onExitCommand { [weak self] in
                self?.popover.performClose(nil)
            })
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        let mainMenu = NSMenu()
        let application = NSMenuItem()
        application.submenu = actionsMenu()
        mainMenu.addItem(application)
        let edit = NSMenu(title: "Edit")
        for (title, selector, key) in [
            ("Cut", #selector(NSText.cut(_:)), "x"),
            ("Copy", #selector(NSText.copy(_:)), "c"),
            ("Paste", #selector(NSText.paste(_:)), "v"),
            ("Select All", #selector(NSText.selectAll(_:)), "a"),
        ] {
            edit.addItem(withTitle: title, action: selector, keyEquivalent: key)
        }
        let editItem = NSMenuItem()
        editItem.submenu = edit
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
        observePresentation()
    }

    private func observePresentation() {
        withObservationTracking {
            refreshMenuBarTime()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observePresentation() }
        }
    }

    private func refreshMenuBarTime() {
        let presentation = model.presentation
        let time = model.menuBarTime
        #if DEBUG
            if model.isPreview { schedulePreviewTick() }
        #endif
        guard presentation != lastPresentation || time != lastMenuBarTime else { return }
        lastPresentation = presentation
        lastMenuBarTime = time
        activeMark.isHidden = time == nil
        statusItem?.button?.image =
            time.map { BrandArt.menuTime(top: $0.top, bottom: $0.bottom) }
            ?? (presentation == .active ? BrandArt.menuActive : BrandArt.menuIdle)
        let timeLabel = time.map { ", \($0.accessibilityLabel)" } ?? ""
        statusItem?.button?.setAccessibilityLabel(
            "Limitless: \(presentation?.title ?? "Setup required")\(timeLabel)")
    }

    #if DEBUG
        private func schedulePreviewTick() {
            previewTick?.cancel()
            guard model.presentation == .active, let remaining = model.protectionRemainingSeconds
            else { return }
            let delay = max(1, remaining - (ceil(remaining / 60) - 1) * 60)
            previewTick = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                guard let self else { return }
                if model.protectionRemainingSeconds == 0 {
                    await model.stopAll()
                } else {
                    refreshMenuBarTime()
                }
            }
        }
    #endif

    func applicationDidResignActive(_ notification: Notification) {
        if NSEvent.pressedMouseButtons & 1 != 0,
            statusButtonBounds()?.contains(NSEvent.mouseLocation) == true
        {
            return
        }
        popover.performClose(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusClickMonitors.forEach(NSEvent.removeMonitor)
    }

    func popoverDidShow(_ notification: Notification) {
        model.panelVisible = true
        let window = popover.contentViewController?.view.window
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(nil)
        NSApp.activate()
    }

    func popoverDidClose(_ notification: Notification) {
        model.optionsExpanded = false
        model.panelVisible = false
    }

    private func handleGlobalMouseEvent(_ event: NSEvent) {
        if popover.isShown, event.type == .leftMouseDown || event.type == .rightMouseDown,
            statusButtonBounds()?.contains(screenPoint(for: event)) != true
        {
            popover.performClose(nil)
        }
        trackStatusClick(event)
    }

    private func statusButtonBounds() -> NSRect? {
        guard let item = statusItem, item.isVisible, let button = item.button,
            let window = button.window, window.screen != nil
        else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func screenPoint(for event: NSEvent) -> NSPoint {
        event.window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow
    }

    private func trackStatusClick(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if event.type == .leftMouseDown {
            closesPanelOnStatusClick =
                !modifiers.contains(.command) && popover.isShown
                && statusButtonBounds()?.contains(screenPoint(for: event)) == true
        }
        if event.type == .leftMouseDown || modifiers != .command {
            commandClick.cancel()
        }
        guard modifiers == .command,
            event.type == .leftMouseDown || commandClick.isTracking,
            let bounds = statusButtonBounds()
        else { return }
        switch event.type {
        case .leftMouseDown:
            commandClick.begin(at: screenPoint(for: event), within: bounds)
        case .leftMouseDragged:
            commandClick.cancel()
        case .leftMouseUp:
            guard commandClick.finish(at: screenPoint(for: event), within: bounds),
                let button = statusItem?.button
            else { return }
            Task {
                await model.startFavorite()
                if model.presentation != .active, !popover.isShown { showPopover(from: button) }
            }
        default: break
        }
    }

    @objc private func clickStatusItem() {
        guard let button = statusItem?.button else { return }
        let event = NSApp.currentEvent
        defer { closesPanelOnStatusClick = false }
        if event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
        {
            popover.performClose(nil)
            actionsMenu().popUp(
                positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
        } else if event?.type == .leftMouseUp, event?.modifierFlags.contains(.command) == true {
            return
        } else if popover.isShown || (event?.type == .leftMouseUp && closesPanelOnStatusClick) {
            popover.performClose(nil)
        } else {
            showPopover(from: button)
        }
    }

    private func showPopover(from button: NSStatusBarButton) {
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func actionsMenu() -> NSMenu {
        let menu = NSMenu()
        menu.appearance = NSApp.effectiveAppearance
        let updates = NSMenuItem(
            title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)
        menu.addItem(.separator())
        let uninstall = NSMenuItem(
            title: "Uninstall Limitless…", action: #selector(uninstall), keyEquivalent: "")
        uninstall.target = self
        menu.addItem(uninstall)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Limitless", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    @objc private func quit() { NSApp.terminate(nil) }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(checkForUpdates) {
            return model.trustedBuild && !model.isPreview && !model.updating
        }
        return menuItem.action != #selector(uninstall)
            || (!model.updating && !model.sudoTouchIDBusy)
    }

    @objc private func checkForUpdates() {
        Task {
            let result = await model.checkForUpdates(manual: true)
            if result == true, model.canInstallAvailableUpdate(manual: true) {
                model.requestUpdate(manual: true)
                return
            }
            let alert = NSAlert()
            alert.messageText = result == true ? "Update available" : "Limitless updates"
            alert.informativeText =
                result == true
                ? model.updateInstallBlockMessage(manual: true)
                : result == false
                    ? "Limitless is up to date."
                    : model.updateMessage ?? "The next check is available later."
            alert.addButton(withTitle: "OK")
            NSApp.activate()
            alert.runModal()
        }
    }

    @objc private func uninstall() {
        guard removalWindow == nil else {
            removalWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        popover.performClose(nil)
        let alert = NSAlert()
        alert.messageText = "Uninstall Limitless?"
        alert.informativeText =
            "Ends all sessions and removes the helpers, login item and preferences. macOS may ask for separate administrator approvals. Then moves Limitless to the Trash. Running commands continue."
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        alert.buttons.first?.isEnabled = model.trustedBuild && !model.isPreview
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let progress = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 110),
            styleMask: [.titled], backing: .buffered, defer: false)
        progress.title = "Uninstalling Limitless"
        progress.isReleasedWhenClosed = false
        progress.contentView = NSHostingView(rootView: RemovalProgress(model: model))
        progress.center()
        progress.makeKeyAndOrderFront(nil)
        removalWindow = progress
        Task {
            while model.busy { try? await Task.sleep(for: .milliseconds(50)) }
            defer {
                progress.close()
                removalWindow = nil
            }
            let identity: SignedIdentity
            do {
                identity = try await SignedIdentity.current(
                    expectedIdentifier: LimitlessIdentity.application)
                _ = try await GitHubUpdate.currentInstalledApplication(identity: identity)
            } catch {
                progress.orderOut(nil)
                model.message =
                    "The matching signed Limitless.app could not be verified in Applications. Keep it installed there and retry."
                showRemovalError()
                return
            }
            guard await model.removeIntegration() else {
                progress.orderOut(nil)
                showRemovalError()
                return
            }
            let installedApp: URL
            do {
                installedApp = try await GitHubUpdate.currentInstalledApplication(
                    identity: identity)
            } catch {
                progress.orderOut(nil)
                model.message =
                    "The helpers were removed, but the matching signed app in Applications could not be verified. Keep Limitless open and inspect the installation."
                showRemovalError()
                return
            }
            do {
                _ = try await NSWorkspace.shared.recycle([installedApp])
                progress.orderOut(nil)
                if model.removalLeftUpdateSettings { showRemovalError() }
                NSApp.terminate(nil)
            } catch {
                progress.orderOut(nil)
                let cleanup = model.message ?? "System cleanup finished."
                model.message =
                    "\(cleanup) macOS could not move the app to the Trash. \(error.localizedDescription)"
                NSWorkspace.shared.activateFileViewerSelecting([installedApp])
                showRemovalError()
            }
        }
    }

    private func showRemovalError() {
        let alert = NSAlert()
        alert.messageText = "Uninstall incomplete"
        alert.informativeText = model.message ?? "Keep Limitless installed and retry."
        alert.addButton(withTitle: "OK")
        NSApp.activate()
        alert.runModal()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if model.removalComplete { return .terminateNow }
        guard !terminating else { return .terminateCancel }
        let quitEvent = NSAppleEventManager.shared().currentAppleEvent
        let systemRestart = Self.isSystemRestart(quitEvent)
        terminating = true
        Task {
            if !model.isPreview && systemRestart {
                await model.refresh()
                if Self.shouldDeferRestart(
                    presentation: model.presentation, sessions: model.status?.sessions ?? [],
                    remaining: model.remainingSeconds)
                {
                    model.message = "Restart postponed. Stop Limitless before restarting your Mac."
                    terminating = false
                    sender.reply(toApplicationShouldTerminate: false)
                    return
                }
            }
            let restored = await model.prepareToQuit(systemRestart: systemRestart)
            var shouldQuit = restored
            if !restored {
                let alert = NSAlert()
                alert.messageText = "Power restoration is not confirmed"
                alert.informativeText =
                    "Keep Limitless open to retry. Quitting leaves the current power state unresolved."
                alert.addButton(withTitle: "Keep Open")
                alert.addButton(withTitle: "Quit Anyway")
                shouldQuit = alert.runModal() == .alertSecondButtonReturn
            }
            terminating = false
            sender.reply(toApplicationShouldTerminate: shouldQuit)
        }
        return .terminateLater
    }

    static func isSystemRestart(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event, event.eventClass == AEEventClass(kCoreEventClass),
            event.eventID == AEEventID(kAEQuitApplication),
            let reason = event.paramDescriptor(forKeyword: AEKeyword(kAEQuitReason))?.enumCodeValue
        else { return false }
        return reason == OSType(kAERestart) || reason == OSType(kAEShutDown)
    }

    static func shouldDeferRestart(
        presentation: PowerPresentation?, sessions: [SessionSummary],
        remaining: (SessionSummary) -> TimeInterval?
    ) -> Bool {
        presentation == .active
            && sessions.contains {
                $0.kind == .manual && $0.suspension == nil && (remaining($0).map { $0 > 0 } ?? true)
            }
    }
}

private struct RemovalProgress: View {
    @Bindable var model: AppModel
    var body: some View {
        ProgressView { Text(model.removalStep ?? "Preparing…") }
            .padding(24).frame(width: 340, height: 110)
    }
}

private final class StatusMark: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

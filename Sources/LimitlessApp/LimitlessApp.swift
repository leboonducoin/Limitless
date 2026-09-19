import AppKit
import Darwin
import Observation
import SwiftUI

@main
enum LimitlessApp {
    @MainActor static func main() {
        guard geteuid() != 0 else { exit(1) }
        if CommandLine.arguments.contains("--prepare-uninstall") {
            let options = Array(CommandLine.arguments.dropFirst())
            guard
                options == ["--prepare-uninstall"]
                    || options == ["--prepare-uninstall", "--erase-preferences"]
            else {
                FileHandle.standardError.write(
                    Data("Usage: LimitlessApp --prepare-uninstall [--erase-preferences]\n".utf8))
                exit(64)
            }
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let model: AppModel
    private var previewWindow: NSWindow?
    private var terminating = false
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()

    override init() {
        #if DEBUG
            if let index = CommandLine.arguments.firstIndex(of: "--preview"),
                index + 1 < CommandLine.arguments.count
            {
                model = AppModel.preview(CommandLine.arguments[index + 1])
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
        if !CommandLine.arguments.contains("--prepare-uninstall") { installStatusItem() }
        Task {
            await model.prepareForLaunch()
            if CommandLine.arguments.contains("--prepare-uninstall") {
                let success = await model.removeIntegration()
                let output = (model.message ?? "Removal was not confirmed.") + "\n"
                (success ? FileHandle.standardOutput : FileHandle.standardError).write(
                    Data(output.utf8))
                exit(success ? 0 : 1)
            }
            model.beginMonitoring()
        }
        #if DEBUG
            if model.isPreview {
                if CommandLine.arguments.contains("--light") {
                    NSApp.appearance = NSAppearance(
                        named: CommandLine.arguments.contains("--contrast")
                            ? .accessibilityHighContrastAqua : .aqua)
                }
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 360, height: 620),
                    styleMask: [.titled, .closable], backing: .buffered, defer: false)
                window.title = "Limitless — Read-only preview"
                window.contentView = NSHostingView(rootView: MenuPanel(model: model))
                window.center()
                window.makeKeyAndOrderFront(nil)
                NSApp.activate()
                previewWindow = window
            }
        #endif
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        item.button?.target = self
        item.button?.action = #selector(clickStatusItem)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.setAccessibilityHelp("Click to open. Right-click for Quit and Uninstall.")
        popover.behavior = .transient
        popover.animates = false
        let host = NSHostingController(rootView: MenuPanel(model: model))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        // Keep the native application menu and Command-Q available to keyboard users.
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
            statusItem?.button?.image =
                model.presentation == .active ? BrandArt.menuActive : BrandArt.menuIdle
            statusItem?.button?.setAccessibilityLabel(
                "Limitless: \(model.presentation?.title ?? "Setup required")")
        } onChange: { [weak self] in
            Task { @MainActor in self?.observePresentation() }
        }
    }

    @objc private func clickStatusItem() {
        guard let button = statusItem?.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp
            || NSApp.currentEvent?.modifierFlags.contains(.control) == true
        {
            popover.performClose(nil)
            actionsMenu().popUp(
                positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate()
        }
    }

    private func actionsMenu() -> NSMenu {
        let menu = NSMenu()
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

    @objc private func uninstall() {
        guard !model.busy else { return }
        popover.performClose(nil)
        let alert = NSAlert()
        alert.messageText = "Uninstall Limitless?"
        alert.informativeText =
            "Ends all sessions and removes the helper, login item and preferences. Then moves Limitless to the Trash. Running commands continue."
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.isEnabled = model.trustedBuild && !model.isPreview
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task {
            guard await model.removeIntegration() else {
                showRemovalError()
                return
            }
            do {
                try FileManager.default.trashItem(at: Bundle.main.bundleURL, resultingItemURL: nil)
                NSApp.terminate(nil)
            } catch {
                model.message =
                    "Setup and preferences removed. Move Limitless from Applications to the Trash."
                showRemovalError()
            }
        }
    }

    private func showRemovalError() {
        let alert = NSAlert()
        alert.messageText = "Uninstall incomplete"
        alert.informativeText = model.message ?? "Keep Limitless installed and retry."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateCancel }
        terminating = true
        Task {
            let restored = await model.prepareToQuit()
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
}

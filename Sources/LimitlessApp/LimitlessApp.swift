import AppKit
import Darwin
import SwiftUI

@main
struct LimitlessApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
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
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPanel(model: delegate.model)
        } label: {
            Image(
                nsImage: delegate.model.presentation == .active
                    ? BrandArt.menuActive : BrandArt.menuIdle
            )
            .accessibilityLabel(
                "Limitless: \(delegate.model.presentation?.title ?? "Setup required")")
        }
        .menuBarExtraStyle(.window)
        Settings { SettingsView(model: delegate.model) }
            .defaultSize(width: 520, height: 640)
            .windowResizability(.contentMinSize)
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let model: AppModel
    private var previewWindow: NSWindow?
    private var terminating = false

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
        if CommandLine.arguments.contains("--prepare-uninstall") {
            Task {
                let success = await model.removeIntegration(
                    erasePreferences: CommandLine.arguments.contains("--erase-preferences"))
                let output = (model.message ?? "Removal was not confirmed.") + "\n"
                (success ? FileHandle.standardOutput : FileHandle.standardError).write(
                    Data(output.utf8))
                exit(success ? 0 : 1)
            }
            return
        }
        model.beginMonitoring()
        #if DEBUG
            if model.isPreview {
                if CommandLine.arguments.contains("--light") {
                    NSApp.appearance = NSAppearance(
                        named: CommandLine.arguments.contains("--contrast")
                            ? .accessibilityHighContrastAqua : .aqua)
                }
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 360, height: 540),
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

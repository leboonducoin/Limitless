import AppKit
import LimitlessCore
import ServiceManagement
import SwiftUI

struct MenuPanel: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Image(nsImage: BrandArt.appIcon(size: 64)).resizable().frame(width: 36, height: 36)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Limitless").font(.headline)
                    Text("A little more time.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if model.isPreview {
                    Text("PREVIEW").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        .help("Read-only preview. No system settings are changed.")
                }
            }
            statusOverview
            Divider()
            if model.isPreview || model.helperStatus == .enabled {
                sessionControls
            } else {
                setupControls
            }
            if let message = model.message {
                Text(message).font(.callout).foregroundStyle(.secondary).fixedSize(
                    horizontal: false, vertical: true)
            }
            Divider()
            HStack {
                SettingsLink { Label("Settings", systemImage: "gearshape") }
                    .keyboardShortcut(",", modifiers: .command)
                Spacer()
                Menu {
                    Button("About Limitless") { NSApp.orderFrontStandardAboutPanel() }
                    Button("Quit Limitless") { NSApp.terminate(nil) }.keyboardShortcut("q")
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("More actions")
            }
            .buttonStyle(.plain)
            .font(.callout)
        }
        .padding(20)
        .frame(width: 360)
        .background {
            if reduceTransparency || contrast == .increased {
                Color(nsColor: .windowBackgroundColor)
            }
        }
        .transaction { transaction in
            // Native controls provide feedback; asynchronous state reads never animate the layout.
            transaction.animation = nil
        }
    }

    @ViewBuilder private var statusOverview: some View {
        if let presentation = model.presentation {
            VStack(alignment: .leading, spacing: 8) {
                Label(presentation.title, systemImage: presentation.symbol).font(
                    .title3.weight(.semibold))
                Text(model.status?.sleep.fault?.guidance ?? presentation.detail)
                    .font(.callout).foregroundStyle(.secondary).fixedSize(
                        horizontal: false, vertical: true)
                if let status = model.status {
                    HStack(spacing: 12) {
                        Label(status.power.source.label, systemImage: status.power.source.symbol)
                        if case .available(let percent, _) = status.power.battery {
                            Text("\(percent)%").monospacedDigit()
                        }
                    }.font(.caption).foregroundStyle(.secondary)
                        .accessibilityElement(children: .combine)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    model.connectionError == nil
                        ? "Make room for your work" : "Connection unavailable",
                    systemImage: model.connectionError == nil
                        ? "moon.zzz" : "exclamationmark.triangle"
                )
                .font(.title3.weight(.semibold))
                Text(
                    model.connectionError
                        ?? "Keep your Mac awake for the time you choose, within your limits."
                )
                .font(.callout).foregroundStyle(.secondary).fixedSize(
                    horizontal: false, vertical: true)
                if model.connectionError != nil {
                    Button("Reconnect") { Task { await model.refresh() } }.disabled(model.busy)
                }
            }
        }
    }

    private var sessionControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.status?.sleep.fault != nil || model.presentation == .attention {
                if model.status?.sleep.ownsGlobalHold == true {
                    Button("Retry restoration") { Task { await model.retryRestoration() } }
                        .disabled(!model.canControl || model.busy)
                } else {
                    Button("Rearm Limitless") { Task { await model.rearm() } }
                        .disabled(!model.canControl || model.busy)
                }
            }
            if let session = model.ownSession {
                HStack {
                    Text("Your session").fontWeight(.medium)
                    Spacer()
                    if let remaining = session.remainingSeconds {
                        Text(
                            Duration.seconds(remaining).formatted(
                                .units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
                        )
                        .monospacedDigit().foregroundStyle(.secondary)
                    } else {
                        Text("No time limit").foregroundStyle(.secondary)
                    }
                }.font(.callout)
                Button {
                    Task { await model.stopManual() }
                } label: {
                    Label(model.busy ? "Updating…" : "End my session", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }.controlSize(.large).buttonStyle(.bordered)
                    .disabled(!model.canControl || model.busy)
            } else {
                StopEditor(model: model)
                startButton.disabled(
                    !model.canControl || model.busy || model.status?.sleep.fault != nil)
            }
            HStack {
                Text(
                    "\((model.status?.policy.mode ?? model.draft.mode).label) · \(model.status?.policy.batteryFloor ?? model.draft.batteryFloor)% reserve"
                )
                Spacer()
            }.font(.caption).foregroundStyle(.secondary)
            if model.status?.policy.batteryFloor == 0 {
                Label("Custom battery protection is off.", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.primary)
            }
            HStack {
                Label(
                    "\(model.taskCount) tracked \(model.taskCount == 1 ? "task" : "tasks")",
                    systemImage: "terminal")
                Spacer()
                if (model.status?.sessions.count ?? 0) > 0 {
                    Button("Stop all") { Task { await model.stopAll() } }
                        .disabled(!model.canControl || model.busy)
                }
            }.font(.callout)
            Text("Closed-lid support depends on your Mac and macOS.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var startButton: some View {
        let button = Button {
            Task { await model.startManual() }
        } label: {
            Label(model.busy ? "Verifying…" : "Keep awake", systemImage: "power")
                .frame(maxWidth: .infinity)
        }.controlSize(.large)
        if reduceTransparency || contrast == .increased {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.glassProminent)
        }
    }

    private var setupControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !model.trustedBuild {
                Text("Development build").font(.callout.weight(.semibold))
                Text(
                    "Power controls need a signed installation. You can inspect the interface and its settings here."
                )
                .font(.callout).foregroundStyle(.secondary)
            } else if model.helperStatus == .requiresApproval {
                Text("Approve Limitless in Login Items & Extensions to enable power controls.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Open System Settings") { model.openLoginSettings() }
            } else {
                Text(
                    "macOS will ask an administrator to approve the power helper. Limitless never stores a password."
                )
                .font(.callout).foregroundStyle(.secondary)
                Button("Enable Limitless") { Task { await model.registerHelper() } }
                    .buttonStyle(.borderedProminent).disabled(model.busy)
            }
        }
    }
}

private struct StopEditor: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Stop", selection: $model.stopChoice) {
                Text("No time limit").tag(StopChoice.unlimited)
                ForEach(SessionEnd.presetMinutes, id: \.self) { minutes in
                    Text(
                        minutes < 60
                            ? "After \(minutes) minutes"
                            : "After \(minutes / 60) \(minutes == 60 ? "hour" : "hours")"
                    )
                    .tag(StopChoice.preset(minutes))
                }
                Divider()
                Text("Custom duration…").tag(StopChoice.custom)
                Text("At a date & time…").tag(StopChoice.date)
                Text("When a process ends…").tag(StopChoice.process)
            }
            .pickerStyle(.menu)
            switch model.stopChoice {
            case .custom:
                HStack {
                    TextField("Duration", value: $model.customDuration, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Duration")
                    Picker("Unit", selection: $model.durationUnit) {
                        ForEach(DurationUnit.allCases) { unit in Text(unit.rawValue).tag(unit) }
                    }.labelsHidden().fixedSize()
                }
            case .date:
                DatePicker(
                    "End", selection: $model.stopDate, displayedComponents: [.date, .hourAndMinute])
            case .process:
                TextField("Process ID", text: $model.processID).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Process ID")
                    .accessibilityHint(
                        "The process must belong to you. Find its PID in Activity Monitor.")
                Text("Use the PID from Activity Monitor. The process is observed, never stopped.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            case .unlimited, .preset: EmptyView()
            }
        }
    }
}

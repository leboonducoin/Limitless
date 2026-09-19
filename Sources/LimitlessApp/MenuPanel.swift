import AppKit
import LimitlessCore
import SwiftUI

struct MenuPanel: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(nsImage: BrandArt.appIcon(size: 64)).resizable()
                            .frame(width: 32, height: 32).accessibilityHidden(true)
                        Text("Limitless").font(.headline)
                        Spacer()
                        if model.isPreview {
                            Text("PREVIEW").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    statusOverview
                    if model.removalInProgress {
                        Text("Uninstall pending. Right-click the icon to retry.").font(.callout)
                    }
                    Divider()
                    if model.isPreview || model.helperStatus == .enabled {
                        sessionControls
                    } else {
                        setupControls
                    }
                    Divider()
                    SettingsView(model: model)
                    if let message = model.message {
                        Text(message).font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }.padding(20)
            }
            .scrollBounceBehavior(.basedOnSize)
            Divider()
            Text(
                "Limitless \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev") · © 2026 Arthur Barreau · MIT"
            )
            .font(.caption2).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
        }
        .frame(width: 360, height: panelHeight)
        .background {
            if reduceTransparency || contrast == .increased {
                Color(nsColor: .windowBackgroundColor)
            }
        }
        .transaction { $0.animation = nil }
    }

    private var panelHeight: CGFloat {
        var height: CGFloat = 490
        if model.ownSession == nil {
            if model.stopChoice == .process { height += 180 }
            if model.stopChoice == .custom || model.stopChoice == .date { height += 40 }
        }
        if model.draft.limitsDuration { height += 36 }
        if model.draftChanged { height += 36 }
        if model.message != nil || model.connectionError != nil || model.status?.sleep.fault != nil
        {
            height += 60
        }
        return min(height, (NSScreen.main?.visibleFrame.height ?? 740) - 40)
    }

    private var statusOverview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    model.presentation?.title ?? "Setup required",
                    systemImage: model.presentation?.symbol ?? "moon.zzz"
                )
                .font(.callout.weight(.semibold))
                Spacer()
                if case .available(let percent, _) = model.status?.power.battery {
                    Label(
                        "\(percent)%",
                        systemImage: model.status?.power.source.symbol ?? "battery.75percent"
                    )
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            if let error = model.connectionError ?? model.status?.sleep.fault?.guidance {
                Text(error).font(.caption).fixedSize(horizontal: false, vertical: true)
            }
            if model.connectionError != nil {
                Button("Reconnect") { Task { await model.refresh() } }.disabled(model.busy)
            }
        }
    }

    private var sessionControls: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    Text("Current session")
                    Spacer()
                    if let remaining = session.remainingSeconds {
                        Text(
                            Duration.seconds(remaining).formatted(
                                .units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
                        )
                        .monospacedDigit()
                    } else {
                        Text("No limit")
                    }
                }.font(.callout).foregroundStyle(.secondary)
                Button {
                    Task { await model.stopManual() }
                } label: {
                    Label(model.busy ? "Updating…" : "Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large).buttonStyle(.bordered)
                .disabled(!model.canControl || model.busy)
            } else {
                StopEditor(model: model)
                startButton.disabled(
                    !model.canControl || model.busy || model.status?.sleep.fault != nil)
            }
            if model.showsTaskCount || (model.status?.sessions.count ?? 0) > 0 {
                HStack {
                    if model.showsTaskCount {
                        Label(
                            "\(model.taskCount) tracked \(model.taskCount == 1 ? "task" : "tasks")",
                            systemImage: "terminal")
                    }
                    Spacer()
                    if (model.status?.sessions.count ?? 0) > 0 {
                        Button("Stop all") { Task { await model.stopAll() } }
                            .disabled(!model.canControl || model.busy)
                    }
                }.font(.caption)
            }
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
        VStack(alignment: .leading, spacing: 10) {
            if model.buildTrust == .checking {
                ProgressView("Preparing…").controlSize(.small)
            } else if model.removalComplete {
                Text("Ready to remove").font(.callout)
            } else if !model.trustedBuild {
                Text("Development build — power controls unavailable.").font(.callout)
            } else if model.helperStatus == .requiresApproval {
                Button("Approve in System Settings") { model.openLoginSettings() }
            } else {
                Button("Enable Limitless") { Task { await model.registerHelper() } }
                    .buttonStyle(.borderedProminent).disabled(model.busy)
                Text("Requires macOS administrator approval.").font(.caption).foregroundStyle(
                    .secondary)
            }
        }.fixedSize(horizontal: false, vertical: true)
    }
}

private struct StopEditor: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Stop", selection: $model.stopChoice) {
                ForEach(SessionEnd.presetMinutes, id: \.self) { minutes in
                    Text(minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h")
                        .tag(StopChoice.preset(minutes))
                }
                Text("No limit").tag(StopChoice.unlimited)
                Divider()
                Text("Custom duration…").tag(StopChoice.custom)
                Text("Date & time…").tag(StopChoice.date)
                Text("When a process ends…").tag(StopChoice.process)
            }.pickerStyle(.menu)
            if model.stopChoice != .unlimited {
                Button("No limit") { model.stopChoice = .unlimited }
                    .controlSize(.small)
            }
            switch model.stopChoice {
            case .custom:
                HStack {
                    TextField("Duration", value: $model.customDuration, format: .number)
                        .textFieldStyle(.roundedBorder).accessibilityLabel("Duration")
                    Picker("Unit", selection: $model.durationUnit) {
                        ForEach(DurationUnit.allCases) { unit in Text(unit.rawValue).tag(unit) }
                    }.labelsHidden().fixedSize()
                }
            case .date:
                DatePicker(
                    "End", selection: $model.stopDate, displayedComponents: [.date, .hourAndMinute])
            case .process:
                processPicker.onAppear { model.refreshProcesses() }
            case .unlimited, .preset: EmptyView()
            }
        }
    }

    private var processPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Search processes", text: $model.processSearch)
                    .textFieldStyle(.roundedBorder).accessibilityLabel("Search processes")
                Button {
                    model.refreshProcesses()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }.accessibilityLabel("Refresh processes").help("Refresh processes")
            }
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(
                        model.processes.filter {
                            model.processSearch.isEmpty
                                || $0.name.localizedStandardContains(model.processSearch)
                                || String($0.id).contains(model.processSearch)
                        }
                    ) { process in
                        Button {
                            model.selectProcess(process)
                        } label: {
                            HStack {
                                Text(process.name).lineLimit(1)
                                Spacer()
                                Text(String(process.id)).monospacedDigit().foregroundStyle(
                                    .secondary)
                                Image(
                                    systemName: model.processID == String(process.id)
                                        ? "checkmark.circle.fill" : "circle")
                            }.padding(5).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(process.name), PID \(process.id)")
                        .accessibilityAddTraits(
                            model.processID == String(process.id) ? [.isSelected] : [])
                    }
                }
            }
            .frame(height: 120)
            .overlay {
                if model.processes.isEmpty {
                    Text(model.processListError ?? "No processes available")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("PID").font(.callout)
                TextField("Process ID", text: $model.processID)
                    .textFieldStyle(.roundedBorder).accessibilityLabel("Process ID")
            }
        }
    }
}

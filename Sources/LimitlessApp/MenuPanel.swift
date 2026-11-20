import AppKit
import LimitlessCore
import LimitlessSystem
import SwiftUI

struct MenuPanel: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    private static let logo = BrandArt.appIcon(size: 64)

    init(model: AppModel) {
        self.model = model
    }

    var body: some View {
        if #available(macOS 15, *) {
            panel.allowsWindowActivationEvents()
        } else {
            panel
        }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            panelContent.fixedSize(horizontal: false, vertical: true)
            Divider()
            HStack(spacing: 8) {
                HStack(spacing: 0) {
                    Text(
                        "\(LimitlessIdentity.version) · © 2026 "
                    )
                    Link(
                        "Arthur Barreau",
                        destination: URL(string: "https://www.linkedin.com/in/arthurbarreau/")!
                    )
                    .foregroundStyle(Color(nsColor: .linkColor))
                    .accessibilityLabel("Arthur Barreau on LinkedIn").help(
                        "Arthur Barreau on LinkedIn")
                    Text(" · MIT")
                }.font(.caption2).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Link(destination: URL(string: "https://github.com/leboonducoin/Limitless")!) {
                    Image(nsImage: BrandArt.github).frame(width: 20, height: 20)
                }
                .accessibilityLabel("Limitless on GitHub").help("Limitless on GitHub")
            }.padding(.horizontal, 16).padding(.vertical, 8)
        }
        .frame(width: 340)
        .background {
            if reduceTransparency || contrast == .increased {
                Color(nsColor: .windowBackgroundColor)
            }
        }
        .transaction { $0.animation = nil }
    }

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(nsImage: Self.logo).resizable()
                    .frame(width: 32, height: 32).accessibilityHidden(true)
                Text("Limitless").font(.system(size: 21, weight: .semibold))
                Spacer()
                if model.isPreview {
                    Text("Preview").font(.caption).foregroundStyle(.secondary)
                }
            }
            statusOverview
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            if model.removalInProgress {
                Text("Uninstall pending. Right-click the icon to retry.").font(.callout)
            }
            if model.showsPowerControls {
                sessionControls
            } else {
                setupControls
            }
            if let message = model.message {
                Text(message).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                Button {
                    model.optionsExpanded.toggle()
                } label: {
                    HStack {
                        Label("Options", systemImage: "slider.horizontal.3")
                        Spacer()
                        Image(systemName: model.optionsExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(model.optionsExpanded ? "Expanded" : "Collapsed")
                if model.optionsExpanded {
                    ScrollView {
                        SettingsView(model: model)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(
                        height: Self.optionsHeight(screenHeight: NSScreen.main?.visibleFrame.height)
                    )
                }
            }
        }
        .padding([.top, .horizontal], 18)
        .padding(.bottom, 8)
        .onChange(of: model.draft) { model.policyEdited() }
    }

    static func optionsHeight(screenHeight: CGFloat?) -> CGFloat {
        min(250, (screenHeight ?? 750) / 3)
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
                    .font(.callout).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            if let error = model.connectionError ?? model.status?.sleep.fault?.guidance {
                Text(error).font(.caption).fixedSize(horizontal: false, vertical: true)
            }
            if model.status?.thermal == .serious || model.status?.thermal == .critical {
                Label("High thermal load", systemImage: "thermometer.high")
                    .font(.caption).foregroundStyle(.orange)
            }
            if let lid = model.lidDisplayState.label {
                Label(lid, systemImage: "laptopcomputer").font(.caption)
            }
            if let audio = model.audioMessage {
                Label(audio, systemImage: "speaker.slash").font(.caption)
            }
            if let hotspot = model.hotspotMessage {
                Label(hotspot, systemImage: "wifi.exclamationmark").font(.caption)
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
            if model.status?.sessions.isEmpty == false {
                HStack {
                    Text("Current session")
                    Spacer()
                    TimelineView(.animation(minimumInterval: 1, paused: !model.panelVisible)) { _ in
                        Text(MenuBarTime.panelDuration(model.protectionRemainingSeconds))
                            .monospacedDigit()
                    }
                }.font(.callout).foregroundStyle(.secondary)
            }
            if model.status?.sessions.isEmpty != false || model.hasOnlyAutomatedSessions {
                StopEditor(model: model)
                startButton.disabled(!model.canStartManualSession)
                if model.status?.sessions.isEmpty == true, let outcome = model.lastSessionMessage,
                    model.batteryNotice == nil
                {
                    Text(outcome).font(.caption).foregroundStyle(.secondary)
                }
            }
            if (model.status?.sessions.count ?? 0) > 0 {
                HStack(spacing: 8) {
                    Button {
                        Task { await model.stopAll() }
                    } label: {
                        Label(
                            model.busy && !model.extendingSession ? "Updating…" : "Stop",
                            systemImage: "stop.fill"
                        ).frame(maxWidth: .infinity)
                    }
                    .help("End all Limitless sessions; running commands continue.")
                    .keyboardShortcut(".", modifiers: .command)
                    .controlSize(.large).buttonStyle(.bordered)
                    .disabled(
                        (!model.canControl && !model.isPreview) || model.stoppingSessions
                            || (model.busy && !model.extendingSession))
                    if model.ownSession != nil {
                        Button {
                            Task { await model.extendSession() }
                        } label: {
                            Image(systemName: "plus").font(.body.weight(.semibold))
                                .frame(width: 28, height: 28).contentShape(Circle())
                        }
                        .buttonStyle(.bordered).buttonBorderShape(.circle)
                        .keyboardShortcut("+", modifiers: .command)
                        .accessibilityLabel("Add 15 minutes").help("Add 15 minutes")
                        .disabled(
                            (!model.canControl && !model.isPreview) || !model.canExtendSession
                                || (model.busy && !model.extendingSession))
                    }
                }
            }
            if model.showsTaskCount {
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        "\(model.taskCount) tracked \(model.taskCount == 1 ? "task" : "tasks")",
                        systemImage: "terminal"
                    )
                    if let sessions = model.status?.sessions {
                        let providers = Set(sessions.compactMap(\.agent))
                        if !providers.isEmpty {
                            Text(
                                AgentProvider.allCases.filter(providers.contains).map(\.displayName)
                                    .formatted(.list(type: .and))
                            )
                            .foregroundStyle(.secondary)
                        }
                    }
                }.font(.caption)
            }
            if let processes = model.watchedProcesses, !processes.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(processes, id: \.pid) { process in
                            Text("Waiting for PID \(String(process.pid))")
                                .font(.caption).monospacedDigit()
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: CGFloat(min(processes.count, 4)) * 18)
                .scrollBounceBehavior(.basedOnSize)
            }
            if let notice = model.batteryNotice {
                Label {
                    Text(notice).foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
                .font(.caption).fixedSize(horizontal: false, vertical: true)
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
            .keyboardShortcut(.return, modifiers: .command)
        if reduceTransparency || contrast == .increased {
            button.buttonStyle(.borderedProminent)
        } else if #available(macOS 26, *) {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.borderedProminent)
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
                    .disabled(model.isPreview)
            } else if model.helperStatus == .enabled {
                if model.connectionError == nil && !model.removalInProgress {
                    ProgressView("Connecting…").controlSize(.small)
                }
            } else {
                Button("Enable Limitless") { Task { await model.registerHelper() } }
                    .buttonStyle(.borderedProminent).disabled(model.busy || model.isPreview)
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
                                    systemName: model.isSelected(process)
                                        ? "checkmark.circle.fill" : "circle")
                            }.padding(5).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(process.name), PID \(process.id)")
                        .accessibilityAddTraits(
                            model.isSelected(process) ? [.isSelected] : [])
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
                Text("PIDs").font(.callout)
                TextField("697;660;9931", text: $model.processID)
                    .textFieldStyle(.roundedBorder).accessibilityLabel(
                        "Process IDs, separated by semicolons")
            }
        }
    }
}

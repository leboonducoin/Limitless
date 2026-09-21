import LimitlessCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    private var batteryInput = SwiftUI.State<String>(wrappedValue: "")
    @FocusState private var batteryFocused: Bool

    private static let batteryFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.allowsFloats = false
        formatter.usesGroupingSeparator = false
        formatter.minimum = NSNumber(value: UserPolicy.batteryFloorRange.lowerBound)
        formatter.maximum = NSNumber(value: UserPolicy.batteryFloorRange.upperBound)
        return formatter
    }()

    init(model: AppModel) {
        self.model = model
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.showsPowerControls {
                Group {
                    if model.showsPowerSource {
                        Picker("Power source", selection: $model.draft.mode) {
                            ForEach(PowerMode.allCases, id: \.self) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Power source")
                    }
                    if model.showsBatteryLimit {
                        HStack {
                            Text("Battery reserved limit")
                            Spacer()
                            TextField("Percent", text: batteryInput.projectedValue)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 44)
                                .accessibilityLabel("Battery reserved limit, percent")
                                .focused($batteryFocused)
                                .onSubmit { applyBatteryInput() }
                                .onChange(of: batteryFocused) {
                                    if !batteryFocused { applyBatteryInput() }
                                }
                                .onChange(of: model.draft.batteryFloor, initial: true) {
                                    batteryInput.wrappedValue =
                                        Self.batteryFormatter.string(
                                            from: NSNumber(value: model.draft.batteryFloor)) ?? ""
                                }
                                .onDisappear { applyBatteryInput() }
                            Text("%")
                            Stepper(
                                "Battery reserved limit", value: $model.draft.batteryFloor,
                                in: UserPolicy.batteryFloorRange, step: 1
                            )
                            .labelsHidden().fixedSize()
                            .accessibilityValue("\(model.draft.batteryFloor)%")
                        }
                        .monospacedDigit()
                        if model.draft.batteryFloor == 0 {
                            Label(
                                "Battery protection is off", systemImage: "exclamationmark.triangle"
                            )
                            .font(.caption)
                        }
                    }
                    if model.stopChoice == .process {
                        Toggle("Session time limit", isOn: $model.draft.limitsDuration)
                        if model.draft.limitsDuration {
                            HStack {
                                Text("Maximum minutes")
                                TextField(
                                    "Minutes", value: $model.draft.maximumMinutes, format: .number
                                )
                                .textFieldStyle(.roundedBorder).accessibilityLabel(
                                    "Maximum minutes"
                                )
                                .frame(width: 90)
                            }
                        }
                    }
                }.disabled(!model.canControl && !model.isPreview)
                if model.showsPowerSource || model.stopChoice == .process { Divider() }
                HStack {
                    Toggle(
                        "Allow CLI & AI tasks",
                        isOn: Binding(
                            get: { model.status?.policy.allowsAutomation ?? false },
                            set: { enabled in Task { await model.setAutomation(enabled) } })
                    )
                    .disabled((!model.canControl && !model.isPreview) || model.busy)
                    Link(
                        destination: URL(
                            string:
                                "https://github.com/leboonducoin/Limitless/blob/main/docs/cli.md#ai-agent-setup"
                        )!
                    ) {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("Set up CLI and AI integration")
                    .help("Set up CLI and AI integration")
                }
            }
            if model.showsSudoTouchID {
                Toggle(
                    "Touch ID for sudo",
                    isOn: Binding(
                        get: {
                            model.status?.sudoTouchID == .enabled
                                || model.status?.sudoTouchID == .external
                        },
                        set: { enabled in
                            if enabled || model.status?.sudoTouchID == .external {
                                model.pendingSudoTouchID = enabled
                            } else {
                                Task { await model.setSudoTouchID(false) }
                            }
                        })
                )
                .disabled(
                    (!model.canControl && !model.isPreview) || model.busy
                        || model.status?.sudoTouchID == .unavailable
                )
                .help("Use Touch ID for sudo commands on this Mac.")
                .alert(
                    model.pendingSudoTouchID == false
                        ? "Disable Touch ID for sudo?" : "Enable Touch ID for sudo?",
                    isPresented: Binding(
                        get: { model.pendingSudoTouchID != nil },
                        set: { if !$0 { model.pendingSudoTouchID = nil } }),
                    presenting: model.pendingSudoTouchID
                ) { enabled in
                    Button(enabled ? "Enable" : "Disable", role: enabled ? nil : .destructive) {
                        Task { await model.setSudoTouchID(enabled) }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { enabled in
                    Text(
                        enabled
                            ? "Applies to sudo commands across this Mac. Your password remains available. Limitless’s administrator prompt is unchanged."
                            : "This setting was enabled outside Limitless. Sudo commands across this Mac will require your password instead."
                    )
                }
            }
            Toggle(
                "Launch at login",
                isOn: Binding(
                    get: { model.loginStatus == .enabled },
                    set: { enabled in Task { await model.setLaunchAtLogin(enabled) } })
            )
            .disabled(
                (!model.trustedBuild && !model.isPreview) || model.busy || model.removalComplete)
            if model.loginStatus == .requiresApproval {
                Button("Approve in System Settings") { model.openLoginSettings() }.disabled(
                    model.isPreview)
            }
            if model.showsPowerControls {
                HStack {
                    Toggle("Automatic updates", isOn: $model.automaticUpdates)
                        .disabled((!model.trustedBuild && !model.isPreview) || model.updating)
                    if let update = model.availableUpdate, !model.automaticUpdates {
                        Button("Update") { model.requestUpdate() }
                            .help("Install Limitless \(update.version)")
                            .disabled(model.updating || model.busy)
                    }
                }
                if let message = model.updateMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .font(.callout).toggleStyle(.switch).controlSize(.small)
        .onChange(of: model.draft) { model.policyEdited() }
    }

    private func applyBatteryInput() {
        if let number = Self.batteryFormatter.number(from: batteryInput.wrappedValue) {
            model.draft.batteryFloor = number.intValue
        }
        batteryInput.wrappedValue =
            Self.batteryFormatter.string(
                from: NSNumber(value: model.draft.batteryFloor)) ?? ""
    }
}

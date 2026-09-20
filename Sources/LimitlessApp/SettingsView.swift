import LimitlessCore
import ServiceManagement
import SwiftUI

/// Essential preferences live in the popover, using the same validated policy draft.
struct SettingsView: View {
    @Bindable var model: AppModel

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
                        Stepper(value: $model.draft.batteryFloor, in: 0...50, step: 1) {
                            LabeledContent(
                                "Battery reserved limit", value: "\(model.draft.batteryFloor)%"
                            )
                            .monospacedDigit()
                        }
                        .accessibilityLabel("Battery reserved limit")
                        .accessibilityValue("\(model.draft.batteryFloor)%")
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
                    .disabled(!model.canControl || model.busy)
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
            Toggle(
                "Launch at login",
                isOn: Binding(
                    get: { model.loginStatus == .enabled },
                    set: { enabled in Task { await model.setLaunchAtLogin(enabled) } })
            )
            .disabled(!model.trustedBuild || model.isPreview || model.busy || model.removalComplete)
            if model.loginStatus == .requiresApproval {
                Button("Approve in System Settings") { model.openLoginSettings() }.disabled(
                    model.isPreview)
            }
            if model.showsPowerControls {
                HStack {
                    Toggle("Automatic updates", isOn: $model.automaticUpdates)
                        .disabled(!model.trustedBuild || model.isPreview || model.updating)
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
}

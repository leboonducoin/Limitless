import LimitlessCore
import ServiceManagement
import SwiftUI

/// Essential preferences live in the popover, using the same validated policy draft.
struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Power source", selection: $model.draft.mode) {
                ForEach(PowerMode.allCases, id: \.self) { mode in Text(mode.label).tag(mode) }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Power source")
            Stepper(value: $model.draft.batteryFloor, in: 0...50, step: 1) {
                LabeledContent("Battery reserve", value: "\(model.draft.batteryFloor)%")
                    .monospacedDigit()
            }
            .accessibilityLabel("Battery reserve")
            .accessibilityValue("\(model.draft.batteryFloor)%")
            if model.draft.batteryFloor == 0 {
                Label("Battery protection is off", systemImage: "exclamationmark.triangle")
                    .font(.caption)
            }
            Toggle("Session time limit", isOn: $model.draft.limitsDuration)
            if model.draft.limitsDuration {
                HStack {
                    Text("Maximum minutes")
                    TextField("Minutes", value: $model.draft.maximumMinutes, format: .number)
                        .textFieldStyle(.roundedBorder).accessibilityLabel("Maximum minutes")
                        .frame(width: 90)
                }
            }
            if model.draftChanged {
                HStack {
                    Text("Unapplied changes").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Apply") { Task { await model.applyPolicy() } }
                        .disabled(!model.canControl || model.busy).accessibilityLabel(
                            "Apply limits")
                }
            }
            Divider()
            Toggle(
                "Allow CLI & AI tasks",
                isOn: Binding(
                    get: { model.status?.policy.allowsAutomation ?? false },
                    set: { enabled in Task { await model.setAutomation(enabled) } })
            )
            .disabled(!model.canControl || model.busy)
            Toggle(
                "Launch at login",
                isOn: Binding(
                    get: { model.loginStatus == .enabled },
                    set: { enabled in Task { await model.setLaunchAtLogin(enabled) } })
            )
            .disabled(!model.trustedBuild || model.isPreview || model.busy || model.removalComplete)
            if model.loginStatus == .requiresApproval || model.helperStatus == .requiresApproval {
                Button("Approve in System Settings") { model.openLoginSettings() }.disabled(
                    model.isPreview)
            }
        }
        .font(.callout).toggleStyle(.switch).controlSize(.small)
    }
}

import AppKit
import LimitlessCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    var body: some View {
        Form {
            if model.isPreview {
                Section { Label("Read-only preview — system changes disabled", systemImage: "eye") }
            }
            Section("Power limits") {
                Picker("Allowed sources", selection: $model.draft.mode) {
                    ForEach(PowerMode.allCases, id: \.self) { mode in Text(mode.label).tag(mode) }
                }.pickerStyle(.segmented)
                Stepper(value: $model.draft.batteryFloor, in: 0...50, step: 1) {
                    LabeledContent("Battery reserve", value: "\(model.draft.batteryFloor)%")
                        .monospacedDigit()
                }
                .accessibilityLabel("Battery reserve")
                .accessibilityValue("\(model.draft.batteryFloor)%")
                if model.draft.batteryFloor == 0 {
                    Label(
                        "Custom battery protection is disabled. Your Mac may continue discharging.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.primary).font(.callout)
                } else {
                    Text("End sessions at this level while the battery is discharging.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Limit the duration of each session", isOn: $model.draft.limitsDuration)
                if model.draft.limitsDuration {
                    TextField(
                        "Maximum minutes", value: $model.draft.maximumMinutes, format: .number
                    )
                    .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Text("CLI and AI tasks can use stricter limits, never weaker ones.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Apply limits") { Task { await model.applyPolicy() } }
                        .disabled(!model.canControl || model.busy || !model.draftChanged)
                }
            }
            Section("Tracked tasks") {
                Toggle(
                    "Allow CLI and AI tasks",
                    isOn: Binding(
                        get: { model.status?.policy.allowsAutomation ?? false },
                        set: { enabled in Task { await model.setAutomation(enabled) } })
                )
                .disabled(!model.canControl || model.busy)
                Text(
                    "Only explicitly followed commands and processes keep your Mac awake. Stop all revokes this authorization."
                )
                .font(.caption).foregroundStyle(.secondary)
                Text("Run: limitless run -- command").font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
            Section("Startup") {
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { model.loginStatus == .enabled },
                        set: { enabled in Task { await model.setLaunchAtLogin(enabled) } })
                )
                .disabled(!model.trustedBuild || model.isPreview || model.busy)
                Text(
                    "Opening Limitless never starts a keep-awake session or authorizes automation."
                )
                .font(.caption).foregroundStyle(.secondary)
                if model.loginStatus == .requiresApproval || model.helperStatus == .requiresApproval
                {
                    Button("Review in System Settings") { model.openLoginSettings() }
                        .disabled(model.isPreview)
                }
            }
            if let message = model.message {
                Section {
                    Text(message).font(.callout).fixedSize(horizontal: false, vertical: true)
                }
            }
            if !model.trustedBuild && !model.isPreview {
                Section {
                    Text("This development build cannot change power settings or login items.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, idealWidth: 520, minHeight: 480, idealHeight: 640)
        .padding(.vertical, 8)
    }
}

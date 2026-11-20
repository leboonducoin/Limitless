import Foundation
import LimitlessCore
import LimitlessSystem

enum ProcessSelection {
    static func allFinished(_ identities: inout [ProcessIdentity]) -> Bool {
        identities.removeAll { !$0.isAlive }
        return identities.isEmpty
    }

    static func parse(_ text: String) throws -> [Int32] {
        let pieces = text.split(separator: ";", omittingEmptySubsequences: false)
        guard pieces.count <= 128 else { throw WorkError.invalidProcess }
        var ids: [Int32] = []
        for piece in pieces {
            let value = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, value.utf8.allSatisfy({ (48...57).contains($0) }),
                let pid = Int32(value), pid > 0
            else { throw WorkError.invalidProcess }
            if !ids.contains(pid) { ids.append(pid) }
        }
        return ids
    }
}

extension SessionStopReason {
    var summary: String {
        switch self {
        case .expired: "The session reached its time limit."
        case .batteryFloor: "The battery reached the reserved limit."
        case .thermalCritical: "macOS reported a critical thermal state."
        case .automationRevoked: "Automation or helper access was withdrawn."
        case .policyChanged: "The session no longer met the power limits."
        case .requested: "The session was stopped."
        case .taskEnded: "The tracked work ended."
        case .ownerLost: "The session lost contact with its owner."
        case .manualPriority: "A manual session took priority."
        case .powerFault: "Limitless could not verify keep-awake protection."
        }
    }
}

enum PowerPresentation: Equatable {
    case active, inactive, suspended, recovering, restoring, attention, unknown

    init(_ status: ServiceStatus) {
        let sleep = status.sleep
        if sleep.phase == .restoring {
            self = .restoring
        } else if sleep.fault != nil {
            self = .attention
        } else if sleep.observed == .unknown {
            self = .unknown
        } else if sleep.phase == .recovering {
            self = .recovering
        } else if sleep.phase == .active && sleep.observed == .disabled && sleep.ownsGlobalHold {
            self = .active
        } else if sleep.ownsGlobalHold || sleep.observed == .disabled {
            self = .attention
        } else if status.sessions.contains(where: { $0.suspension != nil }) {
            self = .suspended
        } else {
            self = .inactive
        }
    }

    var title: String {
        switch self {
        case .active: "Staying awake"
        case .inactive: "Ready when you are"
        case .suspended: "Waiting for power"
        case .recovering: "Verifying protection"
        case .restoring: "Restoring normal sleep"
        case .attention: "Power needs attention"
        case .unknown: "State unavailable"
        }
    }

    var symbol: String {
        switch self {
        case .active: "sun.max.fill"
        case .inactive: "moon.zzz"
        case .suspended: "pause.circle"
        case .recovering, .restoring: "arrow.trianglehead.2.clockwise.rotate.90"
        case .attention: "exclamationmark.triangle"
        case .unknown: "questionmark.circle"
        }
    }

}

struct PolicyDraft: Equatable {
    var mode: PowerMode = .all
    var batteryFloor = 20
    var limitsDuration = false
    var maximumMinutes: Double = 120
    var keepsDisplayAwake = true

    init() {}
    init(_ policy: UserPolicy) {
        mode = policy.mode
        batteryFloor = policy.batteryFloor
        limitsDuration = policy.maximumDuration != nil
        maximumMinutes = (policy.maximumDuration ?? 7_200) / 60
        keepsDisplayAwake = policy.keepsDisplayAwake
    }

    func policy(allowsAutomation: Bool) throws -> UserPolicy {
        try UserPolicy(
            mode: mode, batteryFloor: batteryFloor,
            maximumDuration: limitsDuration ? maximumMinutes * 60 : nil,
            allowsAutomation: allowsAutomation, keepsDisplayAwake: keepsDisplayAwake)
    }
}

enum StopChoice: Hashable {
    case unlimited
    case preset(Int)
    case custom, date, process
}

enum MenuBarStyle: String, CaseIterable {
    case remainingTime, icon
    case endTime = "timer"

    var label: String {
        switch self {
        case .remainingTime: "Time remaining"
        case .icon: "Icon only"
        case .endTime: "End time"
        }
    }
}

struct StatusCommandClick {
    private var origin: CGPoint?
    var isTracking: Bool { origin != nil }

    mutating func begin(at point: CGPoint, within bounds: CGRect) {
        origin = bounds.contains(point) ? point : nil
    }

    mutating func cancel() { origin = nil }

    mutating func finish(at point: CGPoint, within bounds: CGRect) -> Bool {
        defer { cancel() }
        guard let origin, bounds.contains(point) else { return false }
        return hypot(point.x - origin.x, point.y - origin.y) < 4
    }
}

struct MenuBarTime: Equatable {
    let top: String
    let bottom: String
    let accessibilityLabel: String

    static func remaining(seconds: Double) -> Self? {
        guard seconds.isFinite, seconds > 0 else { return nil }
        let rounded = ceil(seconds / 60)
        guard rounded < 100 * 24 * 60 else {
            return Self(top: "99+", bottom: "d", accessibilityLabel: "Over 99 days remaining")
        }
        let minutes = Int(rounded)
        let hours = minutes / 60
        let label = Duration.seconds(minutes * 60).formatted(
            .units(allowed: [.days, .hours, .minutes], width: .wide))
        if hours >= 100 {
            return Self(top: "\(hours / 24)", bottom: "d", accessibilityLabel: "\(label) remaining")
        }
        return Self(
            top: hours == 0 ? "00h" : "\(hours)h", bottom: String(format: "%02d", minutes % 60),
            accessibilityLabel: "\(label) remaining")
    }

    static func end(at deadline: Date, calendar: Calendar = .current) -> Self {
        let clock = calendar.dateComponents([.hour, .minute], from: deadline)
        return Self(
            top: String(format: "%02d:", clock.hour ?? 0),
            bottom: String(format: "%02d", clock.minute ?? 0),
            accessibilityLabel: "Ends at \(deadline.formatted(date: .omitted, time: .shortened))")
    }
}

struct SessionNotices {
    private var remindedID: UUID?

    mutating func shouldRemind(_ status: ServiceStatus) -> Bool {
        guard status.sleep.phase == .active, let id = status.protectionID,
            let remaining = status.protectionRemainingSeconds, remaining > 0
        else { return false }
        if remaining > 5 * 60 {
            if remindedID == id { remindedID = nil }
            return false
        }
        guard remindedID != id else { return false }
        remindedID = id
        return true
    }
}

enum DurationUnit: String, CaseIterable, Identifiable {
    case seconds, minutes, hours, days
    var id: Self { self }
    var seconds: Double {
        switch self {
        case .seconds: 1
        case .minutes: 60
        case .hours: 3_600
        case .days: 86_400
        }
    }
}

extension PowerMode {
    var label: String {
        switch self {
        case .all: "Both"
        case .battery: "Battery"
        case .external: "Power adapter"
        }
    }
}

extension PowerSource {
    var label: String {
        switch self {
        case .battery: "Battery"
        case .external: "Power adapter"
        case .unknown: "Power source unknown"
        }
    }
    var symbol: String {
        switch self {
        case .battery: "battery.75percent"
        case .external: "powerplug"
        case .unknown: "questionmark.circle"
        }
    }
}

extension SleepFault {
    var guidance: String {
        switch self {
        case .foreignHold:
            "Another tool already disabled sleep. Restore its setting before rearming Limitless."
        case .interrupted:
            "A previous session was interrupted. Confirm restoration, then rearm to start a new session."
        case .unreadableState:
            "macOS did not provide a usable state. Retry only after the reading is available."
        case .journalFailure:
            "Limitless could not record ownership safely. Check the installation before trying again."
        case .activationFailed:
            "macOS did not confirm activation. No new session will start until you rearm."
        case .recoveryExhausted:
            "Repeated external changes exhausted recovery. Resolve the conflict before rearming."
        case .restorationFailed, .restorationPending:
            "Sleep restoration is not confirmed. Retry restoration and check the result."
        }
    }
}

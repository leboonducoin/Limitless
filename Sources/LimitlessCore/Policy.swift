import Foundation

public enum PolicyError: Error, Equatable, Sendable {
    case invalidBatteryFloor
    case invalidDuration
    case invalidDate
    case invalidClock
    case powerModeNotAuthorized
    case batteryFloorNotAuthorized
    case automationNotAuthorized
    case duplicateSession
    case sessionLimitReached
}

public enum PowerSource: String, Codable, Sendable {
    case battery, external, unknown
}

public enum PowerMode: String, CaseIterable, Codable, Sendable {
    case battery, external, all

    public var flag: String {
        switch self {
        case .battery: "-b"
        case .external: "-c"
        case .all: "-a"
        }
    }

    public func allows(_ source: PowerSource) -> Bool {
        switch (self, source) {
        case (_, .unknown): false
        case (.all, _), (.battery, .battery), (.external, .external): true
        default: false
        }
    }

    public func isWithin(_ ceiling: PowerMode) -> Bool {
        ceiling == .all || self == ceiling
    }
}

public struct UserPolicy: Codable, Equatable, Sendable {
    public static let batteryFloorRange = 0...80

    public let mode: PowerMode
    public let batteryFloor: Int
    public let maximumDuration: TimeInterval?
    public let allowsAutomation: Bool
    public let keepsDisplayAwake: Bool

    public init(
        mode: PowerMode = .all,
        batteryFloor: Int = 20,
        maximumDuration: TimeInterval? = nil,
        allowsAutomation: Bool = false,
        keepsDisplayAwake: Bool = true
    ) throws {
        guard Self.batteryFloorRange.contains(batteryFloor) else {
            throw PolicyError.invalidBatteryFloor
        }
        if let maximumDuration { try Self.validateDuration(maximumDuration) }
        self.mode = mode
        self.batteryFloor = batteryFloor
        self.maximumDuration = maximumDuration
        self.allowsAutomation = allowsAutomation
        self.keepsDisplayAwake = keepsDisplayAwake
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            mode: values.decode(PowerMode.self, forKey: .mode),
            batteryFloor: values.decode(Int.self, forKey: .batteryFloor),
            maximumDuration: values.decodeIfPresent(TimeInterval.self, forKey: .maximumDuration),
            allowsAutomation: values.decode(Bool.self, forKey: .allowsAutomation),
            keepsDisplayAwake: values.decodeIfPresent(Bool.self, forKey: .keepsDisplayAwake) ?? true
        )
    }

    public static func validateDuration(_ seconds: TimeInterval) throws {
        guard seconds.isFinite, seconds > 0, seconds <= Double(Int64.max / 2)
        else { throw PolicyError.invalidDuration }
    }

    package func withAutomation(_ allowed: Bool) throws -> Self {
        try Self(
            mode: mode, batteryFloor: batteryFloor, maximumDuration: maximumDuration,
            allowsAutomation: allowed, keepsDisplayAwake: keepsDisplayAwake)
    }
}

public enum ThermalCondition: String, Codable, Sendable {
    case nominal, fair, serious, critical, unknown

    public init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .unknown
        }
    }
}

public enum BatteryReading: Codable, Equatable, Sendable {
    case notPresent
    case available(percent: Int, isDischarging: Bool)
    case unavailable

    public static func measured(percent: Int, isDischarging: Bool) -> Self {
        guard (0...100).contains(percent) else { return .unavailable }
        return .available(percent: percent, isDischarging: isDischarging)
    }
}

public struct PowerSnapshot: Codable, Equatable, Sendable {
    public let source: PowerSource
    public let battery: BatteryReading

    public init(source: PowerSource, battery: BatteryReading) {
        self.source = source
        if case .available(let percent, _) = battery, !(0...100).contains(percent) {
            self.battery = .unavailable
        } else if source == .battery, battery == .notPresent {
            self.battery = .unavailable
        } else {
            self.battery = battery
        }
    }
}

import AppKit
import CoreAudio
import CoreGraphics
import CoreLocation
import CoreWLAN
import Foundation
import IOKit
import IOKit.pwr_mgt
import LimitlessSystem
import LocalAuthentication
import Network
import Security

enum LidDisplayState: Equatable {
    case open, closedHeadless, closedWithDisplay, unknown

    static func read() -> Self {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != IO_OBJECT_NULL else { return .unknown }
        defer { IOObjectRelease(service) }
        guard
            let property = IORegistryEntryCreateCFProperty(
                service, kAppleClamshellStateKey as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue(), CFGetTypeID(property) == CFBooleanGetTypeID(),
            let closed = property as? Bool
        else { return .unknown }
        guard closed else { return .open }
        var displays = [CGDirectDisplayID](repeating: 0, count: 32)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(UInt32(displays.count), &displays, &count) == .success,
            count < displays.count
        else { return .unknown }
        return displays.prefix(Int(count)).contains { CGDisplayIsBuiltin($0) == 0 }
            ? .closedWithDisplay : .closedHeadless
    }

    var label: String? {
        switch self {
        case .closedHeadless: "Lid closed · no external display"
        case .closedWithDisplay: "Lid closed · external display"
        case .open, .unknown: nil
        }
    }

    func shouldMuteAudio(
        active: Bool, screenAsleep: Bool, muteOnSleep: Bool, muteOnLidClose: Bool
    ) -> Bool {
        active && ((screenAsleep && muteOnSleep) || (self == .closedHeadless && muteOnLidClose))
    }
}

@MainActor protocol SessionAudioOutput {
    func defaultOutput() -> AudioDeviceID?
    func uid(of device: AudioDeviceID) -> String?
    func findOutput(uid: String) -> AudioDeviceID?
    mutating func mute(of device: AudioDeviceID) -> UInt32?
    mutating func setMute(_ value: UInt32, device: AudioDeviceID, uid: String) -> Bool
    mutating func canSetMute(on device: AudioDeviceID) -> Bool
}

@MainActor struct SessionAudioMute {
    private struct Record: Codable {
        let uid: String
        let confirmed: Bool
    }

    private let journal: URL
    private var output: any SessionAudioOutput
    private var recordLoaded = false
    private var record: Record?
    private var pending: (value: UInt32, since: ContinuousClock.Instant)?
    private var overrideUntilWake = false

    init(
        journal: URL = URL.applicationSupportDirectory
            .appending(path: LimitlessIdentity.application, directoryHint: .isDirectory)
            .appending(path: "AudioMute.json", directoryHint: .notDirectory),
        output: any SessionAudioOutput = SystemAudioOutput()
    ) {
        self.journal = journal
        self.output = output
    }

    mutating func update(shouldMute: Bool, now: ContinuousClock.Instant = .now) -> String? {
        do {
            if !shouldMute { overrideUntilWake = false }
            if !recordLoaded {
                record = try savedRecord()
                recordLoaded = true
            }
            if let pending, let record {
                guard let device = output.findOutput(uid: record.uid),
                    let observed = output.mute(of: device)
                else { return "Reconnect the previous audio output to verify it." }
                guard observed == pending.value else {
                    if pending.since.duration(to: now) >= .seconds(10) {
                        self.pending = nil
                        return "macOS did not confirm the audio change."
                    }
                    return "Waiting for macOS to confirm the audio change."
                }
                self.pending = nil
                if observed == 1 {
                    try save(Record(uid: record.uid, confirmed: true))
                } else {
                    try clearRecord()
                }
            }
            if shouldMute {
                guard !overrideUntilWake else { return nil }
                if record?.confirmed == false {
                    return "Check the previous audio output and unmute it manually if needed."
                }
                if let record, let device = output.findOutput(uid: record.uid),
                    output.mute(of: device) == 0
                {
                    try clearRecord()
                    overrideUntilWake = true
                    return nil
                }
                guard record == nil, let device = output.defaultOutput(),
                    let uid = output.uid(of: device)
                else { return nil }
                guard let original = output.mute(of: device) else {
                    return "This audio output has no mute control."
                }
                guard original == 0 else { return nil }
                guard output.canSetMute(on: device) else {
                    return "This audio output cannot be muted."
                }
                try FileManager.default.createDirectory(
                    at: journal.deletingLastPathComponent(), withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700])
                try save(Record(uid: uid, confirmed: false))
                guard output.setMute(1, device: device, uid: uid) else {
                    try clearRecord()
                    return "Audio mute could not be confirmed."
                }
                pending = (1, now)
            } else if let record {
                guard let device = output.findOutput(uid: record.uid),
                    let current = output.mute(of: device)
                else { return "Reconnect the previous audio output to restore it." }
                if current == 1 {
                    guard record.confirmed else {
                        return "Check the previous audio output and unmute it manually if needed."
                    }
                    guard output.setMute(0, device: device, uid: record.uid) else {
                        return "Audio restoration could not be confirmed."
                    }
                    pending = (0, now)
                    return "Restoring the previous audio output."
                }
                try clearRecord()
            }
            return nil
        } catch {
            return "Limitless could not read or save audio recovery state."
        }
    }

    private mutating func save(_ value: Record) throws {
        try JSONEncoder().encode(value).write(to: journal, options: .atomic)
        record = value
    }

    private mutating func clearRecord() throws {
        try FileManager.default.removeItem(at: journal)
        record = nil
    }

    private func savedRecord() throws -> Record? {
        do {
            let values = try journal.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true, let size = values.fileSize, size <= 4_096
            else { throw CocoaError(.fileReadCorruptFile) }
            let data = try Data(contentsOf: journal)
            guard data.count <= 4_096 else { throw CocoaError(.fileReadCorruptFile) }
            return try JSONDecoder().decode(Record.self, from: data)
        } catch let error as CocoaError
            where [.fileReadNoSuchFile, .fileNoSuchFile].contains(error.code)
        {
            return nil
        }
    }
}

@MainActor struct SystemAudioOutput: SessionAudioOutput {
    private let system = AudioObjectID(kAudioObjectSystemObject)
    private var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute, mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)

    func defaultOutput() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var device = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout.size(ofValue: device))
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &device) == noErr,
            device != kAudioObjectUnknown
        else { return nil }
        return device
    }

    func uid(of device: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout.size(ofValue: value))
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr
        else { return nil }
        return value?.takeRetainedValue() as String?
    }

    func findOutput(uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        let propertyUID = uid as CFString
        var qualifier = Unmanaged.passUnretained(propertyUID)
        var device = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout.size(ofValue: device))
        let result = withExtendedLifetime(propertyUID) {
            AudioObjectGetPropertyData(
                system, &address, UInt32(MemoryLayout.size(ofValue: qualifier)), &qualifier,
                &size, &device)
        }
        return result == noErr && device != kAudioObjectUnknown ? device : nil
    }

    mutating func mute(of device: AudioDeviceID) -> UInt32? {
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout.size(ofValue: value))
        let result = AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &size, &value)
        return result == noErr && value <= 1 ? value : nil
    }

    mutating func setMute(_ value: UInt32, device: AudioDeviceID, uid: String) -> Bool {
        guard self.uid(of: device) == uid else { return false }
        var value = value
        return AudioObjectSetPropertyData(
            device, &muteAddress, 0, nil, UInt32(MemoryLayout.size(ofValue: value)), &value)
            == noErr
    }

    mutating func canSetMute(on device: AudioDeviceID) -> Bool {
        var settable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(device, &muteAddress, &settable) == noErr
            && settable.boolValue
    }
}

private enum AppKeychain {
    private static func query(_ service: String, account: String) -> [String: Any] {
        let authentication = LAContext()
        authentication.interactionNotAllowed = true
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: LimitlessIdentity.application + "." + service,
            kSecAttrAccount as String: account, kSecAttrSynchronizable as String: false,
            kSecUseAuthenticationContext as String: authentication,
        ]
    }

    static func save(_ data: Data, service: String, account: String) -> Bool {
        let request = query(service, account: account)
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(request as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            return SecItemAdd(
                request.merging(attributes) { _, value in value } as CFDictionary, nil)
                == errSecSuccess
        }
        return status == errSecSuccess
    }

    static func read(service: String, account: String) -> Data? {
        var request = query(service, account: account)
        request[kSecReturnData as String] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess
        else { return nil }
        return result as? Data
    }

    static func remove(service: String, account: String) -> Bool {
        let status = SecItemDelete(query(service, account: account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

enum HotspotCredentials {
    struct Network: Codable, Sendable {
        let ssid: String
        let password: String
        let automaticJoin: Bool?

        init(ssid: String, password: String, automaticJoin: Bool = false) {
            self.ssid = ssid
            self.password = password
            self.automaticJoin = automaticJoin
        }

        var isValid: Bool {
            (1...32).contains(ssid.utf8.count) && (8...63).contains(password.utf8.count)
                && !ssid.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
                && !password.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
        }
    }

    static func save(_ network: Network) -> Bool {
        guard network.isValid, let data = try? JSONEncoder().encode(network) else { return false }
        return AppKeychain.save(data, service: "hotspot", account: "fallback")
    }

    static func read() -> Network? {
        guard let data = AppKeychain.read(service: "hotspot", account: "fallback"),
            data.count <= 1_024,
            let network = try? JSONDecoder().decode(Network.self, from: data), network.isValid
        else { return nil }
        return network
    }

    static func remove() -> Bool { AppKeychain.remove(service: "hotspot", account: "fallback") }
}

enum UpdatePreferences {
    static func readConsent() -> Bool? {
        switch AppKeychain.read(service: "updates", account: "automatic") {
        case Data([0]): false
        case Data([1]): true
        default: nil
        }
    }

    static func saveConsent(_ enabled: Bool) -> Bool {
        AppKeychain.save(Data([enabled ? 1 : 0]), service: "updates", account: "automatic")
    }

    static func readSchedule() -> UpdateSchedule? {
        guard let data = AppKeychain.read(service: "updates", account: "schedule"),
            data.count <= 1_024
        else { return nil }
        return try? JSONDecoder().decode(UpdateSchedule.self, from: data)
    }

    static func saveSchedule(_ schedule: UpdateSchedule) {
        guard let data = try? JSONEncoder().encode(schedule) else { return }
        _ = AppKeychain.save(data, service: "updates", account: "schedule")
    }

    static func remove() -> Bool {
        let removedConsent = AppKeychain.remove(service: "updates", account: "automatic")
        return AppKeychain.remove(service: "updates", account: "schedule") && removedConsent
    }
}

@MainActor final class HotspotFallback {
    enum JoinResult: Equatable {
        case cancelled, noMatch, joined
    }

    private enum JoinError: Error { case missingCredentials }
    private var monitor: NWPathMonitor?
    private var monitorID: UUID?
    private var offlineSince: ContinuousClock.Instant?
    private var nextAttempt: ContinuousClock.Instant?
    private var attempt: Task<Void, Never>?
    private let location = CLLocationManager()
    private(set) var message: String?

    func requestLocationAccess() {
        if location.authorizationStatus == .notDetermined {
            location.requestWhenInUseAuthorization()
        }
    }

    func update(eligible: Bool, confirmSession: (@Sendable () async -> Bool)? = nil) {
        guard eligible else {
            monitor?.cancel()
            monitor = nil
            monitorID = nil
            offlineSince = nil
            nextAttempt = nil
            attempt?.cancel()
            message = nil
            return
        }
        if monitor == nil {
            let monitor = NWPathMonitor()
            let id = UUID()
            monitorID = id
            monitor.pathUpdateHandler = { [weak self] path in
                let offline = path.status == .unsatisfied
                Task { @MainActor in
                    guard let self, self.monitorID == id else { return }
                    if offline {
                        if self.offlineSince == nil { self.offlineSince = .now }
                    } else {
                        self.offlineSince = nil
                        self.nextAttempt = nil
                        self.message = nil
                        self.attempt?.cancel()
                    }
                }
            }
            monitor.start(queue: DispatchQueue.global(qos: .utility))
            self.monitor = monitor
        }
        let now = ContinuousClock.now
        guard let offlineSince, offlineSince.duration(to: now) >= .seconds(30),
            now >= (nextAttempt ?? now), let monitorID, attempt == nil, let confirmSession
        else { return }
        nextAttempt = now + .seconds(120)
        let canJoin: @Sendable () async -> Bool = { [weak self] in
            let eligible = await MainActor.run {
                self?.monitorID == monitorID && self?.offlineSince != nil
            }
            guard eligible else { return false }
            return await confirmSession()
        }
        attempt = Task(priority: .utility) { [weak self] in
            let result = await Self.joinIfAvailable(canJoin: canJoin)
            guard let self else { return }
            self.attempt = nil
            if self.monitorID == monitorID, self.offlineSince != nil {
                self.message = result
            }
        }
    }

    @concurrent private static func joinIfAvailable(
        canJoin: @Sendable () async -> Bool
    ) async -> String? {
        do {
            let result = try await associateIfCurrent(canJoin: canJoin) {
                guard let network = HotspotCredentials.read(),
                    network.automaticJoin == true,
                    let interface = CWWiFiClient.shared().interface()
                else { throw JoinError.missingCredentials }
                let name = Data(network.ssid.utf8)
                let nearby = try interface.scanForNetworks(withSSID: name)
                let matches = nearby.filter {
                    $0.ssidData == name
                        && ($0.supportsSecurity(.wpa2Personal)
                            || $0.supportsSecurity(.wpa3Personal))
                }
                guard matches.count == 1, let target = matches.first else { return nil }
                return { try interface.associate(to: target, password: network.password) }
            }
            if result == .noMatch {
                return
                    "The selected protected hotspot is unavailable. Check Location Services and your iPhone."
            }
            return nil
        } catch JoinError.missingCredentials {
            return "Hotspot details could not be read. Save them again in Options."
        } catch {
            return "The iPhone hotspot could not be joined."
        }
    }

    nonisolated static func associateIfCurrent(
        canJoin: @Sendable () async -> Bool,
        scan: () throws -> (() throws -> Void)?
    ) async throws -> JoinResult {
        guard !Task.isCancelled, await canJoin(), !Task.isCancelled else { return .cancelled }
        guard let associate = try scan() else { return .noMatch }
        guard !Task.isCancelled, await canJoin(), !Task.isCancelled else { return .cancelled }
        try associate()
        return .joined
    }
}

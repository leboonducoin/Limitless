import Foundation
import LimitlessCore
import Security
import ServiceManagement

public enum HelperInstallationKind: String, Sendable {
    case bundled, blessed

    public var service: any HelperInstallation {
        switch self {
        case .bundled: BundledHelperInstallation()
        case .blessed: BlessedHelperInstallation()
        }
    }

    func validateApplication() throws -> SignedIdentity {
        let identity = try SignedIdentity(expectedIdentifier: LimitlessIdentity.application)
        guard geteuid() != 0, ConsoleUser.identifier() == geteuid(),
            Bundle.main.object(forInfoDictionaryKey: "LimitlessHelperInstallation") as? String
                == rawValue
        else { throw HelperInstallationError.invalidBundle }
        return identity
    }
}

public enum HelperInstallationError: Error, Sendable {
    case invalidBundle, conflictingInstallation, unconfirmedRemoval
}

public protocol HelperInstallation: Sendable {
    var status: SMAppService.Status { get }
    func register() async throws
    func unregister() async throws
}

extension HelperInstallation {
    public var removalIsConfirmed: Bool {
        guard
            removalStatusesAreAbsent(
                service: status, systemJob: HelperInstallationKind.blessed.service.status)
        else { return false }
        return (try? requireRemovedFiles()) != nil
    }
}

func removalStatusesAreAbsent(
    service: SMAppService.Status, systemJob: SMAppService.Status
) -> Bool {
    [.notRegistered, .notFound].contains(service) && systemJob == .notRegistered
}

private func requireRemovedFiles() throws {
    var backend = MacSleepBackend()
    guard try SecureOwnershipJournal.isStateDirectoryAbsent(),
        try InstalledHelperFiles.areAbsent(), backend.observe() == .allowed
    else { throw HelperInstallationError.unconfirmedRemoval }
}

private struct BundledHelperInstallation: HelperInstallation {
    var status: SMAppService.Status {
        SMAppService.daemon(plistName: LimitlessIdentity.daemonPlist).status
    }

    func register() async throws {
        try await Task.detached {
            let identity = try HelperInstallationKind.bundled.validateApplication()
            try identity.verifyExecutable(
                at: Bundle.main.bundleURL.appendingPathComponent(
                    "Contents/Library/HelperTools/LimitlessHelper"),
                identifier: LimitlessIdentity.helper)
            guard try InstalledHelperFiles.areAbsent() else {
                throw HelperInstallationError.conflictingInstallation
            }
            guard
                HelperInstallationKind.blessed.service.status != .enabled || self.status == .enabled
            else {
                throw HelperInstallationError.conflictingInstallation
            }
            try SMAppService.daemon(plistName: LimitlessIdentity.daemonPlist).register()
        }.value
    }

    @concurrent func unregister() async throws {
        _ = try HelperInstallationKind.bundled.validateApplication()
        try requireRemovedFiles()
        let service = SMAppService.daemon(plistName: LimitlessIdentity.daemonPlist)
        switch service.status {
        case .enabled, .requiresApproval: try await service.unregister()
        case .notRegistered, .notFound: break
        @unknown default: throw HelperInstallationError.unconfirmedRemoval
        }
        guard removalIsConfirmed else {
            throw HelperInstallationError.unconfirmedRemoval
        }
    }
}

private struct BlessedHelperInstallation: HelperInstallation {
    @available(macOS, deprecated: 13.0, message: "Compatibility channel without notarization")
    private func requireUnregisteredJob() throws {
        let modern = SMAppService.daemon(plistName: LimitlessIdentity.daemonPlist).status
        guard modern != .enabled, modern != .requiresApproval, status != .enabled else {
            throw HelperInstallationError.conflictingInstallation
        }
    }

    @available(macOS, deprecated: 13.0, message: "Compatibility channel without notarization")
    var status: SMAppService.Status {
        if SMJobCopyDictionary(kSMDomainSystemLaunchd, LimitlessIdentity.helper as CFString)?
            .takeRetainedValue() != nil
        {
            return .enabled
        }
        return (try? InstalledHelperFiles.areAbsent()) == true ? .notRegistered : .notFound
    }

    @available(macOS, deprecated: 13.0, message: "Compatibility channel without notarization")
    func register() async throws {
        try await Task.detached {
            let identity = try HelperInstallationKind.blessed.validateApplication()
            let helper = Bundle.main.bundleURL.appendingPathComponent(
                "Contents/Library/LaunchServices/" + LimitlessIdentity.helper)
            let details = try identity.verifyExecutable(
                at: helper, identifier: LimitlessIdentity.helper)
            let expected = try identity.requirement(for: LimitlessIdentity.helper)
            guard
                Bundle.main.object(forInfoDictionaryKey: "SMPrivilegedExecutables")
                    as? [String: String] == [LimitlessIdentity.helper: expected],
                let helperInfo = details[kSecCodeInfoPList as String] as? [String: Any],
                helperInfo["CFBundleIdentifier"] as? String == LimitlessIdentity.helper,
                helperInfo["CFBundleVersion"] as? String
                    == Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
                helperInfo["SMAuthorizedClients"] as? [String]
                    == [try identity.requirement(for: LimitlessIdentity.application)]
            else { throw HelperInstallationError.invalidBundle }
            try requireUnregisteredJob()
            if try !SecureOwnershipJournal.directoryIsAbsent(
                at: InstalledHelperFiles.executablePath)
            {
                try identity.verifyExecutable(
                    at: URL(fileURLWithPath: InstalledHelperFiles.executablePath),
                    identifier: LimitlessIdentity.helper)
            }
            try withAuthorization(right: kSMRightBlessPrivilegedHelper) { authorization in
                try requireUnregisteredJob()
                var error: Unmanaged<CFError>?
                guard
                    SMJobBless(
                        kSMDomainSystemLaunchd, LimitlessIdentity.helper as CFString,
                        authorization, &error)
                else {
                    if let error { throw error.takeRetainedValue() }
                    throw CocoaError(.executableLoad)
                }
            }
            guard self.status == .enabled else { throw HelperInstallationError.invalidBundle }
        }.value
    }

    @available(macOS, deprecated: 13.0, message: "Compatibility channel without notarization")
    func unregister() async throws {
        try await Task.detached {
            _ = try HelperInstallationKind.blessed.validateApplication()
            try requireRemovedFiles()
            if removalIsConfirmed { return }
            try withAuthorization(right: kSMRightModifySystemDaemons) { authorization in
                try requireRemovedFiles()
                var error: Unmanaged<CFError>?
                guard
                    SMJobRemove(
                        kSMDomainSystemLaunchd, LimitlessIdentity.helper as CFString,
                        authorization, true, &error)
                else {
                    if let error { throw error.takeRetainedValue() }
                    throw CocoaError(.executableLoad)
                }
            }
            guard removalIsConfirmed else { throw HelperInstallationError.unconfirmedRemoval }
        }.value
    }
}

func withAuthorization(right: String, operation: (AuthorizationRef) throws -> Void) throws {
    var reference: AuthorizationRef?
    let created = AuthorizationCreate(nil, nil, [], &reference)
    guard created == errAuthorizationSuccess, let reference else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(created))
    }
    defer { AuthorizationFree(reference, [.destroyRights]) }
    let result = copyAuthorizationRight(
        right, reference: reference, flags: [.interactionAllowed, .extendRights, .preAuthorize])
    guard result == errAuthorizationSuccess else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(result))
    }
    try operation(reference)
}

private func copyAuthorizationRight(
    _ right: String, reference: AuthorizationRef, flags: AuthorizationFlags
) -> OSStatus {
    right.withCString { name in
        var item = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
        return withUnsafeMutablePointer(to: &item) { itemPointer in
            var rights = AuthorizationRights(count: 1, items: itemPointer)
            return AuthorizationCopyRights(reference, &rights, nil, flags, nil)
        }
    }
}

public enum AdministratorAuthorization {
    @concurrent public static func withGrant<Result: Sendable>(
        _ operation: @MainActor @Sendable (Data) async throws -> Result
    ) async throws -> Result {
        var authorization: AuthorizationRef?
        guard AuthorizationCreate(nil, nil, [], &authorization) == errAuthorizationSuccess,
            let authorization
        else { throw ServiceError.unauthorized }
        defer { AuthorizationFree(authorization, [.destroyRights]) }
        guard
            copyAuthorizationRight(
                kSMRightModifySystemDaemons, reference: authorization,
                flags: [.interactionAllowed, .extendRights])
                == errAuthorizationSuccess
        else { throw ServiceError.unauthorized }
        var form = AuthorizationExternalForm()
        guard AuthorizationMakeExternalForm(authorization, &form) == errAuthorizationSuccess
        else { throw ServiceError.unauthorized }
        try Task.checkCancellation()
        return try await operation(withUnsafeBytes(of: &form) { Data($0) })
    }

    public static func verify(_ request: ServiceRequest) throws {
        guard request.operation.requiresAdministrator else { return }
        guard let data = request.authorization,
            data.count == MemoryLayout<AuthorizationExternalForm>.size
        else { throw ServiceError.unauthorized }
        var form = AuthorizationExternalForm()
        _ = withUnsafeMutableBytes(of: &form) { data.copyBytes(to: $0) }
        var authorization: AuthorizationRef?
        guard AuthorizationCreateFromExternalForm(&form, &authorization) == errAuthorizationSuccess,
            let authorization
        else { throw ServiceError.unauthorized }
        defer { AuthorizationFree(authorization, []) }
        guard
            copyAuthorizationRight(kSMRightModifySystemDaemons, reference: authorization, flags: [])
                == errAuthorizationSuccess
        else { throw ServiceError.unauthorized }
    }
}

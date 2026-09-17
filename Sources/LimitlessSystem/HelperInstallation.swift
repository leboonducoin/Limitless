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

/// Two native installation mechanisms; the legacy API's deprecation stays at this boundary.
public protocol HelperInstallation: Sendable {
    var status: SMAppService.Status { get }
    func register() async throws
    func unregister() async throws
}

private func requireRemovedFiles() throws {
    guard try SecureOwnershipJournal.isStateDirectoryAbsent(),
        try InstalledHelperFiles.areAbsent()
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

    func unregister() async throws {
        _ = try HelperInstallationKind.bundled.validateApplication()
        try requireRemovedFiles()
        let service = SMAppService.daemon(plistName: LimitlessIdentity.daemonPlist)
        try await service.unregister()
        guard service.status == .notRegistered else {
            throw HelperInstallationError.unconfirmedRemoval
        }
        try requireRemovedFiles()
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
            // Presence is not proof of readiness: the app still requires authenticated XPC.
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
            // Never replace an installed binary belonging to another certificate.
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
                else { throw error?.takeRetainedValue() ?? CocoaError(.executableLoad) as CFError }
            }
            guard self.status == .enabled else { throw HelperInstallationError.invalidBundle }
        }.value
    }

    @available(macOS, deprecated: 13.0, message: "Compatibility channel without notarization")
    func unregister() async throws {
        try await Task.detached {
            _ = try HelperInstallationKind.blessed.validateApplication()
            try requireRemovedFiles()
            try withAuthorization(right: kSMRightModifySystemDaemons) { authorization in
                // Recheck after a possibly long native authorization dialogue.
                try requireRemovedFiles()
                var error: Unmanaged<CFError>?
                guard
                    SMJobRemove(
                        kSMDomainSystemLaunchd, LimitlessIdentity.helper as CFString,
                        authorization, true, &error)
                else { throw error?.takeRetainedValue() ?? CocoaError(.executableLoad) as CFError }
            }
            guard
                SMJobCopyDictionary(kSMDomainSystemLaunchd, LimitlessIdentity.helper as CFString)?
                    .takeRetainedValue() == nil
            else { throw HelperInstallationError.unconfirmedRemoval }
            try requireRemovedFiles()
        }.value
    }
}

/// The password belongs to macOS. The short-lived AuthorizationRef never crosses XPC or an await.
private func withAuthorization(right: String, operation: (AuthorizationRef) throws -> Void) throws {
    var reference: AuthorizationRef?
    let created = AuthorizationCreate(nil, nil, [], &reference)
    guard created == errAuthorizationSuccess, let reference else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(created))
    }
    defer { AuthorizationFree(reference, [.destroyRights]) }
    try right.withCString { name in
        var item = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
        try withUnsafeMutablePointer(to: &item) { itemPointer in
            var rights = AuthorizationRights(count: 1, items: itemPointer)
            let result = AuthorizationCopyRights(
                reference, &rights, nil, [.interactionAllowed, .extendRights, .preAuthorize], nil)
            guard result == errAuthorizationSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(result))
            }
        }
    }
    try operation(reference)
}

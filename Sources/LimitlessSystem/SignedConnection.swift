import CryptoKit
import Foundation
import Security
import SystemConfiguration

public enum LimitlessIdentity {
    public static let version = "0.1.0"
    public static let application = "io.github.leboonducoin.Limitless"
    public static let commandLine = application + ".cli"
    public static let helper = application + ".helper"
    public static let controlService = application + ".control"
    public static let taskService = application + ".tasks"
    public static let daemonPlist = helper + ".plist"
}

public enum SignatureError: Error, Sendable {
    case untrustedIdentity, invalidRequirement
}

/// Pin the current executable's actual signing certificate and exact peer identifiers.
/// A self-signed identity is sufficient; ad-hoc signatures have no certificate and are rejected.
public struct SignedIdentity: Sendable {
    public let certificateFingerprint: String
    public let executableURL: URL

    /// Security may evaluate certificate trust while reading signing information.
    @concurrent public static func current(expectedIdentifier: String) async throws -> Self {
        try Task.checkCancellation()
        let identity = try Self(expectedIdentifier: expectedIdentifier)
        try Task.checkCancellation()
        return identity
    }

    public init(expectedIdentifier: String) throws {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var information: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
            SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
            SecCodeCopySigningInformation(
                staticCode, SecCSFlags(rawValue: kSecCSSigningInformation),
                &information) == errSecSuccess,
            let details = information as? [String: Any],
            let certificates = details[kSecCodeInfoCertificates as String] as? [SecCertificate],
            let leaf = certificates.first,
            let executable = details[kSecCodeInfoMainExecutable as String] as? URL,
            details[kSecCodeInfoIdentifier as String] as? String == expectedIdentifier
        else { throw SignatureError.untrustedIdentity }
        // Apple's requirement language selects certificates with a SHA-1 fingerprint.
        // This is a certificate selector, not the digest used to authenticate release archives.
        let fingerprint = Insecure.SHA1.hash(data: SecCertificateCopyData(leaf) as Data)
            .map { String(format: "%02x", $0) }.joined()
        let requirement = try Self.requirement(
            identifier: expectedIdentifier, certificateFingerprint: fingerprint)
        var parsed: SecRequirement?
        guard SecRequirementCreateWithString(requirement as CFString, [], &parsed) == errSecSuccess,
            let parsed, SecCodeCheckValidity(code, [], parsed) == errSecSuccess
        else { throw SignatureError.untrustedIdentity }
        certificateFingerprint = fingerprint
        executableURL = executable
    }

    public func requirement(for identifier: String) throws -> String {
        try Self.requirement(identifier: identifier, certificateFingerprint: certificateFingerprint)
    }

    @discardableResult
    func verifyExecutable(at url: URL, identifier: String) throws -> [String: Any] {
        let value = try requirement(for: identifier)
        var requirement: SecRequirement?
        var code: SecStaticCode?
        guard SecRequirementCreateWithString(value as CFString, [], &requirement) == errSecSuccess,
            let requirement,
            SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
            SecStaticCodeCheckValidity(
                code, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures),
                requirement) == errSecSuccess
        else { throw SignatureError.untrustedIdentity }
        var information: CFDictionary?
        guard
            SecCodeCopySigningInformation(
                code, SecCSFlags(rawValue: kSecCSSigningInformation), &information)
                == errSecSuccess,
            let details = information as? [String: Any]
        else { throw SignatureError.untrustedIdentity }
        return details
    }

    static func requirement(identifier: String, certificateFingerprint: String) throws -> String {
        guard
            [
                LimitlessIdentity.application, LimitlessIdentity.commandLine,
                LimitlessIdentity.helper,
            ]
            .contains(identifier), certificateFingerprint.utf8.count == 40,
            certificateFingerprint.utf8.allSatisfy({
                (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
            })
        else { throw SignatureError.invalidRequirement }
        let value =
            "identifier \"\(identifier)\" and certificate leaf = H\"\(certificateFingerprint)\""
        var parsed: SecRequirement?
        guard SecRequirementCreateWithString(value as CFString, [], &parsed) == errSecSuccess else {
            throw SignatureError.invalidRequirement
        }
        return value
    }
}

public enum ConsoleUser {
    public static func identifier() -> UInt32? {
        var user: uid_t = 0
        guard
            let name = SCDynamicStoreCopyConsoleUser(nil, &user, nil) as String?,
            name != "loginwindow", user != 0
        else { return nil }
        return user
    }
}

@objc public protocol LimitlessXPC {
    func request(_ data: Data, reply: @escaping @Sendable (Data) -> Void)
}

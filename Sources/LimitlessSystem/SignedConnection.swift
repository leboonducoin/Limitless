import Foundation
import LimitlessCore
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

/// Exact identifiers and the current executable's validated team constrain both XPC directions.
public struct SignedIdentity: Sendable {
    public let team: String

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
            let team = details[kSecCodeInfoTeamIdentifier as String] as? String,
            details[kSecCodeInfoIdentifier as String] as? String == expectedIdentifier
        else { throw SignatureError.untrustedIdentity }
        let requirement = try Self.requirement(identifier: expectedIdentifier, team: team)
        var parsed: SecRequirement?
        guard SecRequirementCreateWithString(requirement as CFString, [], &parsed) == errSecSuccess,
            let parsed, SecCodeCheckValidity(code, [], parsed) == errSecSuccess
        else { throw SignatureError.untrustedIdentity }
        self.team = team
    }

    public func requirement(for identifier: String) throws -> String {
        try Self.requirement(identifier: identifier, team: team)
    }

    static func requirement(identifier: String, team: String) throws -> String {
        guard
            [
                LimitlessIdentity.application, LimitlessIdentity.commandLine,
                LimitlessIdentity.helper,
            ]
            .contains(identifier), team.utf8.count == 10,
            team.utf8.allSatisfy({ (65...90).contains($0) || (48...57).contains($0) })
        else { throw SignatureError.invalidRequirement }
        let value =
            "anchor apple generic and identifier \"\(identifier)\" "
            + "and certificate leaf[subject.OU] = \"\(team)\""
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

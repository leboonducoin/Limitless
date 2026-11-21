import Foundation
import LimitlessCore
import Security
import Testing

@testable import LimitlessSystem

@Test func privateLaunchCopiesAreIndependentAndOwnedByTheUser() throws {
    let files = FileManager.default
    let input = files.temporaryDirectory.appendingPathComponent("\(UUID()).app")
    try files.createDirectory(at: input, withIntermediateDirectories: false)
    defer { try? files.removeItem(at: input) }
    let marker = input.appendingPathComponent("fixture")
    try Data([1]).write(to: marker)
    let copy = try PrivateApplicationLaunch.copy(input)
    let directory = copy.deletingLastPathComponent()
    defer { PrivateApplicationLaunch.remove(copy) }
    let attributes = try files.attributesOfItem(atPath: directory.path)
    #expect(attributes[.posixPermissions] as? Int == 0o700)
    try Data([2]).write(to: marker)
    #expect(try Data(contentsOf: copy.appendingPathComponent("fixture")) == Data([1]))
}

@Test func systemChangesRejectMissingOrMalformedAdministratorApproval() throws {
    for operation in [
        ServiceOperation.prepareRemoval, .prepareUpdate, .finishRemoval, .installCLI,
        .setAutomation(true), .setSudoTouchID(true), .setSudoTouchID(false),
    ] {
        #expect(throws: ServiceError.unauthorized) {
            try AdministratorAuthorization.verify(.init(operation))
        }
        #expect(throws: ServiceError.unauthorized) {
            try AdministratorAuthorization.verify(.init(operation, authorization: Data([0])))
        }
    }
    try AdministratorAuthorization.verify(.init(.status))
    try AdministratorAuthorization.verify(.init(.setAutomation(false)))
}

@Test func signingRequirementsPinIdentifierAndCertificateAndRejectInjection() throws {
    let fingerprint = "0123456789abcdef0123456789abcdef01234567"
    for identifier in [
        LimitlessIdentity.application, LimitlessIdentity.commandLine, LimitlessIdentity.helper,
    ] {
        let requirement = try SignedIdentity.requirement(
            identifier: identifier, certificateFingerprint: fingerprint)
        var parsed: SecRequirement?
        #expect(
            SecRequirementCreateWithString(requirement as CFString, [], &parsed) == errSecSuccess)
        #expect(requirement.contains("certificate leaf = H\"\(fingerprint)\""))
        #expect(requirement.contains(identifier))
        let connection = NSXPCConnection(
            machServiceName: "io.github.leboonducoin.Limitless.test-unregistered")
        connection.setCodeSigningRequirement(requirement)
        connection.invalidate()
    }
    _ = try SignedIdentity.requirement(
        identifier: LimitlessIdentity.application,
        certificateFingerprint: fingerprint.uppercased())
    for invalid in [
        "", String(fingerprint.dropLast()), fingerprint + "0",
        fingerprint + "\n", "g" + String(fingerprint.dropFirst()),
        fingerprint + "\" or true",
    ] {
        #expect(throws: SignatureError.invalidRequirement) {
            try SignedIdentity.requirement(
                identifier: LimitlessIdentity.application, certificateFingerprint: invalid)
        }
    }
    #expect(throws: SignatureError.invalidRequirement) {
        try SignedIdentity.requirement(
            identifier: "arbitrary.identifier", certificateFingerprint: fingerprint)
    }
}

@Test func testHostCannotImpersonateTheSignedProductionHelper() {
    #expect(throws: SignatureError.untrustedIdentity) {
        try SignedIdentity(expectedIdentifier: LimitlessIdentity.helper)
    }
}

@Test(arguments: [ClientRole.application, .task]) @MainActor
func asynchronousClientSetupRejectsTheTestHost(role: ClientRole) async {
    await #expect(throws: SignatureError.untrustedIdentity) {
        try await ServiceClient(role: role)
    }
}

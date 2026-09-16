import Foundation
import Security
import Testing

@testable import LimitlessSystem

@Test func signingRequirementsPinIdentifierAndTeamAndRejectInjection() throws {
    for identifier in [
        LimitlessIdentity.application, LimitlessIdentity.commandLine, LimitlessIdentity.helper,
    ] {
        let requirement = try SignedIdentity.requirement(identifier: identifier, team: "A123456789")
        var parsed: SecRequirement?
        #expect(
            SecRequirementCreateWithString(requirement as CFString, [], &parsed) == errSecSuccess)
        #expect(requirement.contains("anchor apple generic"))
        #expect(requirement.contains(identifier))
        #expect(requirement.contains("A123456789"))
    }
    for team in ["", "A12345678", "a123456789", "A12345678\"", "A123456789 or true"] {
        #expect(throws: SignatureError.invalidRequirement) {
            try SignedIdentity.requirement(identifier: LimitlessIdentity.application, team: team)
        }
    }
    #expect(throws: SignatureError.invalidRequirement) {
        try SignedIdentity.requirement(identifier: "arbitrary.identifier", team: "A123456789")
    }
}

@Test func testHostCannotImpersonateTheSignedProductionHelper() {
    #expect(throws: SignatureError.untrustedIdentity) {
        try SignedIdentity(expectedIdentifier: LimitlessIdentity.helper)
    }
}

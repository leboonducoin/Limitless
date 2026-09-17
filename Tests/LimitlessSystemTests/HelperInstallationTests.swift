import Testing

@testable import LimitlessSystem

@Test(arguments: [HelperInstallationKind.bundled, .blessed])
func anAdHocTestHostCannotRequestNativeInstallationOrRemoval(_ kind: HelperInstallationKind) async {
    // The signature check must fail before Authorization Services or either native mutation API.
    let service = kind.service
    await #expect(throws: SignatureError.untrustedIdentity) { try await service.register() }
    await #expect(throws: SignatureError.untrustedIdentity) { try await service.unregister() }
}

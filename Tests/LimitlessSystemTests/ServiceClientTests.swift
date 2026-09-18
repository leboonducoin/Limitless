import Foundation
import Testing

@testable import LimitlessSystem

private final class InvalidationProbe: NSXPCConnection {
    var invalidated = false

    override func invalidate() {
        invalidated = true
        super.invalidate()
    }
}

@Test func droppingConnectionOwnerInvalidatesWithoutExplicitClose() {
    let connection = InvalidationProbe(
        machServiceName: "io.github.leboonducoin.Limitless.test-unregistered")
    var lifetime: ConnectionLifetime? = ConnectionLifetime(connection)
    #expect(lifetime?.connection === connection)
    #expect(!connection.invalidated)
    lifetime = nil
    #expect(connection.invalidated)
}

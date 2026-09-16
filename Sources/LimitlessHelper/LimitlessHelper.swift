import Darwin
import Foundation
import LimitlessSystem
import os

@main
struct LimitlessHelper {
    static func main() {
        do {
            guard geteuid() == 0 else { throw JournalError.administratorRequired }
            let identity = try SignedIdentity(expectedIdentifier: LimitlessIdentity.helper)
            let server = HelperServer(identity: identity)
            try server.start()
            withExtendedLifetime(server) { dispatchMain() }
        } catch {
            Logger(subsystem: LimitlessIdentity.helper, category: "startup")
                .fault(
                    "Helper startup refused: identity or protected state could not be validated.")
            exit(1)
        }
    }
}

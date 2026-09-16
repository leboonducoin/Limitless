import Foundation

/// Observation of the global OS flag, not proof that a closed MacBook stays awake.
public enum SleepObservation: String, Codable, Sendable {
    case allowed, disabled, unknown
}

/// OS boundary. Implementations must bound blocking operations and verify writes.
/// The helper calls it on its serial worker, never on the app's main actor.
public protocol SleepBackend {
    var hasIdleAssertion: Bool { get }
    mutating func observe() -> SleepObservation
    mutating func setSleepDisabled(_ disabled: Bool) throws
    mutating func setIdleAssertion(_ held: Bool) throws
}

/// A successful claim must be durable before a global setting can be changed.
public protocol OwnershipJournal {
    mutating func storeOwned(_ owned: Bool) throws
}

public enum SleepFault: String, Codable, Error, Sendable {
    case interrupted, foreignHold, unreadableState, journalFailure
    case activationFailed, recoveryExhausted, restorationFailed, restorationPending
}

public enum SleepPhase: String, Codable, Sendable {
    case inactive, active, recovering, restoring, blocked
}

public struct SleepReport: Equatable, Codable, Sendable {
    public let phase: SleepPhase
    public let observed: SleepObservation
    public let ownsGlobalHold: Bool
    public let fault: SleepFault?
}

/// Owns decisions, not OS handles. Access and all backend calls must be serialized.
public struct SleepController: Sendable {
    public private(set) var ownsGlobalHold: Bool
    public private(set) var fault: SleepFault?
    public private(set) var recoveryAttempts = 0
    private var restorationAttempts = 0
    private var recoveryAt: TimeInterval = 0
    private var restorationAt: TimeInterval = 0
    private var lastTime: TimeInterval?
    public static let retryLimit = 3

    /// Loaded from the protected journal. A prior claim always requires cleanup.
    public init(restoringOwnedHold: Bool) {
        ownsGlobalHold = restoringOwnedHold
        fault = restoringOwnedHold ? .interrupted : nil
    }

    /// Explicit app-authorized rearming, never a watchdog or lease renewal.
    public mutating func rearm() throws {
        guard !ownsGlobalHold else { throw SleepFault.restorationPending }
        fault = nil
        recoveryAttempts = 0
        restorationAttempts = 0
        recoveryAt = 0
        restorationAt = 0
    }

    /// Explicitly retry a failed stop, without granting permission to activate.
    public mutating func retryRestoration() {
        restorationAttempts = 0
        restorationAt = 0
    }

    public mutating func reconcile(
        wantsAwake: Bool, now: ClockSnapshot,
        backend: inout some SleepBackend, journal: inout some OwnershipJournal
    ) -> SleepReport {
        if let lastTime, now.continuous < lastTime {
            fault = .interrupted
            recoveryAt = 0
            restorationAt = 0
        }
        lastTime = now.continuous
        let observed = backend.observe()

        // Stop, suspension and any latched fault always outrank recovery.
        if !wantsAwake || fault != nil {
            return restore(now: now.continuous, backend: &backend, journal: &journal)
        }
        guard observed != .unknown else {
            fault = .unreadableState
            return restore(now: now.continuous, backend: &backend, journal: &journal)
        }
        if !ownsGlobalHold {
            guard observed == .allowed else {
                fault = .foreignHold
                return report(.blocked, observed)
            }
            do {
                try journal.storeOwned(true)
                ownsGlobalHold = true
            } catch {
                fault = .journalFailure
                return report(.blocked, observed)
            }
        } else if observed == .disabled, backend.hasIdleAssertion {
            return report(.active, observed)
        } else {
            guard recoveryAttempts < Self.retryLimit else {
                fault = .recoveryExhausted
                return restore(now: now.continuous, backend: &backend, journal: &journal)
            }
            guard now.continuous >= recoveryAt else { return report(.recovering, observed) }
            recoveryAttempts += 1
        }

        do {
            try backend.setIdleAssertion(true)
            guard backend.hasIdleAssertion else { throw SleepFault.activationFailed }
            try backend.setSleepDisabled(true)
            let applied = backend.observe()
            guard applied == .disabled else { throw SleepFault.activationFailed }
            // Do not reset this budget after success: repeated external interference
            // must eventually stop, even when each individual repair succeeds.
            recoveryAt = now.continuous + pow(2, Double(recoveryAttempts))
            return report(.active, applied)
        } catch {
            fault = .activationFailed
            return restore(now: now.continuous, backend: &backend, journal: &journal)
        }
    }

    private mutating func restore(
        now: TimeInterval, backend: inout some SleepBackend, journal: inout some OwnershipJournal
    ) -> SleepReport {
        guard ownsGlobalHold else {
            // Never write a global value without a durable claim, even if it is on.
            let observed = backend.observe()
            return report(fault == nil ? .inactive : .blocked, observed)
        }
        guard restorationAttempts < Self.retryLimit else {
            return report(.blocked, backend.observe())
        }
        guard now >= restorationAt else {
            return report(.restoring, backend.observe())
        }
        restorationAttempts += 1
        restorationAt = now + pow(2, Double(restorationAttempts))
        var assertionReleased = false
        do {
            try backend.setIdleAssertion(false)
            assertionReleased = !backend.hasIdleAssertion
        } catch {
            // Still attempt global restoration if the independent assertion fails.
        }
        do {
            // Write zero even when a prior failed activation appeared not to apply.
            // A successful process exit or an earlier observation is not an ack.
            try backend.setSleepDisabled(false)
            guard backend.observe() == .allowed, assertionReleased else {
                throw SleepFault.restorationFailed
            }
            try journal.storeOwned(false)
            ownsGlobalHold = false
            restorationAttempts = 0
            restorationAt = 0
            return report(fault == nil ? .inactive : .blocked, .allowed)
        } catch {
            fault = .restorationFailed
            return report(
                restorationAttempts < Self.retryLimit ? .restoring : .blocked, backend.observe())
        }
    }

    private func report(_ phase: SleepPhase, _ observed: SleepObservation) -> SleepReport {
        SleepReport(phase: phase, observed: observed, ownsGlobalHold: ownsGlobalHold, fault: fault)
    }
}

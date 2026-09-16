# Architecture

## Executables and shared code

Limitless has a native menu-bar app, an unprivileged CLI, and a privileged Swift
helper. The common core contains deterministic policy/session logic, validation,
and the typed transport contract. Concrete types are the default; interfaces exist
only at OS boundaries that require test substitutes.

The helper owns reconciliation and deadlines independently of the panel. App and
CLI requests cross an authenticated XPC boundary. The CLI runs user commands under
the user's identity; the helper never receives a command to execute.

## Power management

Public IOKit assertions cover idle sleep prevention. Public IOPowerSources APIs
provide power information. ServiceManagement handles helper registration and login.
The undocumented global `pmset disablesleep` mechanism is confined to one backend;
its reads, writes and compatibility interpretation must not leak into UI code.

`MacSleepBackend` reads `SleepDisabled` on `IOPMrootDomain` through the public
IORegistry API. This property name is undocumented and is isolated with `pmset`.
Apple's powerd source writes the effective Boolean there; `pmset -g` can omit its
persisted preference when unset. Absence, a non-Boolean value or read failure is
unknown, never false. This proves only the reported flag, not physical lid support.
The backend uses the fixed executable `/usr/bin/pmset` and only `disablesleep 0/1`.
It clears inherited process environment and discards command output. The process
has a two-second execution timeout; termination gets up to another half second.
An unfinished child remains tracked, blocking another write. A successful command
gets up to one second for powerd propagation, then requires a matching observation.
These synchronous operations run only on the helper's serial worker.

`-b` allows battery only, `-c` AC only, `-a` both. Mismatched power temporarily
suspends an otherwise valid session, without extending its deadline. Returning to
an allowed source can resume it. Unknown source suspends rather than assuming AC.
A battery floor applies on battery or while the battery is discharging, including
an externally powered Mac whose adapter cannot keep up. No-battery and unreadable
battery are distinct states. The default floor is 20%; 0 explicitly disables it.

## Sessions and time

Each client demand has an independent identity, owner, policy and stop condition.
Relative durations use continuous monotonic time (including system sleep); absolute
dates use wall time and are re-evaluated after clock/wake notifications. Durations
have no arbitrary product maximum; invalid, nonfinite and unrepresentable values
are rejected. Presets are 5/10/15/30/45 minutes and 1/2/3/4/6/8/12/24 hours.

A user ceiling is enforced separately from client requests. CLI/AI cannot disable
battery protection, extend the ceiling, or re-enable stopped work by renewing a
lease. A liveness lease is not a user-visible duration limit: unlimited sessions
remain unlimited while their explicit owner remains alive and authorized.

At the battery floor, expiry, owner loss or explicit stop, the affected session is
terminated, not paused. Login/reboot never restore active demands. Closing the
popover does not terminate work; explicit Quit stops the sessions it controls.

## Reconciliation and recovery

Desired, admissible and observed states are separate. Re-read after each write,
power/wake events and a low-frequency watchdog. Never convert a read failure to
"off" or 100% battery. Do not turn a successful command exit into an applied-state
claim. On a known recoverable loss, permit a bounded retry while demands remain
eligible; ambiguous external interference suspends and needs user action.

Record ownership before the first write in a protected atomic journal. Refuse to
adopt an existing foreign hold silently. On helper restart restore owned state
before accepting new activation; do not recreate old sessions. A global flag has
no provenance, so concurrent writers cannot be perfectly arbitrated. An unavailable
helper/kernel can prevent timely restoration; report the failure and recovery path.

The controller permits at most three repairs per user rearm, with bounded backoff;
successful repairs do not replenish that allowance. Cleanup has its own three
attempts and backoff, independent of activation backoff, so stop starts immediately.
An exhausted cleanup keeps the ownership record and reports a blocked state.
Only explicit cleanup retry can reset that budget. Fault recovery never grants
activation permission. The persistent journal implementation and helper transport
are separate from the controller; controller tests substitute both OS and disk.
The concrete journal is now tested with real temporary files; helper transport
remains a separate delivery step.

`SecureOwnershipJournal` uses the fixed production directory
`/Library/Application Support/Limitless`, owned by root with mode 0700. It opens
each parent with `openat`/`O_NOFOLLOW`, verifies ownership and permissions, and
refuses extended ACLs instead of guessing whether they grant extra access. Journal
and lock files must be regular, singly linked, mode 0600 and owned by the expected
user. A lifetime `flock` prevents two helpers from holding the journal. Reads are
bounded to 1024 bytes and reject unknown versions or malformed records. Claims
use exclusive temporary files, atomic rename, metadata synchronization and macOS
`F_FULLFSYNC` before acknowledgment. Confirmed restoration removes the record with
the same durability barrier. It never changes existing permissions to make access
work. A test-only, module-internal constructor uses private temporary directories
under the test user's identity; it cannot be selected by a production client.

Restoration of an owned hold writes `disablesleep 0`; it does not rewrite ordinary
energy preferences or attempt to undo a foreign hold. On a Mac with an initially
unset preference, this leaves an explicit false value with the default sleep
behavior. The undocumented mechanism has no supported unset command.

## UI and development baseline

Initial target: macOS 26+, Apple Silicon, Swift 6 language mode. Use an Xcode/Swift
version supported by CodeQL for primary CI, with newer toolchains as compatibility
checks. App state belongs on MainActor; blocking subprocess work does not.
No persistent database, telemetry SDK, network service, web UI or custom UI framework.

## Sources examined

- [Apple pmset implementation](https://github.com/apple-oss-distributions/PowerManagement/blob/main/pmset/pmset.m): `disablesleep` uses system-wide settings rather than the selected source mask.
- [Inspected powerd implementation](https://github.com/apple-oss-distributions/PowerManagement/blob/d415e45501842834a280930c3eed9186544a67f0/pmconfigd/PMSettings.m#L1341): propagation of the effective Boolean to the root domain.
- [Apple idle versus forced sleep](https://developer.apple.com/library/archive/qa/qa1340/_index.html).
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice).
- [Sleepless 1.2.7](https://github.com/Aboudjem/Sleepless/tree/2a690e50724ffc17440ef58e5e0c9f69c82452fa): behavior studied, no source or assets incorporated.

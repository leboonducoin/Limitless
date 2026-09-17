# Architecture

## Executables and shared code

Limitless has a native menu-bar app, an unprivileged CLI, and a privileged Swift
helper. The common core contains deterministic policy/session logic, validation,
and the typed transport contract. Concrete types are the default; interfaces exist
only at OS boundaries that require test substitutes.

The helper owns reconciliation and deadlines independently of the panel. App and
CLI requests cross an authenticated XPC boundary. The CLI runs user commands under
the user's identity; the helper never receives a command to execute.

## Authenticated service

The application and CLI have separate Mach services (`.control` and `.tasks`),
under `io.github.leboonducoin.Limitless`. The corresponding executable identifiers
are `io.github.leboonducoin.Limitless`, `.cli`, and `.helper`. Both sides constrain
every XPC message with the public `setCodeSigningRequirement` API: an exact
identifier and the leaf signing certificate of the caller's own validated running
executable. All three executables must be signed with the same certificate.
The certificate can be self-signed; an Apple-issued identity is not required by
this transport. Ad-hoc and unsigned builds have no certificate and fail closed.
Requirements are parsed before Foundation receives them; identifiers are fixed
and certificate fingerprints accept exactly 40 ASCII hexadecimal characters.
Apple's requirement language uses SHA-1 as its certificate selector; release
archives use SHA-256. No PID-only signature check or private audit-token API is used.

Pinning establishes that peers have the same signer, not that Apple or a third
party has reviewed the app. Native admin approval must establish the installed
helper's trust. Certificate rotation requires removing the old installation with
its matching old app before installing the new signer; the existing guarded
upgrade/removal flow is retained. A new certificate from the same Apple Team ID
does not silently gain access to an old helper.

The helper also checks the kernel-provided effective UID against the current
console user, on admission and every reconciliation. Root and background users
are rejected. Switching users or logging out drops all demands and resets policy
to safe defaults, including disabled automation. Reconnecting never restores a
previous session or its authorization.

Requests use protocol version 2 and bounded JSON inside an XPC `Data` message. There are no
command, executable or path fields. The control endpoint can set policy, stop all,
explicitly rearm or retry cleanup. The task endpoint can only request a constrained
session, inspect state, renew liveness and release its own session. Owner UUIDs
and manual/task classification are assigned by the service. Connections and queued
requests are bounded to 64 each; one demand is allowed per connection. A task
connection cannot start a second demand after its first ends.

Clients renew a 30-second liveness lease every five seconds while responsible for
work. Heartbeats do not change the original deadline. Disconnection releases only
that owner's demand; an expired lease cannot be renewed. XPC interruption or a
ten-second client timeout closes the channel, with no automatic reacquisition.

The helper confines runtime state and all blocking backend calls to one serial
dispatch queue. Public power notifications trigger reconciliation; a two-second
watchdog (250 ms scheduling leeway) also checks telemetry, leases and deadlines.
This is not a hard real-time bound: scheduling, powerd propagation and bounded
restoration attempts can delay a confirmed stop. SIGTERM/SIGINT revoke demands
and attempt cleanup before exit; an unconfirmed stop retains the journal. A crash
or SIGKILL relies on the subsequent helper start to restore the journaled hold.

The Security requirement compiler and Foundation's XPC requirement setter accept
the certificate constraints in local tests. The executable and client compile
locally. Real same-signer/wrong-signer XPC exchange, native service
registration and privileged lifecycle tests have not yet been performed.

The CLI uses native `Process` termination for foreground commands and public
`proc_pidinfo` for existing processes. PID, UID, and start timestamp must continue
to match. Command arguments stay in the unprivileged process and are never part
of XPC or the journal. Normal completion requests an acknowledged release before
closing; a failed confirmation is reported without changing the command's exit
code. See [CLI and AI integration](cli.md) for the tracking boundary and signals.

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

`PowerSourceReader` uses only public IOPowerSources calls and keys. A failed list
or description read is unavailable; a successful empty list on AC identifies a
machine without an internal battery. Once an internal battery has been seen,
its disappearance becomes unavailable telemetry. Missing, ambiguous or incorrectly
typed fields never imply a healthy battery. Signed electrical current detects
discharge while an adapter is connected. UPS-provided power and multiple internal
batteries are conservatively unqualified in the initial hardware scope.

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
The concrete journal is tested with real temporary files; signed helper transport
still requires its dedicated Mac integration gate.

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

The SwiftUI `MenuBarExtra` uses an observable MainActor model and separate native
settings. Read-only status requests renew the app's lease every five seconds even
when the panel is closed. A process-bound manual session checks the same PID/UID/
start-time adapter as the CLI every second. Losing a connection clears that watcher
and never recreates a manual demand. A stale reading is visibly unavailable;
button actions are not reported as applied until the service returns its state.

The app persists only validated power/battery/duration preferences. Automation and
active demands are never persisted. Setting changes require an explicit Apply;
automation changes use the currently applied policy. Helper registration and login
registration have separate native controls. Quit requests an owned manual stop and
warns if restoration is unconfirmed; independently authorized CLI work can remain.
Debug presentation fixtures disable all external mutations and preference writes.
See [the interface contract](design.md) for visual and accessibility decisions.

## Removal

The application-only `prepareRemoval` operation revokes demands and seals the
session service against new activation, rearm or configuration. A shared core
predicate requires an explicit removal state, no sessions/owned hold, an observed
allowed flag and an inactive/blocked controller. The helper additionally verifies
that its idle assertion is absent before deleting the unowned journal directory.
Cleanup uses held directory descriptors, inode/device comparisons and nonrecursive
unlink operations. Unknown contents or ownership retain the directory. Once
cleanup begins, that journal instance permanently refuses new ownership writes.

For a helper running at the fixed SMJobBless installation path,
`InstalledHelperFiles` also captures its installed executable and launchd plist.
It validates root ownership, non-writable shared permissions, regular single-link
files without ACLs or special mode bits, parent identities, daemon label/program/
Mach services, and the helper's exact signing certificate. The certificate and
actual executable path come from Security's validated running-code information,
not command-line arguments. Before retiring the journal it captures and validates
both files; after journal cleanup it revalidates and unlinks only these two entries,
syncing their directories and volume. Replaced entries block removal; partially
removed entries remain tracked for retry. No parent directory is deleted.
Ready status requires completion of both journal and installed-file cleanup.
The app independently verifies absence of both fixed installed paths before
unregistration and before reporting completion, including when the helper is
unavailable. The SMJobBless installer/bundle routing remains to be implemented;
these paths are exercised only through unprivileged temporary-file tests so far.

The app unregisters both native services only after acknowledged cleanup, then
checks registration and absence again. The task endpoint has no removal privilege.
No executable, path or password crosses this boundary. See [distribution](distribution.md)
for the app hook, failure behavior and signed integration gates.

## Sources examined

- [Apple pmset implementation](https://github.com/apple-oss-distributions/PowerManagement/blob/main/pmset/pmset.m): `disablesleep` uses system-wide settings rather than the selected source mask.
- [Inspected powerd implementation](https://github.com/apple-oss-distributions/PowerManagement/blob/d415e45501842834a280930c3eed9186544a67f0/pmconfigd/PMSettings.m#L1341): propagation of the effective Boolean to the root domain.
- [Apple idle versus forced sleep](https://developer.apple.com/library/archive/qa/qa1340/_index.html).
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice).
- [NSXPCConnection code-signing requirements](https://developer.apple.com/documentation/foundation/nsxpcconnection/setcodesigningrequirement(_:)).
- [Sleepless 1.2.7](https://github.com/Aboudjem/Sleepless/tree/2a690e50724ffc17440ef58e5e0c9f69c82452fa): behavior studied, no source or assets incorporated.

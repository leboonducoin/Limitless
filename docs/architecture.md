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

## UI and development baseline

Initial target: macOS 26+, Apple Silicon, Swift 6 language mode. Use an Xcode/Swift
version supported by CodeQL for primary CI, with newer toolchains as compatibility
checks. App state belongs on MainActor; blocking subprocess work does not.
No persistent database, telemetry SDK, network service, web UI or custom UI framework.

## Sources examined

- [Apple pmset implementation](https://github.com/apple-oss-distributions/PowerManagement/blob/main/pmset/pmset.m): `disablesleep` uses system-wide settings rather than the selected source mask.
- [Apple idle versus forced sleep](https://developer.apple.com/library/archive/qa/qa1340/_index.html).
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice).
- [Sleepless 1.2.7](https://github.com/Aboudjem/Sleepless/tree/2a690e50724ffc17440ef58e5e0c9f69c82452fa): behavior studied, no source or assets incorporated.

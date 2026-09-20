# Architecture

| Module | Responsibility |
| --- | --- |
| LimitlessCore | Policy, independent sessions, deadlines and recovery decisions |
| LimitlessSystem | Power readings, XPC/signatures, process identity, installation and updates |
| LimitlessApp | SwiftUI panel, AppKit menu item, manual sessions and preferences |
| LimitlessCLI | Unprivileged commands, PID tracking and agent lifecycle hooks |
| LimitlessHelper | Serialized privileged requests and two-second watchdog |

No package dependencies, database, telemetry or additional product runtime.

## Authenticated service

App and task clients use separate XPC endpoints. Both directions validate the actual
leaf certificate and exact executable identifier. The listener rejects foreign
clients before allocating an owner. Ad-hoc signatures cannot communicate with the
helper. Self-signed publisher certificates are supported without pretending they
are Apple-notarized.

The helper assigns connection owners and binds them to the active console UID.
Requests are Codable data bounded to 128 KiB; wire version 4 rejects incompatible
peers. There are at most 64 clients and 256 sessions. A task connection can start
once. Its five-second heartbeat renews a 30-second liveness lease, never a deadline.
Disconnect, lease expiry or user switch releases ownership.

Only the app can configure policy, rearm, install the fixed CLI shortcut or prepare
removal. The helper accepts no command, executable path or arbitrary root operation.
User commands execute under the caller's identity and preserve their own streams.

## Sessions and time

Manual, command/PID and agent demands share one registry. Relative time uses a
continuous monotonic clock including sleep; calendar deadlines use wall time.
Limits are checked on admission and during reconciliation. A captured user duration
ceiling cannot be extended by later loosening settings.

Stop, expiry, battery cutoff and owner loss remove a demand permanently. Heartbeats
cannot resurrect it. Stop retains CLI permission; faults and removal revoke it.
The app remembers the user's CLI opt-in and reapplies it only to an idle,
fault-free helper through the authenticated app endpoint. Faults clear that
preference. No session is restored after login, reboot or reconnection.

Agent requests use both sources and at least 20% battery, constrained by stricter
user settings. An existing manual session rejects them. Starting a manual session
removes agent demands; those tasks never reacquire when the manual session ends.
Ordinary explicit command sessions remain independent.

## Agent lifecycle

The CLI consumes documented task events from Codex, Claude, Cursor, Gemini or a
manual adapter. Only event/session/turn IDs are decoded; no transcript,
prompt, command contents or credentials are stored.

Each real task starts an unprivileged CLI child with an empty, SHA-256-named marker
in the app's private cache. The child retains its XPC lease through thinking and
tool calls. Completion removes only the corresponding marker. Session exit removes
that session's markers. Host PID and start time provide a crash fallback, never an
activity heuristic. Closing the host ends its demands; an idle open host does not
start one.

Markers use exclusive creation, no-follow opens, owner/mode checks, an exclusive
lock and device/inode matching. Duplicate events cannot revive stopped tasks.
A replacement marker cannot be followed or removed by an old watcher.
Protection loss is final for that task even while its work continues.
Provider cancellation gaps and setup are documented in [CLI & AI](cli.md).

## Power management

`MacSleepBackend` alone contains the undocumented global `pmset disablesleep`
operation and `SleepDisabled` IORegistry observation. Missing or non-Boolean data is
unknown. Fixed executable/arguments, clean environment, bounded subprocess time and
a matching observation are required; a successful exit alone is not proof.

Apple's `caffeinate -i -w <helper PID>` runs alongside the global hold. The watchdog
checks its actual idle-sleep assertion using `IOPMCopyAssertionsByProcess` every
two seconds, not merely its PID. It creates no display assertion or fake activity.
Stop confirms the child's exit; helper exit also ends caffeinate through `-w`.

Public IOPowerSources APIs distinguish no internal battery from failed telemetry.
A previously observed battery disappearing becomes unavailable, not a desktop.
`-b` and `-c` are Limitless policies, not independent pmset switches. A source
mismatch suspends a live session without extending its deadline. Unknown data
suspends. Battery protection also applies to actual discharge on a weak adapter.
On a confirmed desktop, the app hides battery/source controls and uses Both.

## Reconciliation and recovery

Desired, eligible and observed states are separate. A foreign hold is never adopted
or cleared. Record ownership before changing power; restore only owned state.
The global flag has no provenance, so competing privileged writers remain a risk.

Recovery allows three repairs with bounded backoff. Cleanup has its own three
attempts and retains ownership on failure. Explicit rearm/retry cannot bypass
expiry or recreate a stopped demand. Startup restores journaled state first.

The root journal at `/Library/Application Support/Limitless` uses private
permissions, descriptor-relative no-follow traversal, ACL rejection, single-link
regular files, an exclusive lock, bounded reads, atomic replacement and durable
sync. Unknown contents or replaced paths fail closed. Confirmed restoration retires
the journal; no recursive root cleanup is allowed.

Restoring sleep writes `disablesleep 0`. There is no supported unset operation,
so an initially missing preference may remain explicitly false.

## macOS restart deferral

AppKit's quit Apple event distinguishes restart/shutdown from Quit and logout.
With an observed active, unexpired session, the open app can refuse ordinary
termination. Downloads/settings remain unchanged. Forced restarts and managed
deadlines can override this. A CLI alone cannot defer restart.
[AppKit termination](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/AppArchitecture/Tasks/GracefulAppTermination.html).

## Removal

The app first closes new admission and drains sessions. Restoration must be
observed and acknowledged before installed files are unlinked. The helper removes
only its exact fixed CLI symlink and signature-validated native helper files.
Directories, owners, modes, links and expected plist contents are rechecked.

The app independently verifies protected-state/file absence, allowed sleep,
unregistration and CLI-link removal before erasing preferences/cache and recycling
the app. A failed step stays visible and retryable. Updates retain preferences,
login registration and the fixed CLI link, but never active sessions.

## Sources examined

Independent implementation, inspired by [Sleepless](https://github.com/Aboudjem/Sleepless);
no imported code or assets. Apple references:
[caffeinate](https://github.com/apple-oss-distributions/PowerManagement/blob/main/caffeinate/caffeinate.c),
[code requirements](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html),
[SMJobBless](https://developer.apple.com/documentation/servicemanagement/smjobbless(_:_:_:_:)).

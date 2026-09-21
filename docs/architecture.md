# Architecture

| Module | Job |
| --- | --- |
| LimitlessCore | Policies, sessions, deadlines and recovery |
| LimitlessSystem | macOS power, signatures, XPC, processes and installation |
| LimitlessApp | SwiftUI menu, AppKit integration and preferences |
| LimitlessCLI | Commands, process tracking and AI hooks |
| LimitlessHelper | Privileged sleep operations and watchdog |

Swift throughout. No package dependencies, database or analytics.

## Sessions

The helper owns the shared session registry. Each authenticated connection owns
its demands; disconnect or a missed lease releases them. Heartbeats run every
5 seconds with a 30-second lease. Relative deadlines use a continuous clock.

Stop, deadlines, battery protection and owner loss outrank recovery. Sessions
never resume after login or reboot. CLI permission is remembered; faults revoke it.
AI uses both sources and at least 20% battery, within user limits. Manual sessions
reject or end AI holds. A stopped task cannot reacquire protection.

## Power

`MacSleepBackend` isolates the undocumented global `pmset disablesleep` flag.
Battery/adapter modes are policies, not independent macOS flags. Unknown readings
suspend protection. The helper also runs Apple’s `caffeinate` and checks its
assertion every two seconds. Recovery and restoration each allow three attempts.

Only owned state is restored. A protected root journal records ownership before
changes and survives interruption; invalid files fail closed. Competing privileged
tools can still change the global flag. Ordinary restart requests can be deferred
while the app is active; forced restarts remain outside its control.

## Trust and files

App and CLI use separate XPC endpoints. Both sides verify the exact executable ID
and certificate. Requests are bounded to 128 KiB, with 64 clients and 256 sessions.
The helper accepts no arbitrary command or path. It alone installs the fixed CLI
link. Root files use ownership, permissions, no-follow, locking and atomic writes.

The app-only Touch ID operation edits the fixed `sudo_local` file, never `sudo`.
It requires the standard macOS PAM stack, preserves password fallback and rejects
custom active rules. Owned metadata allows exact removal without undoing another
tool’s configuration. Updates keep it; uninstall removes only the owned block.

AI hooks read lifecycle IDs only. Private markers bind a task to its original
process and file identity. Setup merges only Limitless hooks, backs up existing
settings and refuses linked or invalid files. Removal preserves other integrations.

## Updates and removal

Checks and download attempts each wait at least eight hours, persisted across
launches. Failures back off to seven days; longer GitHub retry deadlines are
respected. Background errors stay quiet. No GitHub token is needed or stored.

Updates verify archive bounds, SHA-256, source metadata and pinned app/CLI/helper
signatures. They retain quarantine and a rollback backup. Removal closes admission,
confirms sleep restoration, removes the helper and owned CLI link, then clears
preferences and recycles the app. Failed cleanup stays visible and retryable.

## Apple certificate selector

[CodeQL alert 1](https://github.com/leboonducoin/Limitless/security/code-scanning/1)
is a reviewed exception: Apple’s certificate selector requires a SHA-1 fingerprint.
It identifies a public certificate; archive integrity uses SHA-256. Native
signature validation remains mandatory and the query stays enabled.
[Apple requirement language](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html).

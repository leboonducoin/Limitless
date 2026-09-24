# Architecture

| Module | Job |
| --- | --- |
| LimitlessCore | Policies, sessions, deadlines and recovery |
| LimitlessSystem | macOS power, signatures, XPC, processes and installation |
| LimitlessApp | SwiftUI menu, AppKit integration and preferences |
| LimitlessCLI | Commands, process tracking and AI hooks |
| LimitlessHelper | Privileged sleep operations and watchdog |
| LimitlessSudo / LimitlessSudoHelper | Separate sudo setup and privileged PAM changes |

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

The optional sudo component has its own app identity, icon and administrator
approval. Its helper belongs only to that component; Full Disk Access is not
requested for the menu app or power helper. Only the signed menu app of the
current console user can call its XPC endpoint. It accepts sudo settings and its
own cleanup, with eight clients and 1 KiB requests, then exits when idle.

The Touch ID operation edits the fixed `sudo_local` file, never `sudo`.
It requires the standard macOS PAM stack, preserves password fallback and rejects
custom active rules. Explicit disable can remove an existing Touch ID rule after
confirmation. Updates keep it; uninstall removes only Limitless’s owned block.
macOS permission refusals are separate from connection failures. The app offers
Full Disk Access guidance; it never grants access or retries the write automatically.

AI hooks read lifecycle IDs only. Private markers bind a task to its original
process and file identity. Setup merges only Limitless hooks, backs up existing
settings and refuses linked, shared-writable or write-ACL-controlled paths. Setup and
removal roll back the skill, marker and settings together. Removal preserves other integrations.

## Updates and removal

Checks and download attempts wait 12 hours, persisted across launches.
A manual check resets the 12-hour clock and has a
five-minute cooldown. Failures back off to seven days; longer GitHub retry deadlines are
respected, and a verified download resets its failure count. Invalid persisted counters are
discarded. Background errors stay quiet. No GitHub token is needed or stored.

Updates verify archive bounds, SHA-256, source metadata and all five executable
signatures, including the sudo component and helper. They retain quarantine and a rollback backup. Removal closes admission,
confirms sleep restoration, removes the helper and owned CLI link, then clears
preferences and recycles the app. Sudo cleanup runs in its own helper before
removing its service; updates preserve the setting. An update records whether the power helper
was enabled, restores it after relaunch and retries from the previous app if replacement fails.
Failed cleanup stays visible and retryable.

## Apple certificate selector

[CodeQL alert 1](https://github.com/leboonducoin/Limitless/security/code-scanning/1)
is a reviewed exception: Apple’s certificate selector requires a SHA-1 fingerprint.
It identifies a public certificate; archive integrity uses SHA-256. Native
signature validation remains mandatory and the query stays enabled.
[Apple requirement language](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html).

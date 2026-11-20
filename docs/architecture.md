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

The helper owns one shared protection session with a stable identifier until
its last request ends. Each authenticated connection owns its requests.
Disconnect or a missed lease releases them. Heartbeats run every
5 seconds with a 30-second lease. Relative deadlines use a continuous clock.

Stop, deadlines, battery protection, critical thermal load and owner loss outrank recovery. Sessions
never resume after login or reboot. The root helper remembers power limits and CLI
permission for each approved account. Faults revoke CLI permission and preserve the limits.
AI uses the selected power sources and at least 20% battery. Manual sessions
reject or end AI holds. A second app owner cannot create another manual session.
A stopped task cannot reacquire protection. If Stop ended automated work,
enable CLI access again before accepting new automated requests. The latest authorized deadline
determines the shared countdown when every request is bounded.

Only the authenticated app owning a manual session can extend its timer or date by
15 minutes. Extensions preserve the session ID, start time, power limits and original
duration ceiling. Expired or stopped sessions cannot be extended. Protocol 14 requires
matching app, CLI and helpers. A fresh helper rejects starts until the app reapplies
the saved power policy. The helper remembers CLI consent and its power limits in
root-owned preferences keyed by the console account's directory identity. App
preferences cannot grant access. Existing installations need one new approval.

## Power

`MacSleepBackend` isolates the undocumented global `pmset disablesleep` flag.
Battery and adapter modes are policies. Unknown power readings suspend protection.
The helper checks the system assertion from Apple's `caffeinate -i` and the display
assertion when the policy also requests `-d`. Keeping the display awake prevents
automatic idle locking. Manual locking and managed security policies stay under
macOS control. Assertions are released at the end, including suspension, thermal
cutoff and battery cutoff. Recovery and restoration each allow three attempts.

At critical thermal load the helper rejects new starts and releases existing
sessions. Cooling permits a new session. The most recent endings are held in
memory for the menu, notifications and CLI diagnosis.

The menu app reads the lid state and display list separately. Opt-ins for
display sleep and lid closure without an external display can mute the
selected output. It restores that output after wake or stop if the mute was confirmed.
Switching to a different output while the display stays asleep leaves the new output alone.
It honors an observed manual unmute until the next wake or session. An ambiguous
recovery record needs manual attention. Keyboard backlighting and Low Power Mode
remain under macOS control. Apple's public Low Power Mode API only reads state.

Optional hotspot fallback runs in the user app. It reads credentials from the
login Keychain, where it also stores permission to join automatically. Credentials
without explicit approval stay inactive. It looks for one exact WPA2 or WPA3
Personal match after a network
outage. It rechecks eligibility before joining. CoreWLAN association already in
progress completes under macOS control.

Only owned state is restored. A protected root journal records ownership before
changes and survives interruption; invalid files fail closed. Competing privileged
tools can still change the global flag. Ordinary restart requests can be deferred
while the app is active; forced restarts remain outside its control.

## Trust and files

App and CLI use separate XPC endpoints. Both sides verify the exact executable ID
and certificate. Requests are bounded to 128 KiB, with 64 clients and 256 sessions.
Up to 60 task connections may be admitted, and only eight task requests may be
pending, leaving capacity for app controls.
The helper accepts no arbitrary command or path. It installs the fixed system
CLI link only when its complete execution path and destination directory are
protected from local account writes. Otherwise the app verifies a copy of the
signed bundle in an owner-only per-account directory and uses that path for
CLI and agent setup. Root files use ownership, permissions, no-follow, locking
and atomic writes.
The app requests native administrator authorization for privileged removal, CLI
enablement, and changes to Touch ID. Each privileged service verifies the
authorization before it applies such a request.

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
process and file identity. A worker holds an exclusive lock during its turn.
Expired, unclaimed markers can be cleaned up after the startup grace period.
Setup merges only Limitless hooks, backs up existing
settings and refuses linked, shared-writable or write-ACL-controlled paths. Setup and
removal roll back the skill, marker and settings together. Removal preserves other integrations.

## Updates and removal

Checks and download attempts wait eight hours, persisted across launches. A detected update
starts downloading immediately while the app is idle. A manual check resets the eight-hour
clock and can retry a delayed download after a five-minute cooldown. Version checks fetch the
published `release.json` asset rather than GitHub's rate-limited REST API. Server retry deadlines
remain mandatory. Failures back off to seven days, and a verified download resets its failure
count. Invalid persisted counters are discarded. Background errors stay quiet. No GitHub token
is needed or stored.

Updates verify archive bounds, SHA-256, source metadata and all five executable
signatures, including the sudo component and helper. They retain quarantine and a rollback
backup until the replacement starts and verifies the required helper. If the existing
installation cannot be replaced by the current user, the app offers the release download.
Removal closes admission,
confirms sleep restoration, removes the helper and owned CLI link, then clears
preferences and recycles the matching signed app in Applications, even when macOS
launched a quarantined copy from App Translocation. The installed copy is verified
before cleanup and again before recycling. Sudo cleanup runs in its own helper before
removing its service; updates preserve the setting. Update preparation can be cancelled by the
same console user while the power helper's recovery record is still intact. An update records
whether the power helper was enabled, restores it after relaunch and retries from the previous
app if opening the replacement fails. Uninstall confirms normal sleep before handling audio
restoration or Keychain cleanup. Failed cleanup stays visible and retryable.

## Apple certificate selector

[CodeQL alert 1](https://github.com/leboonducoin/Limitless/security/code-scanning/1)
is a reviewed exception: Apple’s certificate selector requires a SHA-1 fingerprint.
It identifies a public certificate; archive integrity uses SHA-256. Native
signature validation remains mandatory and the query stays enabled.
[Apple requirement language](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html).
Community signatures also embed a designated requirement for the exact self-signed
anchor and executable identifier. Reciprocal app, CLI and helper authorization keeps
pinning the exact leaf certificate and identifier; neither requirement asks macOS to
trust a separately installed certificate.

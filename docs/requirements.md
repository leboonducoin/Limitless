# Requirements and release acceptance

This document preserves the complete product contract. A passing unit test proves
only its covered behavior. Items remain open until the evidence described below
exists. No public release or push is authorized by this document.

## Required product

| ID | Requirement | Required evidence | Status |
| --- | --- | --- | --- |
| R01 | Native Swift menu-bar app, SwiftUI/AppKit | Native build, UI inspection and keyboard/VoiceOver exercise | Open |
| R02 | Keep awake, including lid closed without an external display when supported | Backend tests and real MacBook lid-closed runs, version/model recorded | Open |
| R03 | Exclusive `-b`, `-c`, `-a` policies, enforced on source transitions | Policy/parser tests and physical AC/battery transitions | Core policy and CLI parser tested; hardware open |
| R04 | Observe applied state and recover in a controlled way | Backend failure, unknown state, bounded retry and ownership tests | Simulated controller tested; privileged integration open |
| R05 | Battery floor 0–50, step 1; 0 disables custom protection with warning | Boundary/serialization tests and UI/CLI warning checks | Core boundaries tested; UI/CLI open |
| R06 | Presets, custom duration, date/time, command/process completion, unlimited | Clock, expiry, process and UI tests; long-duration device check | Clock, CLI duration/date and process adapters tested; UI/integration open |
| R07 | Launch at login independent of activation | SMAppService integration and fresh-login inactive-state evidence | Open |
| R08 | Restrained Liquid Glass UI, original icon, discreet motion | Light/dark, contrast, reduced-motion/transparency and visual evidence | Open |
| R09 | Swift CLI and AI skill track actual work, release all completed tasks, obey user limits | Concurrent tasks, interruptions, stale owners, PID reuse and policy-boundary tests | CLI, process adapter and leases tested; skill validated; signed end-to-end open |
| R10 | Homebrew installation, clean distribution and complete uninstall | Fresh install, upgrade, active-session removal and zap verification | Open |
| R11 | Initial native administrator approval; never retain password | Signed helper approval/revocation and XPC authorization tests | Helper and signature constraints compile; signed approval/exchange open |
| R12 | Public-ready MIT repository with docs, tests, complete CI and security | Executed checks and release checklist, exact source/artifact linkage | Open |
| R13 | All authored executable code Swift; no Node/Python product runtime | Source and packaged-artifact inventory | Open |
| R14 | Public Apple APIs; isolate undocumented mechanism | Call-site audit, entitlement inspection and backend tests | Backend isolated; signed artifact audit open |
| R15 | Frequent local commits, maintained AGENTS.md, RTK for terminal work | Git history and maintained contributor instructions | In progress |

## Delivery sequence

1. Contributor instructions, MIT attribution, common core and initial CI.
2. Deterministic policy, sessions, timing and observed-state semantics.
3. Authenticated helper, power observation, narrow backend and recovery journal.
4. Menu-bar app, settings, login integration, original icon and native polish.
5. Command/process CLI, concurrent task ownership and AI skill.
6. Signed distribution, Homebrew integration and complete removal.
7. Complete security/CI audit and physical qualification; publication requires approval.

## Non-negotiable invariants

- `disablesleep` is global; `-b`/`-c` are Limitless policies, not presumed isolated
  backend switches. A policy change always triggers reconciliation.
- Explicit stop, expired deadline, exhausted battery allowance or revoked owner
  cannot be overridden by recovery, task renewal, launch at login or reboot.
- Only observed state is reported as applied. Unknown telemetry remains unknown.
- A command's exit and a process's identity are observed, not guessed from CPU usage
  or the continued existence of an agent application.
- CLI/AI requests can narrow user-authorized limits, never widen them.
- A terminated task releases only its own session; the last eligible demand releases
  the automatic hold. An explicit independent manual session remains independent.
- Privileged code never executes a user command or uses an arbitrary client path.
- A foreign global hold is reported, not silently adopted or removed.
- No safety guarantee depends on a reboot resetting an undocumented setting.
- No raw command arguments, task contents or credentials in persistent logs.

## Physical release matrix

Record Mac model, architecture, exact macOS/build, Limitless commit/version,
power source, expected result, observation and restoration result for each run:

- Lid open/closed, no external display, battery and AC for all three policies.
- AC attach/detach while active and while suspended; unknown/unstable telemetry.
- Battery floor, protection disabled warning, timed stop and manual stop.
- App/CLI/helper crash, owner loss, restart, reboot and login.
- Helper approval refused/revoked, invalid signature/client, service upgrade.
- Install, reinstall, upgrade, uninstall while active, and full preference cleanup.
- VoiceOver, keyboard-only use, contrast, dark/light appearance and reduced motion.
- Idle CPU/wakeups and sustained runtime; do not infer thermal safety from a flag.

## External prerequisites

Full Xcode; Apple Developer Program/Team ID and Developer ID Application signing
identity; notarization credentials stored outside Git; final bundle identifiers;
private vulnerability reporting; a Homebrew tap; authorized Mac integration tests.
The development environment currently has CLT Swift 6.4 and no detected usable
signing identity or full Xcode. Revalidate this before claiming a blocker persists.

# Requirements and release acceptance

This document preserves the complete product contract. A passing unit test proves
only its covered behavior. Items remain open until the evidence described below
exists. No public release or push is authorized by this document.

## Required product

| ID | Requirement | Required evidence | Status |
| --- | --- | --- | --- |
| R01 | Native Swift menu-bar app, SwiftUI/AppKit | Native build, UI inspection and keyboard/VoiceOver exercise | Builds and preview inspected; complete keyboard/VoiceOver open |
| R02 | Keep awake, including lid closed without an external display when supported | Backend tests and real MacBook lid-closed runs, version/model recorded | Live battery activation/restoration verified; physical lid-closed gate open |
| R03 | Exclusive `-b`, `-c`, `-a` policies, enforced on source transitions | Policy/parser tests and physical AC/battery transitions | Live battery/all activation and AC-only suspension on battery verified; physical source transitions open |
| R04 | Observe applied state and recover in a controlled way | Backend failure, unknown state, bounded retry and ownership tests | Live flag/ownership activation and restoration verified; fault/recovery simulations pass, live fault gate open |
| R05 | Battery floor 0–50, step 1; 0 disables custom protection with warning | Boundary/serialization tests and UI/CLI warning checks | Core boundaries, native single-step/draft isolation, signed zero warnings and refusal below user floor verified; live discharge cutoff open |
| R06 | Presets, custom duration, date/time, command/process completion, unlimited | Clock, expiry, process and UI tests; long-duration device check | Core/CLI tests, UI controls and signed command/PID completion, expiry and user-capped unlimited trials pass; remaining manual/date/long-duration gates open |
| R07 | Launch at login independent of activation | SMAppService integration and fresh-login inactive-state evidence | Actual registration/unregistration succeeded without a helper or awake session; fresh login/reboot open |
| R08 | Restrained Liquid Glass UI, original icon, discreet motion | Light/dark, contrast, reduced-motion/transparency and visual evidence | Original Swift artwork and native light/dark previews inspected; accessibility gates open |
| R09 | Swift CLI and AI skill track actual work, release all completed tasks, obey user limits | Concurrent tasks, interruptions, stale owners, PID reuse and policy-boundary tests | Signed command/PID completion, concurrency, expiry, user limits, refusals and continued work after protection/removal verified; live interruption/owner-loss/fault cases open |
| R10 | Homebrew installation, clean distribution and complete uninstall | Fresh install, upgrade, active-session removal and zap verification | Native helper lifecycle, cask style/strict audit and isolated local Homebrew install/removal pass after initial Gatekeeper block; download/upgrade/active Homebrew/zap gates open |
| R11 | Initial native administrator approval; never retain password | Signed helper approval/revocation and XPC authorization tests | Eight non-root cases and native signed inactive/active lifecycle pass; cancellation/revocation and restart gates open |
| R12 | Public-ready MIT repository with docs, tests, complete CI and security | Executed checks and release checklist, exact source/artifact linkage | Public docs and issue/PR templates implemented; local checks pass; hosted CI, provenance and release qualification open |
| R13 | All authored executable code Swift; no Node/Python product runtime | Source and packaged-artifact inventory | Source and signed community test bundle inventoried: 44 Swift files, three native executables, no Node/Python runtime; repeat for release artifact |
| R14 | Public Apple APIs; isolate undocumented mechanism | Call-site audit, entitlement inspection and backend tests | Source and signed test linkage inspected; public system frameworks, no entitlements, undocumented backend isolated; hardware qualification open |
| R15 | Frequent local commits, maintained AGENTS.md, RTK for terminal work | Git history and maintained contributor instructions | In progress |
| R16 | Usable distribution without the maintainer or users holding a paid Apple Developer membership; Developer ID is optional later | No-account authentication/installation review, GitHub download and dedicated Homebrew tap tested on a clean Mac | Local signing, native helper lifecycle and Homebrew install/CLI/removal pass without membership; initial Gatekeeper block observed; clean-Mac download and opening-flow qualification open |

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

Apple build tools; a stable signing identity and a qualified native installation
path for the no-account distribution; final bundle identifiers; private
vulnerability reporting; a Homebrew tap; authorized Mac integration tests.
Apple Developer Program membership, a Team ID, Developer ID Application identity
and notarization credentials are prerequisites only for the optional notarized
channel. End users never need developer membership. Do not silently reduce the
closed-lid, initial native admin approval, XPC authentication or removal requirements
to satisfy R16. See [distribution decisions](distribution.md#distribution-without-apple-developer-membership).
The development environment has CLT Swift 6.4 and no full Xcode. A dedicated local
test identity was created with explicit consent on 2026-09-17 and successfully
signed the community artifacts and XPC probes. Publisher identity management and
the native installation gates remain separate. Revalidate before claiming a blocker.

# Requirements and release acceptance

Limitless is an independent Swift macOS utility by Arthur Barreau, MIT licensed,
copyright © 2026. GitHub Releases is the only installation route; Homebrew was
removed by the maintainer's decision. Developer ID is optional later.

Source pushes to main and GitHub Actions are authorized. Physical trials belong
to the maintainer. Acceptance of earlier builds does not automatically qualify a
new binary. No public binary release is authorized by this document.

## Product contract

| ID | Required behavior | Acceptance evidence |
| --- | --- | --- |
| R01 | Native SwiftUI/AppKit menu-bar app | Build, native inspection, keyboard and VoiceOver |
| R02 | Awake with lid closed, no external display when supported | Real MacBook trials on each qualified OS/hardware |
| R03 | Exclusive battery, adapter and both modes | Policy tests and physical source transitions |
| R04 | Observe actual state; bounded recovery | Failure simulations and live fault/restoration trial |
| R05 | Battery limit 0–50%, step 1; zero warns | Boundary tests and real discharge cutoff |
| R06 | Presets, custom duration/date, process completion, unlimited | Clock/process tests and native timing trials |
| R07 | Launch at login independent of activation | Registration, fresh login and no resumed session |
| R08 | Compact native material UI, original icon, discreet motion | Native appearance/accessibility inspection |
| R09 | CLI and whole-task AI lifecycle, independent owners, manual priority | Policy/parser/process tests and actual agent lifecycle trials |
| R10 | One graphical GitHub download, complete uninstall | Clean download/open, upgrade and active/inactive removal |
| R11 | Initial native administrator consent, no password storage | Signed approval/refusal and reciprocal XPC tests |
| R12 | Public MIT repository, concise docs, CI and security gates | Actual final-commit checks and release evidence |
| R13 | All executable product/maintenance code Swift; no Node/Python runtime | Source and exported-artifact inventory |
| R14 | Public Apple APIs; isolated undocumented lid mechanism | Source/API and privilege review |
| R15 | Scoped commits, current contributor instructions | Reviewed history and AGENTS.md |
| R16 | Distribution without paid Apple membership | Stable certificate and clean-Mac native installation |

Implemented code and automated checks are recorded in [testing](testing.md).
Earlier signed installation, task and removal trials are retained in
[test history](testing-history.md). Open hardware/publication gates are not implied
passed by those results.

## Current interface and automation decisions

- Presets: 15/30/45 minutes, 1/2/4/8/12/24 hours and No limit in the timing picker.
- All preferences in the main panel, automatic application, one Stop button.
- Remaining PID list and task count; hide zero count outside process mode.
- Monochrome mark with a separate dark orange dot below/right, clear of the logo.
- Hide source/battery controls on confirmed desktops; hide battery limit in adapter mode.
- Right-click Quit/Uninstall, red confirmation, all app preferences removed.
- Enable CLI to install the plain `limitless` command automatically.
- Remember CLI opt-in, but never resume an awake session. Faults revoke consent.
- AI covers whole active turns including thinking, uses both sources and a 20%
  floor within user limits, and stands down for manual Keep awake sessions.
- Optional idle-only GitHub updates. No system-update setting changes; ordinary
  restarts may be deferred while the app observes an active session.

## Invariants

The lid flag is global: power modes are policies, not independent pmset settings.
Unknown readings stay unknown. Stop, battery cutoff, deadline and owner loss
outrank recovery. Restoring sleep changes only state owned by Limitless.

Each task releases only its own demand. The helper enforces user ceilings and
accepts no arbitrary command/path. User commands never run elevated. No stored
password, sudoers grant, security bypass or task-content logging.

Login/reboot cannot resurrect work. A running agent window is not proof of a task:
real lifecycle events are required. Provider cancellation gaps must be visible.

## Physical release matrix

Record model, architecture, macOS/build, source commit/version, source of power,
expected behavior, observation and restoration for each case:

- Lid open/closed without an external display; all three source policies.
- AC attach/detach, unknown telemetry, discharge while connected.
- Battery threshold/zero warning, timer, manual stop and long runtime.
- App/CLI/helper crash, owner loss, helper restart, reboot and login.
- Approval refused/revoked, invalid clients, service/channel upgrade.
- Fresh GitHub download/opening, reinstall and active/inactive full removal.
- Actual AI completion/cancel/error/host exit, concurrent tasks and manual priority.
- Keyboard, VoiceOver, contrast, light/dark and reduced motion/transparency.
- Idle CPU/wakeups. A reported flag is not a thermal-safety guarantee.

## External prerequisites

Apple build tools, a stable signing identity and a qualified clean-Mac installation
path are needed for community publication. Developer ID/notarization additionally
need active Apple membership, Team ID, certificate and notarization credentials.
Users need none of these developer credentials.

See [distribution](distribution.md) for exact build, signing and publication gates.

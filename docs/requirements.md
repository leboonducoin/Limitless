# Product contract

Limitless is Arthur Barreau’s MIT-licensed native Swift macOS utility. One GitHub
app download includes the menu, helper, CLI and AI skill. No paid Apple membership
is needed to use it. Developer ID/notarization can be added later.

- Keep awake, including closed-lid use without an external display where supported.
- Exclusive battery/adapter/both modes; battery reserve 0–50% in steps of 1.
- Presets: 15/30/45 min, 1/2/4/8/12/24 h; custom duration/date, processes, unlimited.
- Wait for all selected processes. Show remaining PIDs and per-second timing.
- Independent launch at login, immediate settings and complete uninstall.
- CLI and whole-task AI tracking, manual priority, no weakening user limits.
- Updates at most every eight hours; persistent throttling and idle installation.
- Optional Touch ID for sudo, explicit consent, password fallback and owned cleanup.
- Swift executables only; no Node/Python runtime, password storage or security bypass.

## Invariants

The lid flag is global. Missing telemetry stays unknown. Stop, battery cutoff,
deadlines and owner loss outrank recovery. Restore only Limitless-owned state.
No session may resume at login/reboot or after a cutoff. The helper accepts no
arbitrary command/path. Commands run without elevation.

## Acceptance checklist

The maintainer performs physical tests. Record the tested Mac/macOS, build and
outcome; successful trials on one machine do not promise all hardware behaves alike.

- Lid open/closed; no display; AC attach/detach; battery cutoff and long runtime.
- Timers, PID completion, Stop, app/CLI/helper exit, restart and login.
- Administrator refusal, setup, fresh download/opening, upgrade and full uninstall.
- Touch ID sudo success/cancel/password fallback; external changes only on request.
- Real agent completion/cancel/error, concurrent tasks and manual-session priority.
- Native light/dark UI, keyboard, VoiceOver, contrast and reduced motion.
- Final commit’s local checks, hosted CI/security, exported archive and signatures.

Publishing additionally needs a stable signing identity and verified release files.
Apple notarization needs membership, Team ID and credentials; users need none of
these. [Build and release commands](distribution.md).

# Product contract

This is the checklist for changes to Limitless. [Testing](testing.md) explains
how to verify them.

- One native Swift app for macOS 14+, Intel and Apple Silicon. GitHub download.
- Menu-bar controls, translucent appearance and accessible keyboard navigation.
- Keep awake with battery/adapter/both modes; closed-lid use where supported.
- Battery limit: 0–80%, typed or adjusted in one-percent steps. Zero disables custom protection.
- Reapply saved power limits after a helper restart before admitting new sessions.
- Timers, dates, unlimited sessions and waiting for all selected processes.
- Active sessions keep the display awake by default. Let the display sleep on request for background work.
- Stop all protection at critical thermal load. Read battery and thermal state independently.
- Distinguish a closed lid with and without an external display. Closed-lid and display-sleep audio muting are independent opt-ins with restoration of the owned output.
- Optional iPhone hotspot fallback uses an exact protected network, with credentials in Keychain.
- A Command-click starts the configured favorite when idle or only AI tasks are active,
  and extends the app's current timer by 15 minutes.
  The menu bar offers remaining time by default, end time, and icon only at the same width.
- Use one shared keep-awake session. Each request keeps its authorization, deadline and limits. A second app owner cannot start a separate manual session.
- Session notifications report approaching expiry and session endings. They default on
  at first launch, subject to macOS permission, and can be disabled.
- A small + button beside Stop adds 15 minutes per click to an owned timer or date session.
- CLI diagnosis and whole-task AI tracking that identify the provider and respect user limits and manual sessions.
- Helper approval enables launch at login in the same onboarding run. If the app
  is reopened before approval, users can enable launch at login in Options.
- Updates default on after helper approval: check every 8 hours and install immediately while idle.
- Optional Touch ID for sudo, native administrator consent and complete uninstall.

The sleep flag is global. Restore only state owned by Limitless. Stop, battery
protection, deadlines and owner loss take priority over recovery. Never resume a
session after login, reboot or a cutoff. Unknown readings stay unknown.

The helper accepts no arbitrary command or path. User commands run without
elevation. No stored passwords, security bypass or extra runtime.

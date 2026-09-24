# Product contract

This is the checklist for changes to Limitless. [Testing](testing.md) explains
how to verify them.

- One native Swift app for macOS 14+, Intel and Apple Silicon. GitHub download.
- Menu-bar controls, translucent appearance and accessible keyboard navigation.
- Keep awake with battery/adapter/both modes; closed-lid use where supported.
- Battery limit: 0–80%, typed or adjusted in one-percent steps. Zero disables custom protection.
- Timers, dates, unlimited sessions and waiting for all selected processes.
- CLI and whole-task AI tracking that respect limits and manual sessions.
- Helper activation enables launch at login. Users can disable it independently.
- Updates default on after helper approval: check every 8 hours and install immediately while idle.
- Optional Touch ID for sudo, native administrator consent and complete uninstall.

The sleep flag is global. Restore only state owned by Limitless. Stop, battery
protection, deadlines and owner loss take priority over recovery. Never resume a
session after login, reboot or a cutoff. Unknown readings stay unknown.

The helper accepts no arbitrary command or path. User commands run without
elevation. No stored passwords, security bypass or extra runtime.

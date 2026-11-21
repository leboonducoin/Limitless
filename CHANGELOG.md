# Changelog

## 1.2.0 — Unreleased

Upgrading from 1.1 or earlier requires a manual download. If you use Limitless
with a terminal or AI agent, follow the
[CLI migration instructions](https://github.com/leboonducoin/Limitless/blob/main/docs/cli.md#upgrading-from-11-or-earlier)
before installing 1.2.

### Menu bar and keyboard

- Use Limitless directly from the menu bar. The popover responds on the first click and keeps session controls visible while Options scrolls beneath them.
- Open Options from the whole row, including the label and icon. Settings are grouped by purpose, Power source comes first in Power, and Options collapses when the popover closes.
- Command-click starts your favorite duration when idle or when only CLI or AI tasks are active. During your own timer or dated session, it adds 15 minutes within your limits.
- Use Command-Return to start, Command-Plus to extend, and Command-Period to stop. Tab, Space, and Escape work in the popover.
- Choose remaining time, end time, or an icon alone. Remaining time is the default and shows `00h` when less than an hour remains. All three modes keep the same menu-bar width and show an orange Limitless mark during protection.
- Get a reminder in the final five minutes and a notification with the reason when the shared session ends. Notifications default to on at first launch and follow macOS permission and your setting. Short sessions can also report their ending.

### Sessions, power, and the lid

- Concurrent CLI and AI requests share one keep-awake session while keeping their own deadlines and limits. A manual session takes priority so automated requests cannot extend it.
- The helper restores approved power limits after a restart, including when CLI access is off. After upgrading from 1.1 or earlier, review your power limits in Options once.
- Critical thermal state ends protection and blocks new starts until macOS reports that it has cooled. Battery cutoffs and session deadlines continue to apply.
- Keep the display awake or let it sleep during a session. Limitless distinguishes a closed lid with an external display from a closed lid without one.
- Opt in to muting audio when the display sleeps or when the lid closes without an external screen. Limitless restores the mute it applied to the original output and preserves a mute you set yourself.
- Enable optional iPhone hotspot fallback for a specific password-protected network. Connect to the hotspot once to save its access point. Credentials stay in the local Keychain. Limitless checks that the session is still eligible before scanning and again before joining.
- Out-of-range timer values are rejected before a session starts, and old out-of-range values can be displayed safely.

### CLI and AI integrations

- `limitless doctor` reports the authenticated helper, active protection, power and thermal readings, and protocol. Copy diagnostics from the menu when reporting a problem.
- See which agent or provider is keeping the Mac awake, alongside any manual request. The bundled skill explains how lifecycle hooks protect Codex, Claude, Cursor, and Gemini tasks and how their protection ends.
- Recover abandoned task markers while preserving the markers used by active workers. Disabling or removing a Limitless integration leaves unmanaged agent configuration alone.
- Changing CLI access leaves your power limits in place. The helper remembers power limits and requires fresh approval for CLI access after it restarts or the console account changes. Protocol 14 requires the app, CLI, and helpers from the same release.

### Updates, cleanup, and verification

- Recover safely from interrupted updates. The previous installation stays available until the new app starts and its power helper is confirmed when required.
- Keep update recovery state in Keychain. Preserve backups from the older updater and unrelated recovery records. Offer a manual download when Limitless cannot confirm its recovery state.
- Offer a manual download when the installed app cannot be replaced automatically. Automatic updates still require an idle session and a matching signing identity.
- Restore normal sleep during uninstall before handling audio or Keychain errors. Existing external Touch ID settings are preserved during uninstall.
- Uninstall requires confirmation in the menu. The helpers verify macOS administrator approval before removing system components, granting CLI access, or changing Touch ID for sudo.
- Reserve space for app controls even when many CLI or agent tasks connect.
- Automated sessions yield to an ordinary macOS restart or shutdown.
- Install a protected CLI per account when the shared application or command directories are writable. Use **Migrate CLI & agent hooks…** in Options to retire the old shortcut and update Limitless hooks in that account.
- Keep hotspot consent with the saved credential in Keychain. Preserve the access restrictions on agent settings and avoid copying extra files into the release.
- Remove both current and older saved hotspot credentials when forgetting a hotspot or uninstalling Limitless.
- Stop ends the session and withdraws CLI and agent approval. Re-enable CLI access in Options to start new automated work.
- Keep the automatic-update choice and retry schedule in Keychain. Review your automatic-update preference after upgrading from an older release.
- Respect the choice to disable launch at login. If you quit during helper approval, you can enable launch at login separately in Options.
- Add regression tests for session ownership and timing, thermal limits, hotspot cancellation, audio restoration, and update recovery. CI checks Swift compilation, sanitizers, dependencies, workflows, and secrets.
- Add an interactive demo and GitHub workflows that attest inert preview archives and verified distribution packages.
- Pin release packaging to the project's Apple Developer Team. Reject unsupported PAM file bytes before changing Touch ID for sudo.
- Verify update and Touch ID components in private copies before launching them. Verify signed archives and their checksums again after export.

## 1.1.0 — 2026-10-21

- Keep the display awake during eligible sessions to prevent automatic idle locking, and verify both display and system assertions. Manual locking remains available.
- Add a small circular + beside Stop to extend an owned timer or date by 15 minutes per click. Rapid clicks accumulate; Stop discards pending additions. Existing policy ceilings and cutoff protection remain in force.
- Require protocol 11 across the app, CLI and helpers. Moving to an Apple Developer ID signature requires manual removal with the previous app before installing the new archive.

## 1.0.5 — 2026-09-25

- Resolve the installed app from its verified `/Applications/Limitless.app` copy when macOS launches a quarantined update from a read-only translocated path. Update recovery and uninstall no longer target the translocated copy.
- Verify the installed app's signed build record before removing integrations, and recheck it before moving the app to Trash. If Trash fails, select the installed app in Finder for manual removal.
- Add signed update fixtures for an altered build record and a translocated running copy.

## 1.0.4 — 2026-09-25

- Read the public `release.json` asset instead of GitHub's rate-limited releases API. Update checks no longer consume the anonymous REST API quota or require a GitHub token.
- Explain a manual check that is already running, temporarily delayed, or unable to reach the release metadata instead of reporting every case as a generic failure. A delayed check shows when it can run again.
- Reject a downloaded update if the revision in its signed `Build.json` differs from the revision advertised in `release.json`, in addition to the existing archive hash and signature checks.
- Keep the power-source selector inside the menu's fixed width when the app first opens, an update becomes available, or Automatic updates changes. The selector now sits below its label.
- Let macOS remember a Command-dragged position for the menu-bar icon across app launches.
- Run the power helper with launchd's adaptive process type to improve reconnection after login. Client authentication and session policy are unchanged.
- Add regression coverage for update checks, archive identity, menu layout, and helper metadata.

If an older copy cannot complete its update check, install 1.0.4 manually from the release archive. Versions 1.0.0–1.0.2 have known updater problems; 1.0.3 can fail its check when GitHub's anonymous API limit is reached.

## 1.0.3 — 2026-09-25

- Check for updates every eight hours and start an available automatic update immediately when the app is idle. Failed checks and downloads use increasing delays rather than rapid retries.
- Hide the inline Update button during a retry delay; right-click the menu-bar icon to request a fresh check.
- Accept the bundled `Limitless Sudo.app` during secure archive extraction while continuing to reject unexpected archive paths.
- Keep the power-source selector stable while the menu opens.
- Pin the community certificate's self-signed anchor in code signatures, so verification does not depend on that certificate being installed on the user's Mac.

## 1.0.2 — 2026-09-24

- Protect Codex, Claude, Cursor and Gemini setup files against symlink substitution and path changes during reads and writes.
- Roll back managed skills, markers and provider configuration if setup or removal fails partway through; preserve unrelated user configuration.
- Restore the previous app and helper when an update replacement fails, and reset download backoff after a successful update.
- Add twice-weekly CI/Security runs, on Monday and Friday, alongside push and pull-request checks.

## 1.0.1 — 2026-09-24

- Add the showcase film, screenshots, original MP3/WAV soundtrack and source assets to `assets/`.
- Enable helper-assisted automatic updates with a 12-hour check interval in this version, plus a manual check and install action from the menu-bar app. Version 1.0.3 later changed the interval to eight hours.

## 1.0.0 — 2026-09-23

- Ship the native menu-bar app and companion CLI for Intel and Apple Silicon Macs running macOS 14 or later.
- Start and stop explicit keep-awake sessions, including closed-lid operation where macOS and the hardware allow it. End a session after a duration, at a date, or when all selected processes exit.
- Choose battery, power adapter or both, with a configurable battery reserve; no session resumes automatically after login or reboot.
- Allow the CLI and Codex, Claude, Cursor or Gemini task hooks only after opting in. Manual sessions retain priority over AI tasks.
- Install a separately approved privileged power helper. Optionally enable launch at login, updates, and Touch ID for sudo with the normal password path preserved.
- Uninstall the app and its owned integrations from the menu bar.

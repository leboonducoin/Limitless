# Changelog

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

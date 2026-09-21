# Limitless

**Keep your Mac awake. Close the lid. Let the work finish.**

[![CI](https://github.com/leboonducoin/Limitless/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/leboonducoin/Limitless/actions/workflows/ci.yml)
[![Security](https://github.com/leboonducoin/Limitless/actions/workflows/security.yml/badge.svg?branch=main)](https://github.com/leboonducoin/Limitless/actions/workflows/security.yml)
[![MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-111111.svg)](docs/distribution.md)

I made Limitless to keep my Mac awake while it works. A small, native macOS
menu-bar app, written in Swift. Free, open source, no account needed.

<p align="center">
  <img src="docs/images/menu-preview.png" width="340" alt="Limitless on macOS: active keep-awake session, timer, power source and battery protection">
</p>

## Install

**Apple Silicon · macOS 26 or later**

[GitHub Releases](https://github.com/leboonducoin/Limitless/releases) is the only
download location. The first public archive has not been published yet.

Once available: unzip **Limitless.app**, drag it to **Applications**, then open it.
The icon appears in your menu bar. Click **Enable Limitless** and approve the
macOS administrator prompt. Your password is never stored.

On first opening, macOS may ask you to allow the app in **System Settings →
Privacy & Security → Open Anyway**. [Apple’s instructions](https://support.apple.com/en-gb/102445).

## Use it

Choose a duration and click **Keep awake**. The orange dot means it is active.

- Stop after a timer, at a date, or when all selected processes finish.
- Choose battery, power adapter, or both. Reserve 20% battery by default.
- Keep awake with the lid closed, without an external display on compatible Macs.
- Let Codex, Claude, Cursor or Gemini keep your Mac awake during their tasks.
- Enable launch at login and automatic updates if you want them.
- Optionally use Touch ID for sudo, with password fallback.

Right-click the icon to **Quit** or **Uninstall**.

For the terminal and AI integrations, enable **Allow CLI & AI tasks** in the app:

```sh
limitless --help
limitless status
```

[CLI and one-command AI setup →](docs/cli.md)

## Good to know

Keeping your Mac awake uses battery. Limitless stops at your battery limit;
setting it to 0 disables that protection. Keep the Mac ventilated, especially
with the lid closed.

Closed-lid behavior depends on macOS and your Mac. Forced restarts and company
management policies can interrupt a session. Launch at login never resumes one.

---

By [Arthur Barreau](https://www.linkedin.com/in/arthurbarreau/).
[MIT](LICENSE) · © 2026 Arthur Barreau · [Contribute](CONTRIBUTING.md) · [Security](SECURITY.md)

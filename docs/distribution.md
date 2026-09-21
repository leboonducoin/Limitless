# Installation

**macOS 14+ · Intel & Apple Silicon**

1. Download the app from [GitHub Releases](https://github.com/leboonducoin/Limitless/releases).
2. Unzip it, drag **Limitless.app** to **Applications** and open it.
3. Click its menu-bar icon, then **Enable Limitless**. Approve the macOS prompt.

The first public archive has not been published yet.

The same download includes the app, CLI and AI skill. Launch at login turns on
after helper approval. You can turn it off; it never starts a keep-awake session.
Enable **Allow CLI & AI tasks** to use the [terminal and AI integrations](cli.md).

If macOS blocks opening, use **System Settings → Privacy & Security → Open Anyway**
when offered. [Apple's instructions](https://support.apple.com/en-gb/102445).

## Touch ID for sudo

Enable it in the menu to use your fingerprint for `sudo`. Your password still
works. This is a Mac-wide setting; it does not change Limitless's administrator
prompt. Remote sessions may still need a password.

## Updates and removal

Automatic updates are optional. Otherwise, an **Update** button appears when a
version is available. Updates install when no session is running.

Right-click the menu-bar icon → **Uninstall Limitless**. This stops sessions and
removes the app, helper, CLI shortcut, login item, preferences and AI integrations
installed by Limitless. Existing Touch ID settings and recovery backups are kept.

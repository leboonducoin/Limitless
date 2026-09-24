# Installation

**macOS 14+ · Intel & Apple Silicon**

1. Download the app from [GitHub Releases](https://github.com/leboonducoin/Limitless/releases).
2. Unzip it, drag **Limitless.app** to **Applications** and open it.
3. Click its menu-bar icon, then **Enable Limitless**. Approve the macOS prompt.

The same download includes the app, CLI and AI skill. Launch at login turns on
after helper approval. You can turn it off; it never starts a keep-awake session.
Enable **Allow CLI & AI tasks** to use the [terminal and AI integrations](cli.md).

If macOS blocks opening, use **System Settings → Privacy & Security → Open Anyway**
when offered. [Apple's instructions](https://support.apple.com/en-gb/102445).

## Touch ID for sudo

Enable it in the menu to use your fingerprint for `sudo`. Your password still
works. This is a Mac-wide setting; it does not change Limitless's administrator
prompt. Remote sessions may still need a password.

The first change installs a separate **Limitless — Touch ID for sudo** component,
with its own administrator approval. If macOS blocks the change, click **Open Full
Disk Access**. In Settings, enable the entry ending in **Limitless.sudo.helper**,
then return to Limitless and retry the toggle.

Keep the main app and sleep helper disabled in that list. You can revoke the sudo
helper's access afterward; changing Touch ID or removing its rule needs it again.
This remains a broad macOS permission, held by the separate sudo helper.

## Updates and removal

Automatic updates turn on with the helper and can be disabled. Otherwise, an **Update** button appears when a
version is available. Limitless checks every 12 hours. Right-click the menu-bar
icon → **Check for Updates** to check now and install an available update while
idle. A manual check resets the 12-hour timer. Checks and downloads use the same
12-hour interval. Limitless verifies the download, then installs and reopens the app.
If the helper was enabled, the reopened version restores it; a failed replacement reopens
the previous app so the same recovery can run.

Right-click the menu-bar icon → **Uninstall Limitless**. This stops sessions and
removes the app, helper, CLI shortcut, login item, preferences and AI integrations
installed by Limitless. Existing Touch ID settings and recovery backups are kept.

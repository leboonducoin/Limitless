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

If macOS blocks the change, open **System Settings → Privacy & Security → Full
Disk Access**, enable **Limitless**, reopen the app and retry. This permission is
for changing sudo; keeping the Mac awake does not require it. You can revoke it
afterward, but changing Touch ID again or removing Limitless's rule needs it again.

## Updates and removal

Automatic updates are optional. Otherwise, an **Update** button appears when a
version is available. Limitless checks at most once every 24 hours. It verifies
the download, waits until no session is running, then installs and reopens the app.

Right-click the menu-bar icon → **Uninstall Limitless**. This stops sessions and
removes the app, helper, CLI shortcut, login item, preferences and AI integrations
installed by Limitless. Existing Touch ID settings and recovery backups are kept.

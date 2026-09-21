# Installation & releases

Download the app from [GitHub Releases](https://github.com/leboonducoin/Limitless/releases),
unzip it, move it to **Applications** and open it. Apple Silicon, macOS 26+.
The first public archive has not been published yet.

The download includes the menu-bar app, helper, CLI and AI skill. No developer
account or extra runtime is needed. Enable Limitless through its native macOS
administrator prompt. Enable CLI separately in the menu.

If macOS blocks first opening, use **System Settings → Privacy & Security →
Open Anyway** when offered. Managed Macs may refuse it.
[Apple’s instructions](https://support.apple.com/en-gb/102445).
Never remove quarantine or disable macOS security checks.

Right-click the menu-bar icon to uninstall. This restores sleep, removes the helper,
CLI shortcut, login item, preferences and owned AI integrations, then moves the app
to Trash. Configuration backups remain available for recovery.

## Signing

The community channel uses a stable publisher certificate and native SMJobBless
approval. App, CLI and helper verify that same certificate and their exact IDs.
This signature is separate from Apple notarization; ad-hoc builds cannot control
sleep. Keep the signing key outside Git and never change system trust to install.

Developer ID and notarization can be added later with a paid Apple membership.
Changing the signing identity requires uninstalling the old helper with its matching
app first. GitHub remains the download location.

## Build

```sh
swift Tools/ProjectTool.swift bundle
swift Tools/ProjectTool.swift preview
```

Both create new temporary output directories. `preview` also exports a sharp PNG
using the real SwiftUI/AppKit views. These inert Debug builds install nothing.
`LIMITLESS_PREVIEW_STATE` selects another fixture; `LIMITLESS_OUTPUT_DIR` selects a
new output directory. On a synced Desktop, set `LIMITLESS_BUILD_PATH` to a temporary
build path.

## Community release

From a clean commit, set `LIMITLESS_SIGNING_IDENTITY` to the existing certificate’s
40-character fingerprint. `LIMITLESS_OUTPUT_DIR` selects a new output directory.

```sh
swift Tools/ProjectTool.swift community-sign
swift Tools/ProjectTool.swift community-verify APP_PATH CERT_SHA1
swift Tools/ProjectTool.swift community-package APP_PATH CERT_SHA1 NEW_OUTPUT_DIRECTORY
```

Packaging re-extracts and verifies the ZIP, then writes `SHA256SUMS` and `release.json`.
Publish these together under `vVERSION`, after the exact commit’s CI/security and
[Mac acceptance checks](requirements.md#acceptance-checklist). Local commands do
not publish. Increment the build and align the app/CLI version before signing.

For Developer ID, also set `LIMITLESS_TEAM_ID` and select full Xcode:

```sh
swift Tools/ProjectTool.swift sign
swift Tools/ProjectTool.swift notarize APP_PATH TEAM_ID KEYCHAIN_PROFILE
swift Tools/ProjectTool.swift verify APP_PATH TEAM_ID
swift Tools/ProjectTool.swift package APP_PATH TEAM_ID NEW_OUTPUT_DIRECTORY
```

`notarize` uploads to Apple, requires an Accepted result and staples the ticket.
Check an existing submission before retrying a timeout. Credentials stay in Keychain.
[Apple’s workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

## Updates

Checks and downloads are each limited to one attempt every eight hours, even after
relaunch. Repeated failures increase the wait; GitHub retry deadlines take priority.
The unauthenticated API quota is shared by the public IP, including other tools on
the same network. [GitHub limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api).

Automatic installation is optional and waits until idle. A newer marketing version
is required. Updates preserve quarantine, verify all three signatures and keep a
rollback backup. A new certificate/channel always requires manual installation.

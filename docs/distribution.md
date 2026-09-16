# Build, installation and removal

Limitless is not yet published or qualified for privileged installation. The
commands below create development artifacts, not a production installer. Do not
register a development helper or bypass Gatekeeper to make it run.

## Local app bundle

From the repository root, using the selected Apple toolchain:

```sh
rtk proxy swift Tools/ProjectTool.swift bundle
```

The tool prints a new temporary output directory. Set `LIMITLESS_OUTPUT_DIR` for
a chosen output parent; an existing `Limitless.app` is refused rather than replaced.
On a synced Desktop, keep build output outside the sync provider:

```sh
rtk proxy env LIMITLESS_BUILD_PATH=/private/tmp/limitless-swift-build LIMITLESS_OUTPUT_DIR=/private/tmp/limitless-preview swift Tools/ProjectTool.swift bundle
```

Use `LIMITLESS_CONFIGURATION=release` for an optimized bundle. Both configurations
are signed ad hoc for local inspection. This signature does **not** satisfy the
app/helper's required Apple signing identity. Power and login controls stay disabled.
Nothing is copied to Applications, no service is registered and no login item is
changed. The bundle includes:

| Path within `Limitless.app/Contents` | Purpose |
| --- | --- |
| `MacOS/LimitlessApp` | SwiftUI/AppKit menu-bar executable |
| `MacOS/limitless` | Unprivileged Swift command/process CLI |
| `Library/HelperTools/LimitlessHelper` | Swift privileged service; not registered by the build |
| `Library/LaunchDaemons/io.github.leboonducoin.Limitless.helper.plist` | SMAppService bundled-daemon declaration |
| `Resources/Limitless.icns` | Original artwork exported by Swift/AppKit at native icon sizes |
| `Resources/limitless-skill` | Distributable AI instructions |
| `Resources/LICENSE` | MIT attribution |

`Tools/ExportIcon.swift` shares `BrandArt.swift` with the app. No generated image
runtime, downloaded image, Node or Python is packaged. The bundle command runs
strict Swift formatting/build checks, `iconutil`, `plutil -lint` and recursive strict
signature verification. CI builds a Release bundle; CodeQL includes both Swift
maintenance tools. This is structural validation, not notarization or installation.

## Read-only UI inspection

A Debug bundle supports a labeled presentation fixture:

```sh
rtk proxy /private/tmp/limitless-preview/Limitless.app/Contents/MacOS/LimitlessApp --preview active
```

Available states are `active`, `inactive`, `suspended`, `restoration` and `unknown`.
Add `--light` for an app-local light appearance, or `--light --contrast` for AppKit's
high-contrast light appearance. These flags never change system preferences and
are absent from Release behavior. Draft controls remain inspectable, while all
power, policy, helper and login mutations are disabled. See [testing](testing.md)
for observed evidence and remaining keyboard/accessibility gates.

## Production prerequisites and acceptance

Production packaging still requires a Developer ID Application identity, confirmed
team/bundle identifiers, hardened-runtime signing of each executable, notarization
and stapling, and verification on a clean Mac. Credentials stay in the keychain or
protected CI secrets, outside Git. No artifact upload or release is authorized by
this document. A source hash, version and signed artifact digest must agree before
publication. Do not publish the ad-hoc bundle or invent a downloadable release URL.

The Homebrew cask and complete removal flow remain to be implemented and exercised.
Installation must preserve macOS approval; a cask must not run `sudo pmset`, install
passwordless sudoers rules or disable quarantine. Native first launch separately
requests helper approval and offers launch at login.

Removal must revoke all sessions, confirm restoration of Limitless-owned state,
unregister the helper and login item, then remove the app, CLI link and optional
preferences/skill. An unresolved ownership journal must stop destructive removal.
Never promise that deleting an app or rebooting clears the undocumented global
flag. Active-session uninstall, upgrade, approval rejection and interrupted cleanup
remain required tests before a Homebrew release is usable.

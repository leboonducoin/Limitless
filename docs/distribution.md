# Build, installation and removal

Limitless is not yet published or qualified for privileged installation. The
commands below create development artifacts, not a production installer. Do not
register a development helper or bypass Gatekeeper to make it run.

## Distribution without Apple Developer membership

**User decision, 2026-09-16:** Apple Developer membership will come later. Limitless
must also be usable through GitHub or a dedicated Homebrew tap before then. Users
must never need their own developer membership. The Developer ID commands below
remain an optional future channel, not the only acceptable product distribution.

The current code is not ready for this complete route. `SignedIdentity` now pins
the exact peer identifier and the executable's own signing certificate, including
a self-signed certificate, but setup still uses `SMAppService.daemon`. The installed Apple
SDK's public `SMAppService.h` explicitly requires notarization for apps containing
LaunchDaemons. Simply removing the Team ID check would neither qualify installation
nor preserve helper authentication. Ad-hoc development bundles remain disabled
while that boundary is redesigned.

The certificate requirements compile and are accepted by Foundation's XPC setter
in local tests; a bundle identifier or UID alone remains insufficient. Real
same-certificate/wrong-certificate exchange and native administrator approval
still need integration evidence. Apple's code-signing requirements support a
self-signed certificate pin; that does not prove a complete installation flow.
[Apple certificate requirements](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html).

The installation review must compare the current documented `SMAppService` contract
with native alternatives, including the older public `SMJobBless` API, which is
deprecated. No choice is considered qualified until signature exchange, approval,
upgrade, restoration and full removal are exercised on a real Mac. Keep the shared
session/controller/backend and all user limits; do not add a password field,
passwordless sudoers rule, unsigned-client acceptance or an arbitrary root executor.
[Apple SMJobBless contract](https://developer.apple.com/documentation/servicemanagement/smjobbless(_:_:_:_:)).

For downloaded non-notarized apps, macOS may require a user decision in Privacy &
Security; managed systems may disallow it. That choice must remain with the user.
The app and cask must not remove quarantine, disable Gatekeeper or automate approval.
[Apple opening policy](https://support.apple.com/en-gb/102445).
The official `homebrew/cask` catalogue requires passing its Gatekeeper checks;
distribution from our own reviewed tap is a distinct channel and cannot claim
official-catalogue acceptance. No tap or downloadable release exists yet.
[Homebrew acceptance policy](https://docs.brew.sh/Acceptable-Casks).

## Local app bundle

From the repository root, using the selected Apple toolchain:

```sh
rtk proxy swift Tools/ProjectTool.swift bundle
```

The tool prints a new temporary output directory. Set `LIMITLESS_OUTPUT_DIR` for
a chosen new output directory; an existing directory is refused rather than replaced.
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
| `Resources/Build.json` | Source revision, configuration and worktree cleanliness |

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

## Notarized-channel prerequisites and acceptance

The optional notarized channel requires a Developer ID Application identity, confirmed
team/bundle identifiers, hardened-runtime signing of each executable, notarization
and stapling, and verification on a clean Mac. Credentials stay in the keychain or
protected CI secrets, outside Git. No artifact upload or release is authorized by
this document. A source hash, version and signed artifact digest must agree before
publication. Do not publish the ad-hoc bundle or invent a downloadable release URL.

The Swift release tooling and Homebrew template are implemented; they have not
produced a signed or notarized release. The native removal flow is implemented,
with session/filesystem tests; its signed ServiceManagement lifecycle has not
been exercised.
Installation must preserve macOS approval; a cask must not run `sudo pmset`, install
passwordless sudoers rules or disable quarantine. Native first launch separately
requests helper approval and offers launch at login.

Removal must revoke all sessions, confirm restoration of Limitless-owned state,
unregister the helper and login item, then remove the app, CLI link and optional
preferences/skill. An unresolved ownership journal must stop destructive removal.
Never promise that deleting an app or rebooting clears the undocumented global
flag. Active-session uninstall, upgrade, approval rejection and interrupted cleanup
remain required tests before a Homebrew release is usable.

## Maintainer release commands

Run these commands from the repository root **only after authorization for the
corresponding signature, Apple upload or publication**. They do not install the
app, helper or login item. The first release recipe targets Apple Silicon and
macOS 26 or later; it rejects other binary architectures. Intel qualification
and a matching universal/Intel recipe require separate evidence.

1. Set the same numeric `major.minor.patch` in `Packaging/Info.plist` and
   `LimitlessIdentity.version`; advance `CFBundleVersion` in the plist. The builder
   executes the unprivileged CLI's `--version` and rejects a mismatch. Commit all
   source changes, run full CI/security checks, and complete the hardware matrix.
2. Select full Xcode for the process with `DEVELOPER_DIR`, without changing the
   system-wide developer directory. Install your own **Developer ID Application**
   certificate/private key through Apple's tools. Check its fingerprint with
   `rtk proxy security find-identity -v -p codesigning`. No identity or credential
   is provided by this repository.
3. Set `LIMITLESS_TEAM_ID` to the real ten-character Apple Team ID and
   `LIMITLESS_SIGNING_IDENTITY` to that certificate's 40-character SHA-1 fingerprint.
   SHA-1 here selects a keychain identity; artifact integrity uses SHA-256.
   Then build into a new directory:

   ```sh
   rtk proxy env LIMITLESS_BUILD_PATH=/private/tmp/limitless-release-build LIMITLESS_OUTPUT_DIR=/private/tmp/limitless-signed swift Tools/ProjectTool.swift sign
   ```

   `sign` requires a clean committed tree, forces a Release build, embeds its
   source revision, and verifies the tree again before signing. It signs the CLI
   and helper before the app, with hardened runtime and secure timestamps. Each
   executable must satisfy the exact Developer ID Application certificate class,
   bundle ID and requested Team ID, and all three must contain the same leaf
   certificate. Entitlements are not needed by this design
   and are rejected. There is no `--deep` signing or silent ad-hoc fallback.
   [Apple signing guidance](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac),
   [certificate requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements).
4. Store notarization credentials in a named keychain profile using Apple's
   interactive `notarytool store-credentials`, outside Git. After upload approval,
   replace the following uppercase labels with your actual values:

   ```sh
   rtk proxy swift Tools/ProjectTool.swift notarize /private/tmp/limitless-signed/Limitless.app TEAM_ID KEYCHAIN_PROFILE
   ```

   This command **uploads the signed app to Apple**. It requires an `Accepted`
   result, staples the ticket, validates it and asks Gatekeeper to assess the
   app. It prints a diagnostic directory containing the submitted ZIP and JSON
   response, including when a nonzero tool result supplies JSON. A 30-minute
   wait timeout does not cancel Apple's processing: inspect the submission ID
   with `notarytool info`/`log` before deciding whether to submit again. No
   automatic resubmission, password argument or security bypass is used.
   [Apple notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).
5. Create the final archive **after stapling**, from the same clean source commit:

   ```sh
   rtk proxy swift Tools/ProjectTool.swift package /private/tmp/limitless-signed/Limitless.app TEAM_ID /private/tmp/limitless-release
   ```

   `package` refuses existing output, creates `Limitless-VERSION-arm64.zip`,
   extracts it into a fresh temporary directory and repeats signature, identity,
   architecture, metadata, ticket and Gatekeeper verification on the exported app.
   It then writes `SHA256SUMS`, `release.json` and `limitless.rb` using the actual
   archive's SHA-256. The manifest identifies the version, source commit, team,
   filename and digest. A standalone verification is also available:

   ```sh
   rtk proxy swift Tools/ProjectTool.swift verify /private/tmp/limitless-signed/Limitless.app TEAM_ID
   ```

The cask is generated from `Packaging/limitless.rb.in`. Its GitHub URL follows the
planned `vVERSION` tag and exact ZIP filename; generation **does not create that
release or make the URL available**. No tap has been created. After an authorized
release actually exists, the matching generated cask can be distributed through a
reviewed tap or installed as a local cask file with Homebrew. Never use the template
itself as an installable cask, substitute a dummy digest, or use `--no-quarantine`.

The source record is covered by the app signature; the digest binds the archive.
Neither proves an independently reproducible build or a GitHub artifact
attestation. Before publication, record the exact successful CI/security runs,
hardware acceptance, clean-Mac Gatekeeper result, signature team, tag/commit,
manifest and release artifacts together. Protected release approvals and any
hosted provenance attestation require repository/signing configuration; this
repository currently performs no automatic credential import, upload or release.

On upgrade/reinstall, the guarded uninstall hook also revokes sessions and removes
native registrations. Saved preferences remain, but helper approval, login and
automation must be enabled again through the app. No session resumes automatically.
`zap` removes only this user's documented preferences/cache/window state. It must
not delete the protected root journal or user-created AI skill copies.

## Prepare for removal

In Settings, **Prepare for removal** ends all sessions and disables automation.
The helper blocks new activation, policy changes and rearming for the rest of its
process lifetime, including across reconnects and console-user changes. Running
commands/processes are never terminated by this operation.

Only a confirmed allowed sleep flag, no owned hold, no remaining idle assertion
and no sessions permit the helper to remove its empty state directory. It checks
the held directory and lock against their original filesystem identities. Unknown
files, a still-owned/corrupt journal, changed permissions or replaced links block
cleanup. There is no recursive root deletion. The retired journal cannot accept
new writes. A partial failure can be retried without recreating a demand.

The app then uses asynchronous `SMAppService.unregister()` for the helper and
login item, checks their registration states and verifies that the fixed state
directory is absent. Only then can it report preparation complete. A failed or
unreadable check leaves an error. Finder cannot be prevented from deleting a file;
keep the app installed until preparation succeeds. [Apple unregister API](https://developer.apple.com/documentation/servicemanagement/smappservice/unregister(completionhandler:)).

The signed app provides the same operation for the generated Homebrew uninstall hook,
run as the console user, without `sudo`:

```sh
rtk proxy /Applications/Limitless.app/Contents/MacOS/LimitlessApp --prepare-uninstall
```

It exits 0 only on confirmed completion, otherwise 1 (64 for invalid arguments).
An ad-hoc development app refuses it. `--erase-preferences` explicitly removes the
current user's saved Limitless preferences after successful cleanup; the default
preserves them. User-created skill copies and external links are not silently deleted.

The cask must quit the app before invoking this hook with `must_succeed: true`,
then let Homebrew remove its app and CLI link. Optional `zap` handles this user's
preferences/cache/saved-window state. Do not use blanket deletion rules for the
protected journal or ignore a failed hook. Install, upgrade/reinstall and uninstall
remain signed-Mac tests, including approval loss and a helper restart between
cleanup and unregistration. [Homebrew cask rules](https://docs.brew.sh/Cask-Cookbook#stanza-uninstall).

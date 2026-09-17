# Build, installation and removal

Limitless is not yet published or qualified for privileged installation. Local
ad-hoc builds and certificate-signed test artifacts exist; neither is a qualified
production installer. Do not register an ad-hoc helper or bypass Gatekeeper.

## Distribution without Apple Developer membership

**User decision, 2026-09-16:** Apple Developer membership will come later. Limitless
must also be usable through GitHub or a dedicated Homebrew tap before then. Users
must never need their own developer membership. The Developer ID commands below
remain an optional future channel, not the only acceptable product distribution.

This route is implemented but not yet qualified for release. `SignedIdentity` pins
the exact peer identifier and the executable's own signing certificate, including
a self-signed certificate. The installed Apple SDK's public `SMAppService.h`
requires notarization for apps containing LaunchDaemons, so the community bundle
uses a separate native installation adapter. Ad-hoc development bundles remain
disabled; removing the Team ID requirement does not remove authentication.

Certificate-signed, non-root XPC probes now verify a real cross-process reply and
reject mismatched certificate pins and identifiers in both directions. A bundle
identifier or UID alone remains insufficient. The first authorized SMJobBless
installation and authenticated app/CLI exchanges with the root helper succeeded
on the test Mac. The first removal exposed a plist validation bug; see
[the integration record](testing.md#privileged-installation-trial).
Apple's
code-signing requirements support a self-signed certificate pin; that does not
prove a complete installation flow.
[Apple certificate requirements](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html).

The implementation retains `SMAppService` for the notarized channel and uses
the older public, deprecated `SMJobBless` API for the no-account channel. The Swift
installer validates both signatures and embedded reciprocal requirements before
requesting administrator consent through Authorization Services. The helper
has guarded cleanup for the two fixed files that SMJobBless installs, using the
running executable's signed identity; temporary-file tests cover replacement,
unsafe paths and interrupted removal. This does not qualify a real installation.
Cancellation, upgrade, restoration and full removal still require real-Mac evidence.
The removal validator accepts the optional `Program` key written by SMJobBless only
when it equals the fixed helper path, alongside the exact `ProgramArguments` array.
Keep the shared session/controller/backend and all user limits;
do not add a password field,
passwordless sudoers rule, unsigned-client acceptance or an arbitrary root executor.
[Apple SMJobBless contract](https://developer.apple.com/documentation/servicemanagement/smjobbless(_:_:_:_:)).

The native adapter rejects replacement of a loaded job. To upgrade or change
certificate/channel, first use the old matching app's guarded removal, then enable
the new installation. An interrupted, unloaded installation can be repaired only
when any remaining executable satisfies the same certificate requirement. macOS
still decides whether registration succeeds. No channel migration is automatic.

A stable publisher signing certificate/private key is still required, but it need
not be issued by Apple. Certificate creation, keychain changes and trust changes
are separate authorized maintainer actions; this repository performs none of them.
Users receive the already signed app and never need a signing key. Losing or
rotating the publisher key requires the old matching app to remove its helper.
The community channel does not use Apple's secure timestamp service and makes no
notarization claim; certificate validity and expiry need release qualification.

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
app/helper's required certificate identity. Power and login controls stay disabled.
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

## Community bundle and release commands

Build an ad-hoc community inspection bundle without installing anything:

```sh
rtk proxy env LIMITLESS_BUILD_PATH=/private/tmp/limitless-community-build LIMITLESS_OUTPUT_DIR=/private/tmp/limitless-community-preview swift Tools/ProjectTool.swift community-bundle
```

This variant puts the helper at
`Contents/Library/LaunchServices/io.github.leboonducoin.Limitless.helper`.
Its `__TEXT,__info_plist` and `__TEXT,__launchd_plist` sections contain the helper's
identity/version, authorized clients and launchd declaration. `SMJobBless` supplies
the installed `ProgramArguments`; the embedded plist deliberately has no program
path or arguments. The app's `SMPrivilegedExecutables` must agree with the helper.
Ad-hoc bundles use the requirement `false` for both peers, authorizing nobody.

The builder passes generated metadata to the helper linker only, verifies the
actual Mach-O sections and Security's signed Info.plist view, and resets the
metadata environment for ordinary builds/checks. No root tool runs. Both bundle
variants must fail the actual-certificate release verifier. CI includes both
development layouts; this does not qualify native installation.

After explicit signing authorization, use a clean committed checkout and an
existing stable code-signing identity in the maintainer's keychain. Set
`LIMITLESS_SIGNING_IDENTITY` to its actual 40-character SHA-1 fingerprint; no
`LIMITLESS_TEAM_ID` or paid membership is required. The placeholder `CERT_SHA1`
below must be replaced with that fingerprint, never a sample value:

```sh
rtk proxy env LIMITLESS_BUILD_PATH=/private/tmp/limitless-community-release-build LIMITLESS_OUTPUT_DIR=/private/tmp/limitless-community-signed swift Tools/ProjectTool.swift community-sign
rtk proxy swift Tools/ProjectTool.swift community-verify /private/tmp/limitless-community-signed/Limitless.app CERT_SHA1
rtk proxy swift Tools/ProjectTool.swift community-package /private/tmp/limitless-community-signed/Limitless.app CERT_SHA1 /private/tmp/limitless-community-release
```

`community-sign` forces Release, records the clean source commit, embeds exact
certificate requirements and signs all three executables with hardened runtime,
no entitlements and no timestamp service. It has no ad-hoc fallback. The verifier
requires the same actual certificate and exact identifiers throughout the app,
the community layout, matching embedded metadata, ARM64 and clean source metadata.
`community-package` extracts and verifies the actual exported archive again before
generating its SHA-256, manifest and draft cask. Its manifest records
`channel: community`, `notarized: false` and the certificate fingerprint. The
Developer ID commands below retain their separate timestamp/notarization gates.

None of these commands creates a certificate, installs a helper, changes trust,
publishes a download or bypasses Gatekeeper. On 2026-09-17, explicit user consent
authorized a dedicated local test identity and test signatures. The resulting
community bundle and re-extracted ZIP passed the verifiers with no trust-store
changes. This is a test certificate, not a qualified publisher identity or release.
Clean-Mac approval and the Homebrew lifecycle remain untested. See
[signed test evidence](testing.md#signed-community-and-xpc-tests).

An untrusted self-signed identity may be absent from `security find-identity -v`
while still supporting exact-certificate code-signing requirements. Do not add a
trust exception just to change that listing. The observed test identity was marked
`CSSMERR_TP_NOT_TRUSTED`; signing, strict verification and the XPC probe succeeded.
[Apple's distinction between signature validity and subsystem trust](https://developer.apple.com/library/archive/technotes/tn2206/).

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
hardware acceptance, clean-Mac Gatekeeper result, certificate/channel (and team
for Developer ID), tag/commit,
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

In the community channel, preparation acknowledges restoration while the executable
still exists. A separate application-only request removes the two fixed installed
files with the checks described in [architecture](architecture.md#removal). Its reply
may fail XPC signature validation after unlinking the executable. The app therefore
requires proven path absence and a fresh allowed sleep observation; it never disables
the certificate requirement or treats a transport error alone as successful cleanup.
The app then uses native `SMJobRemove` with administrator consent for that job, or
asynchronous `SMAppService.unregister()` for the bundled helper. Login removal
always uses `SMAppService`. The app checks registration states and absence of the
fixed journal and installed files before reporting completion. A failed or
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

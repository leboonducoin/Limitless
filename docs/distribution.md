# Installation and distribution

## One installation through GitHub Releases

The download contains one `Limitless.app`, with the menu-bar interface, helper,
CLI and AI skill. Unzip it, move it to Applications and open it. The icon appears
before administrator approval. Copying an app alone does not launch it.
Homebrew is no longer an installation route.

**No public release is available yet.** Local signed test builds are separate from
a qualified download. Initial target: Apple Silicon and macOS 26+.

## Distribution without Apple Developer membership

Users never need a developer account. The community channel uses a stable publisher
certificate, which may be self-signed. App, CLI and helper pin that same certificate
and their exact identifiers. Ad-hoc builds remain unable to use privileged controls.

The community helper installs through Apple's public, deprecated SMJobBless API
and native Authorization Services. No password is stored. SMAppService is retained
for the optional notarized channel. Identifier-only or UID-only authentication is
not an alternative.

A self-signed signature does not establish Gatekeeper acceptance. macOS may require
a user opening decision; managed systems can refuse it. Never strip quarantine,
change trust, disable Gatekeeper or automate security approval. Clean-Mac download,
first opening and removal remain release gates.
[Apple opening policy](https://support.apple.com/en-gb/102445).

Keep the publisher key stable and outside Git. Certificate creation/trust changes
are separate authorized actions. Losing or rotating the key requires removal through
the old matching app. Community builds make no notarization or secure-timestamp claim.
[Apple signature requirements](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html).

## Adding Apple Developer membership later

GitHub remains the download location. Developer ID signing, notarization and
stapling are already supported by the build tool; no App Store rewrite is needed.
Migrating certificate/channel requires removing the old helper through the matching
app before approving the new one. It is never a silent automatic update.

Existing properly timestamped Developer ID apps can continue to work after membership
or certificate expiry. Revocation is different; new certificates require active
membership. A free developer account does not provide Developer ID distribution
or notarization.
[Apple membership support](https://developer.apple.com/support/renewal/).

## Local app bundle

From the repository root:

```sh
env LIMITLESS_BUILD_PATH=/private/tmp/limitless-build LIMITLESS_OUTPUT_DIR=/private/tmp/limitless-preview swift Tools/ProjectTool.swift bundle
```

Output must be new. This creates an ad-hoc development app without registering a
helper or login item. It must fail both release verifiers.

For native inspection, add `LIMITLESS_PREVIEW_STATE=inactive`, `active`, `process`,
`setup`, `desktop`, `external` or `battery-unknown`. Fixtures are read-only Debug
content; Release/signing refuses them. Use separate output directories.
Preview data never proves physical power behavior.

## Community bundle and release commands

`community-bundle` checks the SMJobBless layout using intentionally unusable
development requirements. It does not install a service.

Signing requires an authorized existing certificate and a clean committed checkout.
Set `LIMITLESS_SIGNING_IDENTITY` to its real 40-character certificate fingerprint.
No Team ID is required. Replace `CERT_SHA1` below with the actual fingerprint:

```sh
env LIMITLESS_BUILD_PATH=/private/tmp/limitless-community-build LIMITLESS_OUTPUT_DIR=/private/tmp/limitless-community-signed swift Tools/ProjectTool.swift community-sign
swift Tools/ProjectTool.swift community-verify /private/tmp/limitless-community-signed/Limitless.app CERT_SHA1
swift Tools/ProjectTool.swift community-package /private/tmp/limitless-community-signed/Limitless.app CERT_SHA1 /private/tmp/limitless-community-release
```

The builder forces Release, records clean source, signs all three executables,
and checks exact identities, certificate bytes, metadata, architecture and absence
of entitlements. Packaging re-extracts and verifies the exported ZIP before writing
its SHA-256 and `release.json`. The manifest says community / not notarized.
No command creates a key, changes trust or publishes anything.

## Maintainer release commands

For the Developer ID channel, set the real `LIMITLESS_TEAM_ID` and
`LIMITLESS_SIGNING_IDENTITY`. Select full Xcode with process-local `DEVELOPER_DIR`.
Keep notarization credentials in Apple's named keychain profile, never in Git.

```sh
env LIMITLESS_BUILD_PATH=/private/tmp/limitless-release-build LIMITLESS_OUTPUT_DIR=/private/tmp/limitless-signed swift Tools/ProjectTool.swift sign
swift Tools/ProjectTool.swift notarize /private/tmp/limitless-signed/Limitless.app TEAM_ID KEYCHAIN_PROFILE
swift Tools/ProjectTool.swift verify /private/tmp/limitless-signed/Limitless.app TEAM_ID
swift Tools/ProjectTool.swift package /private/tmp/limitless-signed/Limitless.app TEAM_ID /private/tmp/limitless-release
```

`notarize` uploads to Apple and requires separate upload approval. It requires an
Accepted result, staples the ticket and checks Gatekeeper. A wait timeout does not
cancel Apple's processing: inspect the submission ID before retrying.
[Apple notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

Before either channel is published:
- Match the marketing version in the plist and `LimitlessIdentity`; increment build number.
- Observe the exact commit's complete CI/security results and finish the
  [hardware acceptance matrix](requirements.md).
- Verify the exported archive, checksum and source manifest, including clean-Mac opening/removal.
- Publish the verified ZIP, `SHA256SUMS` and `release.json` together under `vVERSION`,
  only after publication approval.

A source record and archive digest are not a reproducible-build or hosted-attestation
claim. Local packaging creates no tag or public download.

## Updates

The app checks the fixed GitHub repository at launch and every six hours. GitHub
rate limits use its retry time; other errors retry after fifteen minutes.
Updates require a newer marketing version, not merely a build number.

Automatic updates are opt-in and wait for no active sessions. Manual Update appears
only when a release is available. Archives have bounded extraction, SHA-256,
source/metadata and pinned app/CLI/helper signature checks. Quarantine is preserved.
The helper closes new admission while idle; replacement retains a backup and rolls
back on failure. A changed certificate/channel requires manual installation.

Preferences and login registration survive. Active sessions do not. The native app
may reapply the saved CLI opt-in only after the new helper is approved and healthy.
No public release currently means there is nothing to update to.

## Prepare for removal

Right-click the menu icon and choose **Uninstall Limitless…**, then confirm the red
button. Limitless ends sessions, confirms restored sleep, removes the helper and
its CLI shortcut, unregisters login, erases all preferences/cache/window state,
moves the app to Trash and quits.

If restoration or native cleanup fails, removal stops with a visible error.
Keep the matching app and its ownership journal until cleanup is confirmed.
Never force-remove root files to get around this gate. The helper never overwrites
a foreign command, and removal leaves foreign links alone.

Copied AI skills and agent hook entries remain in their user-managed configuration;
remove the Limitless entries as explained in [AI setup](cli.md#ai-agent-setup).
Old local installation evidence is in the [test history](testing-history.md).

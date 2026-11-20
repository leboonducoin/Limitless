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

Developer ID releases use Apple's app signature and a stapled notarization ticket.
GitHub remains the download location. Moving from the community certificate to Developer ID
requires manual installation: first uninstall the old app using its own menu, then install
the new archive and approve its helpers. Automatic updates never cross signing identities.
Do not remove the old app if its cleanup has not completed.

## Touch ID for sudo

Enable it in the menu to use your fingerprint for `sudo`. Your password still
works. This is a Mac-wide setting; it does not change Limitless's administrator
prompt. Remote sessions may still need a password.

The first change installs a separate **Limitless — Touch ID for sudo** component,
with its own administrator approval. Each change also requires administrator
authorization. If macOS blocks the change, click **Open Full
Disk Access**. In Settings, enable the entry ending in **Limitless.sudo.helper**,
then return to Limitless and retry the toggle.

Keep the main app and sleep helper disabled in that list. You can revoke the sudo
helper's access afterward; changing Touch ID or removing its rule needs it again.
This remains a broad macOS permission, held by the separate sudo helper.

## Updates and removal

Automatic updates turn on when you first enable the helper and can be disabled.
Limitless saves this choice in Keychain. After upgrading from an older release,
review the automatic-update setting in Options. Limitless checks every eight
hours and starts installing a detected update immediately while idle. Otherwise, an **Update**
button appears when a version is available and disappears during the retry delay. Right-click
the menu-bar icon → **Check for Updates** to perform a fresh check and install an available
update while idle. A manual check resets the eight-hour timer and can retry a delayed download
after five minutes; server retry deadlines still apply. The login Keychain stores the retry schedule
and your automatic-update choice. Checks read the published `release.json`
asset instead of GitHub's rate-limited REST API. Limitless requires its source revision to match
the signed app's `Build.json`, verifies the download, then installs and reopens the app.
If the helper was enabled, the reopened version restores it; a failed replacement reopens
the previous app so the same recovery can run. The installer records the backup location
before replacing the app and keeps the backup until the replacement starts and, when required,
confirms its helper. On an installation your account cannot
replace automatically, use **Download update** in Options. macOS may run a quarantined update from a
temporary, randomized location. Limitless verifies the matching signed copy in
Applications before granting CLI access again, replacing it on the next update or moving it
to the Trash. If macOS asks for administrator approval during removal, the power and
Touch ID helpers have separate approvals; a missing Touch ID helper may first need
to be restored to remove a Limitless-owned Touch ID rule.

If Limitless cannot confirm its Keychain recovery records, an in-app replacement
waits for Keychain access to return. Use **Download update** to install it manually
if recovery stays unavailable. The download is available even when the power
helper is disabled. Uninstall preserves unreadable update records and reports
them after removing the system components.

When upgrading from 1.1 or earlier, enable the power helper again if requested
in Options and review Power. Limitless leaves the older updater's backup in
place because it has no protected recovery receipt for that transaction.

To move Limitless farther right in the menu bar, hold Command and drag its icon. macOS remembers
that position for later launches.

Right-click the menu-bar icon → **Uninstall Limitless**. This stops sessions and
removes the app, helper, CLI shortcut, login item, preferences and AI integrations
installed by Limitless. Existing Touch ID settings and recovery backups are kept.
Uninstall and updates that remove an active helper require administrator
authorization before privileged cleanup.
The **Attested preview** workflow can build an inert Debug archive from `main`
on request. The workflow artifact includes `SHA256SUMS` and has a GitHub build
attestation. Use the full commit SHA from the preview's workflow run as `COMMIT`.

```sh
shasum -a 256 -c SHA256SUMS
gh attestation verify Limitless-Preview.zip --repo leboonducoin/Limitless \
  --signer-workflow leboonducoin/Limitless/.github/workflows/preview-build.yml \
  --source-ref refs/heads/main --source-digest "$COMMIT"
```

The preview has a separate identity and cannot enable protection. GitHub Releases
carries the user-installable signed app.

## Attest the distribution package

Run **Attest distribution archive** manually from the exact release commit on
`main`. The workflow verifies and packages a locally signed and stapled
Developer ID input. Its attestation describes the GitHub packaging run. The
signed app's build record supplies the source revision for the local compilation.
Signing compiles and verifies the app in a fresh private workspace before export.

1. Pass the release's CI and Security gates and record the
   [physical acceptance results](compatibility.md).
2. Create a draft release targeting the full source commit SHA. Prepare a
   `Limitless-Signed-App.zip` with the verified `Limitless.app` at its root.
   Upload that input to the draft and record its SHA-256 on the signing Mac.
3. Dispatch the workflow with the draft tag and input SHA-256. The workflow
   checks the signature against Limitless's Apple Developer Team and matches the
   signed build record to the workflow's source commit.
   Download the `Limitless-distribution` artifact and verify the ZIP before attaching it.

```sh
shasum -a 256 -c SHA256SUMS
gh attestation verify Limitless-VERSION-universal.zip --repo leboonducoin/Limitless \
  --signer-workflow leboonducoin/Limitless/.github/workflows/attest-release.yml \
  --source-ref refs/heads/main --source-digest "$COMMIT"
```

Attach the three verified files from the artifact to the draft. Remove the
signed input ZIP from the draft before publication. The workflow requires no
signing key. GitHub requires access to draft releases in the fetch job, which
only downloads and hashes the input. Packaging and attestation run in separate
jobs with their own permissions. Runs for the same tag cannot overlap.

## Host the interactive demo

Open [demo.html](demo.html) directly in a browser to preview the three scenarios.
GitHub Pages can serve it from the repository's `main` branch and `/docs`
directory. The demo runs without JavaScript or a local Limitless installation.

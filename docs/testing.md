# Testing

## Check a code change

On a Mac with Xcode 26.2 or later, run this from the repository:

```sh
swift Tools/ProjectTool.swift check
```

It checks formatting, builds the app and runs the tests. Success ends with
**All current local checks passed.** It installs nothing and does not change
sleep, login or sudo settings.

For memory and concurrency checks, also run:

```sh
swift Tools/ProjectTool.swift asan
swift Tools/ProjectTool.swift tsan
```

If the repository is in an iCloud-synced folder, keep build files outside it:

```sh
env LIMITLESS_BUILD_PATH=/private/tmp/limitless-build swift Tools/ProjectTool.swift check
```

Set `SDKROOT` to an installed SDK path if the selected SDK and Swift compiler do not match.

## Preview the interface

```sh
swift Tools/ProjectTool.swift preview
```

Open the **Limitless.app** path printed at the end, then click its status item.
The preview opens only in the menu bar, with a PNG beside the bundle.
Command-click and the timer controls simulate sessions in memory. The preview cannot
keep the Mac awake or install the helper.
Previews use a separate app identity so they do not replace Limitless in macOS settings.
For the setup screen instead:

```sh
env LIMITLESS_PREVIEW_STATE=setup swift Tools/ProjectTool.swift bundle
```

Other previews: `inactive`, `process`, `desktop`, `external`, `battery-unknown`, `battery-low`,
`touch-id-external` and `touch-id-permission`. Check light/dark mode, Tab navigation, VoiceOver and
Reduce Motion/Transparency. Check that the Options label, icon, blank space and chevron all
open Options. Scroll to the App category while the session controls stay visible. Close the
panel and reopen it to verify Options is collapsed. From a background launch, verify that the
first click on the item opens the panel and a single click on Options expands it. Verify the
minute-only display shows `00h` above the minutes with its orange mark. Check that content fits
when Automatic updates changes or an Update button appears. Keyboard input must follow the Mac's
layout and locale.

## Test the installed app

Use a real installation, not the preview. Record the app version, Mac model,
macOS version and any steps that fail.

- Enable the helper; verify launch at login turns on. Turn it off and reopen the
  app: it must stay off. Login must never start a session.
- With CLI access off, configure adapter-only mode and a custom battery reserve.
  Restart the helper and confirm those limits before starting another session.
- Restart the Mac and record how long the adaptive helper takes to reconnect after login.
  It must become responsive without manual intervention or weakened client validation.
- Start a short timer, then try Stop, a date and multiple PIDs.
- Click the circular + beside Stop repeatedly: each confirmed click adds 15 minutes to
  the same timer/date session. Stop must discard queued additions. Unlimited and process
  sessions cannot be extended; duration ceilings and battery protection still apply.
- With a short automatic screen-lock delay, leave an active session idle past that delay.
  Check that the display stays awake and unlocked, then Stop and verify normal idle
  locking returns. Repeat after expiry, battery cutoff and power-source suspension.
  Manual lock must still work. Record managed-policy restrictions separately.
- On a laptop, test lid open/closed, switching power and the battery limit.
- Check a closed laptop on an external display and disconnect the display. Check
  that the menu distinguishes both configurations and that expiry restores the
  owned sleep change in each. Record any actual system sleep separately.
- Switch Keep display awake during a bounded session and verify the corresponding
  assertions. Test optional muting with supported and unsupported outputs,
  disconnect/reconnect the original output before restoration, and check that a
  pre-muted output stays muted.
- Use simulated serious and critical thermal state in the test suite. For native
  qualification observe telemetry during ordinary workload on a ventilated Mac.
- With fresh settings, confirm notifications start enabled and macOS asks for permission on
  first launch. Deny or disable them, relaunch and check the choice persists. With permission,
  verify one reminder for the last five minutes, a postponed reminder after extension,
  and the correct end reason.
- On an approved iPhone/Mac pair, verify hotspot setup, password retention across
  a same-identity update, recovery after an outage, and cancellation before association.
- Type a battery limit, press Return or leave the field, then try the arrows.
  Letters are refused; 81 becomes 80. A blocked start or battery cutoff explains why.
- Run two AI tasks. The last one ending stops their hold; manual sessions stay yours.
- On a user-owned installation, enable CLI access and confirm setup uses its
  private executable. Rerun setup over existing hooks and verify the legacy
  Limitless command is replaced without changing foreign hooks. Reopen after
  helper restart and confirm the consent and limits are restored independently
  of user preferences.
- Try Touch ID, Cancel and password fallback for sudo.
  Its setup component uses the Limitless icon and **Limitless — Touch ID for sudo**
  name. Full Disk Access can list its helper as **io.github.leboonducoin.Limitless.sudo.helper**.
  Keep access off for the main app and power helper.
  A refused change must show a red warning and orange button below the sudo switch,
  without interrupting an awake session. The button must open only System Settings.
  Enable the sudo helper's entry and retry; no automatic retry. Revoke access and
  verify that a later change fails.
- Right-click **Check for Updates**. An available update installs immediately while idle;
  a manual check resets the eight-hour clock and can retry a delayed download after five
  minutes. The current release must report that it is up to date without contacting
  `api.github.com`. During that delay, verify that the inline **Update** button is absent. Confirm the
  published archive accepts the bundled `Limitless Sudo.app` path. Verify the helper returns after the reopened
  app; if opening the replacement is deliberately failed, verify the previous app
  reopens and restores it. Cancel sudo component cleanup during a prepared update
  and verify that the old app can start a fresh session with the saved limits.
  Confirm the previous app stays on disk until the replacement has started and
  authenticated its helper when required.
  After approving a quarantined update, verify that CLI opt-in is restored even if macOS
  starts the app from a randomized path; the next update must still target the signed app
  in Applications. Do not remove quarantine to make this pass.
- Use Command-click while idle and check the favorite duration. Confirm that
  Command-Return starts, Command-Plus extends, and Command-Period stops from the
  panel. Open and close Options from keyboard focus. Verify that the remaining time
  and end time update after extension, that icon-only mode uses a full orange mark,
  and that none of the styles changes the status item's width. Check that Command-click
  during an owned timer adds 15 minutes to it.
- Command-drag the Limitless icon farther right, relaunch the app and verify that macOS restores
  its position.
- Then uninstall: the app should close and its integrations disappear.
  With an owned audio mute awaiting a disconnected output, verify that uninstall
  still stops protection before asking to reconnect the output.
  Cancel the sudo component's administrator prompt, retry removal, and verify both
  helpers disappear. An existing external sudo setting must remain unchanged.
  Repeat after a quarantined update that launches through App Translocation: the
  signed app in Applications must move to the Trash, not the temporary running copy.
  If that installed copy is missing or has a different version, removal must stop
  before changing the helpers or preferences.

For long runs, keep the Mac ventilated and leave battery protection enabled.
If stopping or uninstalling fails, keep the app and report the error before retrying.

## Before merging

Both [CI](https://github.com/leboonducoin/Limitless/actions/workflows/ci.yml) and
[Security](https://github.com/leboonducoin/Limitless/actions/workflows/security.yml)
must pass for the final commit. They cover tests, sanitizers, CodeQL, workflow
linting and secret scanning. Security also runs every Monday and Friday at 07:29 UTC.
Pull requests also check dependencies.
Both GitHub-hosted macOS 15 jobs run the shipped CLI and verify the macOS 14.0
deployment target in both slices. The Intel job also runs the full checks.
GitHub retired its macOS 14 runner. Before release, execute the shipped CLI and
qualify the installed app on a macOS 14 Mac. **CI gate** and **Security gate**
fail if a required job fails, is cancelled or is unexpectedly skipped.

Signed XPC/update fixtures pin the exact leaf certificate and executable identifier.
This supports Developer ID chains as well as the community certificate; the fixture
signature does not claim notarization or qualify installation.
The signed update replacement fixture also requires a Mac with no installed Limitless
helpers or ownership journal. Its refusal on an installed Mac is a separate manual gate;
do not remove those services merely to make a fixture pass.

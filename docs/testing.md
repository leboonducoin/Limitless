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

## Preview the interface

```sh
swift Tools/ProjectTool.swift preview
```

Open the **Limitless.app** path printed at the end. This is an inert preview,
with a PNG beside it. It cannot keep the Mac awake or install the helper.
Previews use a separate app identity so they do not replace Limitless in macOS settings.
For the setup screen instead:

```sh
env LIMITLESS_PREVIEW_STATE=setup swift Tools/ProjectTool.swift bundle
```

Other previews: `inactive`, `process`, `desktop`, `external`, `battery-unknown`, `battery-low`,
`touch-id-external` and `touch-id-permission`. Check light/dark mode, Tab navigation, VoiceOver and
Reduce Motion/Transparency. Keyboard input must follow the Mac's layout and locale.

## Test the installed app

Use a real installation, not the preview. Record the app version, Mac model,
macOS version and any steps that fail.

- Enable the helper; verify launch at login turns on. Turn it off and reopen the
  app: it must stay off. Login must never start a session.
- Start a short timer, then try Stop, a date and multiple PIDs.
- On a laptop, test lid open/closed, switching power and the battery limit.
- Type a battery limit, press Return or leave the field, then try the arrows.
  Letters are refused; 81 becomes 80. A blocked start or battery cutoff explains why.
- Run two AI tasks. The last one ending stops their hold; manual sessions stay yours.
- Try Touch ID, Cancel and password fallback for sudo.
  Its separate component must show the Limitless icon and **Limitless — Touch ID
  for sudo** name. Keep Full Disk Access off for the main app and power helper.
  A refused change must show a red warning and orange button below the sudo switch,
  without interrupting an awake session. Grant access only to **Limitless Sudo.app**
  and retry; no automatic retry. Revoke access and verify that a later change fails.
- Check updates while idle, then uninstall. The app should close and its integrations disappear.
  Cancel the sudo component's administrator prompt, retry removal, and verify both
  helpers disappear. An existing external sudo setting must remain unchanged.

For long runs, keep the Mac ventilated and leave battery protection enabled.
If stopping or uninstalling fails, keep the app and report the error before retrying.

## Before merging

Both [CI](https://github.com/leboonducoin/Limitless/actions/workflows/ci.yml) and
[Security](https://github.com/leboonducoin/Limitless/actions/workflows/security.yml)
must pass for the final commit. They cover tests, sanitizers, CodeQL, workflow
linting and secret scanning. Pull requests also check dependencies.
The CLI runs on macOS 14; Intel also runs the full checks. **CI gate** and
**Security gate** fail if a required job fails, is cancelled or is unexpectedly skipped.
Automated results do not replace the installed-app checks above.

# Testing

## Local commands

```sh
swift Tools/ProjectTool.swift check
swift Tools/ProjectTool.swift asan
swift Tools/ProjectTool.swift tsan
```

`check` validates formatting, release inputs and graphical entry points, typechecks
optional integration probes, builds Release and runs the tests. It does not install
a helper or change power settings. Sanitizers run separately and are blocking in CI.

On a synced Desktop, keep generated bundles outside the sync provider:

```sh
env LIMITLESS_BUILD_PATH=/private/tmp/limitless-swift-build swift Tools/ProjectTool.swift check
```

Use separate paths for simultaneous sanitizer runs. The tool loads the installed
Swift Testing macro when needed by Command Line Tools. Full Xcode is used in CI;
CLT's absent Xcode search-path warnings are recorded environment limitations.

Opt-in read-only hardware observation:

```sh
env LIMITLESS_READ_ONLY_INTEGRATION=1 LIMITLESS_BUILD_PATH=/private/tmp/limitless-swift-build swift Tools/ProjectTool.swift check
```

## CI and security

GitHub Actions runs on pushes to main and pull requests. Baseline and CodeQL use
Xcode 26.2; ASan/TSan use Xcode 26.6 on macos-26. Gates include Swift/Actions CodeQL,
actionlint, zizmor, Gitleaks and dependency review on PRs. Actions are pinned;
no signing secrets are exposed to PR builds. Scan intended staged changes and
history before publishing. Do not report skipped or unavailable checks as passed.

The SHA-1 certificate-selector finding is a documented
[Apple compatibility exception](../SECURITY.md#reviewed-compatibility-exception);
the query remains enabled.

## Current evidence

Build 10 local checks pass: 119 tests reported (51 core, 50 system, 5 CLI, 13 app),
including the disabled hardware opt-in. Coverage includes manual priority over
agent sessions, independent tasks, Stop without losing CLI consent, consent
restoration without weaker limits, source/battery visibility, fixed CLI-link
ownership, lifecycle parsing and marker replacement/refusal.

Native active and desktop previews were inspected. Adapter selection hides the
battery control; the desktop fixture hides both controls without a blank section.
Tab reaches source selection and the help link. Real menu-bar dot placement,
popover timing, the enabled red confirmation and full VoiceOver remain manual.
The existing AppIntents/BaseBoard and accessibility-time negative-geometry
diagnostics recur; no crash occurred. They are not a clean runtime-log claim.

Source review retained native popover motion, immediate keyboard/Reduce Motion
opening and nonanimated polling/countdown. Ponytail review removed separate
subagent holds: a parent turn covers work it awaits, while detached work needs its
own lifecycle. Security review checked XPC roles, fixed-link cleanup, marker
identity/permissions/ACLs, host identity, limits and absence of reacquisition.
Actual agent versions, CLI-link installation and signed privileged cleanup still
need the separate manual integration trials. Read hosted results for the exact
commit in [CI](https://github.com/leboonducoin/Limitless/actions/workflows/ci.yml) and
[Security](https://github.com/leboonducoin/Limitless/actions/workflows/security.yml).

The preceding build 9 passed local checks and hosted
[CI](https://github.com/leboonducoin/Limitless/actions/runs/35513006899) and
[Security](https://github.com/leboonducoin/Limitless/actions/runs/35513006880):
110 tests, including one disabled hardware opt-in. Those results do not qualify
the current changes. [Earlier test records](testing-history.md) retain exact
commands, results, artifacts and limitations.

## Signed community and XPC tests

Only with explicit signature authorization and an existing certificate:

```sh
swift Tests/SignedXPC/Run.swift CERT_SHA1 NEW_OUTPUT_DIRECTORY
swift Tests/SignedUpdate/Run.swift CERT_SHA1 NEW_OUTPUT_DIRECTORY
```

The XPC fixture covers valid and rejected peers in both directions and listener
admission. The update fixture uses temporary signed apps. Neither installs a
privileged service or changes sleep. Ordinary checks only typecheck these runners.
See [historical signed evidence](testing-history.md#signed-community-and-xpc-tests).

## Native interface inspection

Build an inert Debug fixture using [the preview recipe](distribution.md#local-app-bundle).
Inspect active, inactive, setup, process, desktop, external and unreadable-battery
states. Check mouse/keyboard opening, outside-click dismissal, destructive alert
color, focus order, text sizing and reduced motion. Review runtime logs.
A fixture never proves physical sleep prevention.

### Settings keyboard qualification

Use the active keyboard layout and locale. Logical key names may still map to US
key positions; resolve actual characters before entering values. Read applied
limits back through authenticated helper status. Keep inspection probes read-only;
separate any explicitly authorized mutation. The
[recorded keyboard trial](testing-history.md#settings-keyboard-qualification)
explains the previously observed layout problems.

## Manual helper restart observer

Read the [operator protocol](testing-history.md#manual-helper-restart-observer)
before use. It needs a separately authorized, bounded active session and a
coordinated helper interruption. Only the operator sends the signal.

```sh
swift Tests/NativeMac/ObserveHelperRestart.swift --observe-armed-restart
```

The observer waits for a new helper PID, restored sleep and authenticated status
with no sessions and the interrupted fault. It is typechecked, never executed by CI.

## Required validation layers

Automated tests cover policy, timing, parsing, file boundaries and simulated
backend faults. Separately verify signed installation/XPC, actual power behavior,
and the exported archive's signatures, SHA-256 and source manifest.

Real-Mac gates remain in the [acceptance matrix](requirements.md): lid closed,
power transitions, battery cutoff, helper crash/reboot, clean download/opening,
upgrade/removal and full accessibility. For AI integrations, exercise completion,
cancel/error, host exit, concurrency and manual-session priority in each actual
agent version. Synthetic hook fixtures do not prove provider event delivery.

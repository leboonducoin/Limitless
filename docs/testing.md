# Testing

```sh
swift Tools/ProjectTool.swift check
swift Tools/ProjectTool.swift asan
swift Tools/ProjectTool.swift tsan
```

`check` validates formatting, release inputs, integration-probe compilation,
Release build and tests. It never installs a helper or changes power or sudo settings.
Touch ID tests use temporary PAM fixtures, including existing settings, unsafe
files, unsupported policies and removal. Real fingerprint/password trials are manual.
For a synced Desktop, prefix the command with
`env LIMITLESS_BUILD_PATH=/private/tmp/limitless-build`. Use separate paths for
simultaneous builds. Full Xcode is used in CI; Command Line Tools may emit missing
Xcode search-path warnings.

## CI

Pushes to main and pull requests run tests, ASan, TSan, Swift/Actions CodeQL,
actionlint, zizmor and Gitleaks. PRs also run dependency review. Actions are pinned;
signing secrets stay outside PR jobs. Baseline/CodeQL use Xcode 26.2, sanitizers
26.6 on macos-26. The [certificate-selector exception](architecture.md#apple-certificate-selector)
does not disable its CodeQL query.

See the exact commit’s [CI](https://github.com/leboonducoin/Limitless/actions/workflows/ci.yml)
and [Security](https://github.com/leboonducoin/Limitless/actions/workflows/security.yml) results.
Simulated tests and actual Mac trials are separate evidence.

## Native previews

```sh
swift Tools/ProjectTool.swift preview
```

Creates an inert app and a full-resolution PNG in a new temporary directory.
`bundle` with `LIMITLESS_PREVIEW_STATE` supports active, inactive, process, setup,
desktop, external and battery-unknown fixtures. See [distribution](distribution.md).
Inspect native controls, keyboard focus, VoiceOver, contrast, motion and logs.
A screenshot does not validate power behavior.

### Settings keyboard qualification

Use the current keyboard layout and number locale, not US keycodes. Read applied
limits back through authenticated helper status. Keep observation separate from
operator-authorized UI mutations.

## Signed probes

With an existing, authorized certificate and a new output directory:

```sh
swift Tests/SignedXPC/Run.swift CERT_SHA1 NEW_OUTPUT_DIRECTORY
swift Tests/SignedUpdate/Run.swift CERT_SHA1 NEW_OUTPUT_DIRECTORY
```

These use temporary signed fixtures, without privileged installation or power
changes. Ordinary checks only compile them. Read-only hardware observation is
opt-in through `LIMITLESS_READ_ONLY_INTEGRATION=1`.

## Manual helper restart observer

Use a verified test installation and keep its matching app open.

1. Start an operator-authorized session of at least five minutes. Confirm active,
   disabled, owned status.
2. Run `swift Tests/NativeMac/ObserveHelperRestart.swift --observe-armed-restart`.
3. After `READY`, the operator interrupts the named helper within 60 seconds,
   using `sudo /bin/launchctl kill SIGKILL system/io.github.leboonducoin.Limitless.helper`.
4. Do not rearm. Wait for the new helper PID, ten seconds of allowed sleep, zero
   sessions and the authenticated `interrupted` fault. Then use normal cleanup.

The observer never sends signals or starts a session. Unknown readings/timeouts
fail. If restoration is unconfirmed, preserve the app and journal and retry
through the app. CI never runs this trial. Other Mac checks are in the
[acceptance checklist](requirements.md).

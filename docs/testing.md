# Testing and evidence

## Current evidence

2026-09-16 environment inspection: macOS 26.6.2, Apple M1 Pro, CLT Swift 6.4,
SDK 27.0. Full Xcode and a valid signing identity were not detected. No system
power settings, login items or privileged services have been changed by this work.

The two modules pass 54 default Swift Testing tests (36 core, 18 system; including
parameterized boundary cases), strict swift-format lint and a Release build.
One additional opt-in, read-only Mac integration test also passes on the inspected
MacBook. Separate Address Sanitizer and Thread Sanitizer runs pass all 55 tests
with that opt-in enabled.
This covers policy, clock semantics, ownership, simultaneous demands, source
suspension, battery cutoff, revocation and simulated restoration/recovery failures.
System tests cover strict Boolean decoding, the real continuous clock and bounded
unprivileged `true`/`false`/`sleep` subprocesses. Journal tests use real temporary
files to check reopening, exclusive ownership, atomic cleanup, malformed data,
permissions, ACLs, symlinks, hard links and FIFOs. Coverage profiles are generated.
Power-source tests cover scaling, AC discharge, missing or malformed fields and
loss of a previously detected battery.
Tests never call privileged power writes or create real sleep assertions. XPC,
the root-path journal integration, UI and physical sleep behavior remain untested.

Read-only inspection outside the tool sandbox found an absent `SleepDisabled`
line in `pmset -g`, while IORegistry reported a Boolean false. The sandboxed pmset
read had returned only a header. Neither empty output is treated as false by the
implementation. No source from Apple or Sleepless was copied into this repository.

## Local commands

With full Xcode selected for the process, from the repository root:

```sh
rtk proxy swift Tools/ProjectTool.swift check
rtk proxy swift Tools/ProjectTool.swift asan
rtk proxy swift Tools/ProjectTool.swift tsan
```

`check` runs whitespace checks, strict formatting, Release compilation and tests
with coverage enabled. `asan` and `tsan` run separate instrumented test builds.
The tool loads Apple's existing Swift Testing macro explicitly when the selected
Command Line Tools contain it in the nested `plugins/testing` directory. It does
not install a framework or modify the toolchain. Ordinary Xcode needs no override.

On the inspected Mac, the Desktop file provider adds Finder metadata to generated
test bundles, which codesign rejects. Keep build output outside that synced folder:

```sh
rtk proxy env LIMITLESS_BUILD_PATH=/private/tmp/limitless-swift-build swift Tools/ProjectTool.swift check
```

Use distinct scratch paths for simultaneous sanitizer builds. Do not disable code
signing or strip security attributes to work around an installation failure.
CLT also emits linker warnings for absent Xcode-style search directories; these
are recorded environment warnings, not evidence that full Xcode was tested.

Opt in to the real, read-only IOKit/IOPowerSources smoke check on a supported Mac:

```sh
rtk proxy env LIMITLESS_READ_ONLY_INTEGRATION=1 LIMITLESS_BUILD_PATH=/private/tmp/limitless-swift-build swift Tools/ProjectTool.swift check
```

This checks readable power data and the global flag without creating an assertion
or changing a setting. Ordinary CI skips this hardware-dependent assertion. It
does not qualify closed-lid operation, transitions, helper approval or restoration.

## CI and security

The checked-in workflows run on pull requests, pushes to `main`, and manual
dispatch. Security also runs weekly. Actions are pinned to verified full commit
IDs; checkout credentials are not persisted. Jobs have individual minimum
permissions and timeouts. No job installs the helper or changes power settings.

| Check | Local evidence, 2026-09-16 | GitHub execution |
| --- | --- | --- |
| Release build, strict format, Swift tests | Passed | Configured; not run |
| Address / Thread Sanitizer, separate builds | Both passed; runtime libraries verified in binaries | Configured; not run |
| actionlint 1.7.12 | Passed | Configured; not run |
| zizmor 1.30.1, pedantic | Offline audit passed | Online audit configured; not run |
| Gitleaks 8.30.1 | Full local history and staged core passed | Full fetched history configured; not run |
| CodeQL Swift and GitHub Actions, extended security | Not available locally with this CLT toolchain | Configured; not run |
| Dependency review and Dependabot | Configuration inspected | Requires GitHub execution/settings |

Primary CI uses Xcode 26.2 on `macos-26`, within CodeQL's documented Swift
compiler support. Go is a development-only runner dependency for pinned
actionlint and the MIT Gitleaks scanner, not a Limitless product dependency.
The separately licensed Gitleaks GitHub Action is not used. zizmor's action and
scanner version are pinned. Security-tool versions embedded in `run` commands
need manual review when updating; Dependabot manages action references.

No push has occurred, so no remote CI result is claimed. UI tests, authenticated
XPC checks, release signing/notarization and artifact provenance checks remain
release gates to add and execute as those components become available.

## Required validation layers

1. Swift Testing for deterministic core policy, transport validation and time.
2. Simulated backend integration for state reconciliation and recovery failures.
3. Real unprivileged command/process lifecycle tests, including interruption.
4. Signed native XPC/ServiceManagement tests on an explicitly authorized Mac.
5. Native UI, accessibility and runtime-log inspection with full Xcode/tooling.
6. The physical release matrix in [requirements.md](requirements.md).
7. Full CI/security and signed/notarized artifact verification before release.

Record commands and real outcomes. A blocked/not-run check is never a pass.
Do not install a helper or change power settings in ordinary unit tests or on an
untrusted PR runner. Do not disable system protections to make tests pass.

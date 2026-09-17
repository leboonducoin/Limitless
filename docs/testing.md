# Testing and evidence

## Current evidence

2026-09-16 environment inspection: macOS 26.6.2, Apple M1 Pro, CLT Swift 6.4,
SDK 27.0. Full Xcode and a valid signing identity were not detected. No system
power settings, login items or privileged services have been changed by this work.

The two libraries, app, helper and CLI executables pass strict swift-format and a Release
build. There are 88 default Swift Testing tests (45 core, 37 system, 3 CLI, 3 app, including
parameterized boundary cases).
One additional opt-in, read-only Mac integration test also passes on the inspected
MacBook. Separate Address Sanitizer and Thread Sanitizer runs pass all 89 tests
with that opt-in enabled at the 2026-09-17 native installation checkpoint.
This covers policy, clock semantics, ownership, simultaneous demands, source
suspension, battery cutoff, revocation and simulated restoration/recovery failures.
System tests cover strict Boolean decoding, the real continuous clock and bounded
unprivileged `true`/`false`/`sleep` subprocesses. Journal tests use real temporary
files to check reopening, exclusive ownership, atomic cleanup, malformed data,
permissions, ACLs, symlinks, hard links and FIFOs. Coverage profiles are generated.
Removal tests cover active/corrupt ownership, unexpected files, replaced locks and
directories, dangling links, successful empty cleanup and rejection of retired
journal writes. A real permission failure after lock removal verifies that the
journal remains sealed and a later cleanup retry succeeds (unprivileged test only).
Installed-helper filesystem tests use private temporary roots and an explicit
test verifier, never a root installation. They cover idempotent removal, unrelated
files, changed binary contents, symbolic/hard links, FIFOs, writable/special modes,
replaced parents, wrong daemon identity and a partial unlink failure with retry.
A replacement at an already removed path blocks further cleanup. Reconstructed
cleanup accepts only confirmed absent entries, while a dangling link remains an
error; these interrupted-removal states are also tested on temporary files.
Production uses Security's strict signature verification instead of the fixture verifier;
positive signed deletion and ServiceManagement removal still require integration.
Both Release development layouts passed icon/plist/signature checks and expected
Developer ID/community release rejection on 2026-09-17. Community checks inspect
the actual embedded Mach-O plists and Security's signed Info.plist view. The modern
bundle was built after the community bundle using the same scratch directory,
checking that switching layouts does not retain stale helper metadata. Neither
bundle installs a service or has a publisher certificate.
Ponytail review removed an
unused cleanup-status flag and reused the journal's filesystem checks; no new
dependency or general-purpose filesystem abstraction was introduced.
Core tests verify that removal revokes all work, survives console
changes, denies task-endpoint removal, and requires a confirmed restored state.
Power-source tests cover scaling, AC discharge, missing or malformed fields and
loss of a previously detected battery.
Service tests cover role separation, connection capacity, console-user changes,
expired leases, unextendable deadlines, transport bounds and malformed policy.
Signature tests parse the exact certificate requirements with Security and set
them on inactive Foundation XPC connections. They reject malformed/injected
certificate fingerprints and identifiers, and confirm the ad-hoc test host cannot
impersonate the production helper. This is not a successful cross-process exchange.
Both native installation adapters also reject registration/removal from an ad-hoc
test host before native consent or mutation. Tool self-checks reject malformed
certificate selectors, versions, truncated Mach-O metadata, unsafe signing flags
and entitlements; only the community channel accepts a missing secure timestamp.
No native authorization dialogue, signed SMJobBless exchange or removal was tested.
CLI tests cover conflicting modes/stop conditions, malformed options, unbounded
representable durations, timezone-bearing dates and unchanged argument arrays.
Real unprivileged process tests verify exit codes, termination, duplicate launch
rejection, PID/start-time identity and owner changes. The built CLI's `--help`
works; `run -- /usr/bin/printf should-not-run` returned 69 without launching that
command because the development signature does not satisfy the production identity.
The installed skill-creator validator accepted `skills/limitless/SKILL.md`.
App tests reject misleading active/inactive presentation, invalid saved limits and
preview attempts to control the helper, automation, login items or removal.
Tests never call privileged power writes or create real sleep assertions. Live
signed XPC, the complete CLI/service lifecycle, root-path journal integration and
physical sleep remain untested. Native presentation inspection is recorded below;
it does not qualify privileged controls or physical power behavior.

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

`check` runs whitespace checks, strict formatting, release-tool input checks,
Homebrew DSL syntax, Release compilation and tests with coverage enabled.
`asan` and `tsan` run separate instrumented test builds.
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

| Check | Local evidence through 2026-09-17 | GitHub execution |
| --- | --- | --- |
| Release build, strict format, Swift tests | Passed | Configured; not run |
| Development app bundle, icon export, plist and strict ad-hoc signature verification | Both Release layouts passed; modern Debug previously passed | Both Release layouts configured; not run |
| Release input validation, Homebrew template syntax, ad-hoc release rejection | Passed | Included in check and bundle; not run |
| Address / Thread Sanitizer, separate builds | Both passed; runtime libraries verified in binaries | Configured; not run |
| actionlint 1.7.12 | Passed again after community CI edit | Configured; not run |
| zizmor 1.30.1, pedantic | Offline audit passed again after community CI edit | Online audit configured; not run |
| Gitleaks 8.30.1 | Full local history and staged changes passed | Full fetched history configured; not run |
| CodeQL Swift and GitHub Actions, extended security | Not available locally with this CLT toolchain | Configured; not run |
| Dependency review and Dependabot | Configuration inspected | Requires GitHub execution/settings |

Primary CI uses Xcode 26.2 on `macos-26`, within CodeQL's documented Swift
compiler support. Go is a development-only runner dependency for pinned
actionlint and the MIT Gitleaks scanner, not a Limitless product dependency.
The separately licensed Gitleaks GitHub Action is not used. zizmor's action and
scanner version are pinned. Security-tool versions embedded in `run` commands
need manual review when updating; Dependabot manages action references.

The local Release app includes only its Swift executables, plist/icon resources,
MIT license and AI skill. Its packaged CLI prints help successfully and rejects
`run -- /usr/bin/printf should-not-run` with exit 69 before launching that command:
an ad-hoc artifact cannot impersonate the signed production identity. No helper
was installed or executed for this packaging check.
The app's `--prepare-uninstall` hook also returned 1 with the expected signed-build
requirement before any removal action. Actual service unregistration remains untested.

Release-tool self-checks reject malformed/injected Team IDs, nonnumeric versions,
invalid digests and ad-hoc artifacts. Synthetic signing-information checks reject
missing/invalid runtime flags or timestamps and any entitlement data. They parse the Developer ID requirement and
the Homebrew template with the system Ruby parser. Ruby is only a development
DSL check/Homebrew dependency, not an application or CLI runtime. Each development
bundle repeats the negative signature check after its ordinary signature passes.
The builder also checks that the actual CLI version matches the bundle plist.
The positive publisher-certificate, Developer ID/timestamp, Apple submission, stapling,
Gatekeeper and exported-release checks are implemented but not executed: this Mac
has zero valid signing identities (rechecked 2026-09-17) and Command Line Tools,
not full Xcode. Full Xcode is not required by the community signing command.
No notarization upload, generated production cask or signed artifact is claimed.
The separate `brew style --help` probe was unable to create Homebrew's cache in
the restricted environment; it did not install a dependency. Full Homebrew
style/audit and install/upgrade/uninstall qualification are not claimed.

No push has occurred, so no remote CI result is claimed. Native interaction tests,
authenticated XPC, release-tool positive paths, independent provenance attestation
and the signed Homebrew lifecycle remain separate release gates.

## Native interface inspection

Read-only Debug previews were inspected through native accessibility automation on
the Mac above. Dark active state and light inactive state rendered without panel
overflow; a process-help truncation was found and corrected. The light inspection
used an app-local `NSAppearance.accessibilityHighContrastAqua` override, without
changing the Mac's appearance or accessibility preferences. This is not proof that
every system accessibility preference has been exercised.

The stop menu exposes unlimited time, all 13 presets, custom duration with units,
native date/time entry and process identity input. Settings expose independent
power limits, automation consent and login controls. Native scrolling reaches the
startup explanation. The battery control exposes its label/value to accessibility;
0% displays the warning, and one increment gives 1%. Tab focus and the Up arrow
were exercised on the stepper (20% to 21%). Preview controls cannot apply policy,
enable automation, register the helper or change login items.
The removal section and native confirmation were inspected in the read-only
preview. The destructive confirmation is disabled there; opening and dismissing
the dialogue changes only presentation state. No real removal was performed.
The final dialog's explicit Cancel action was also exercised with Escape.

Command-comma and Command-W did not produce an observable action through this
automation session; keep shortcut verification open. VoiceOver speech, full
keyboard-only use, actual menu-bar popover placement, Reduce Motion and Reduce
Transparency preferences remain manual qualification gates.

Runtime-log review found Apple AppIntents `com.apple.linkd.autoShortcut` connection
errors (4097), BaseBoard task-port messages and cache-file lookup messages during
the development previews. No Limitless-originated error was identified in that
sample. A GUI launch inside the command sandbox aborted; the authorized native
preview outside that sandbox ran and exited normally. Recheck logs with the signed
installed app; these observations are not a claim of an error-free production run.

Motion review using the installed `review-animations` skill:

| Before | After | Why |
| --- | --- | --- |
| No custom transitions, springs or looping animation | Retain native control/popover feedback and disable asynchronous layout animation | Frequent status refreshes must not move controls or delay keyboard feedback |

**Approve the source-level motion scope.** Native reduced-motion behavior still
requires the manual gate above. Ponytail complexity review: lean already; no extra
UI framework, duplicated policy engine or animation layer to remove.

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

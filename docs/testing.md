# Testing and evidence

## Current evidence

2026-09-16 environment inspection: macOS 26.6.2, Apple M1 Pro, CLT Swift 6.4,
SDK 27.0. Full Xcode and a valid signing identity were not detected. No system
power settings, login items or privileged services have been changed by this work.
On 2026-09-17, the user authorized creation of a dedicated local test identity and
signing of test bundles. Those checks are recorded separately below; no Apple
membership, trust-store exception or privileged installation was used.

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
Tests never call privileged power writes or create real sleep assertions. The
complete signed CLI/helper lifecycle, root-path journal integration and physical
sleep remain untested. Non-root signed XPC evidence and native presentation inspection are recorded below;
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
Homebrew DSL syntax, typechecking of the opt-in signed XPC probe/runner, Release
compilation and tests with coverage enabled. It never signs or executes that probe.
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
The community certificate and exported-archive checks have passed with a dedicated
local test identity, as recorded below. Developer ID/timestamp, Apple submission,
stapling, Gatekeeper and publisher release qualification remain unexecuted.
This Mac has Command Line Tools, not full Xcode; full Xcode is not required by
the community signing command. No notarization upload or published cask is claimed.
The separate `brew style --help` probe was unable to create Homebrew's cache in
the restricted environment; it did not install a dependency. Full Homebrew
style/audit and install/upgrade/uninstall qualification are not claimed.

No push has occurred, so no remote CI result is claimed. Native interaction tests,
privileged XPC, Developer ID release paths, independent provenance attestation
and the signed Homebrew lifecycle remain separate release gates.

On 2026-09-17, the expanded README and contribution guide were checked against the
actual CLI help, native control labels, core defaults and distribution commands.
All 27 local Markdown link targets exist; anchors were reviewed separately.
The complete local check passed again with the read-only opt-in (89 tests).
Issue forms and their chooser were reviewed against GitHub's documented
[form schema](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-githubs-form-schema)
and [template configuration](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/configuring-issue-templates-for-your-repository).
Their GitHub rendering has not been tested; no issue or pull request was submitted.

## Signed community and XPC tests

On 2026-09-17, the user authorized a local test certificate and test signatures.
The dedicated key is RSA 3072, imported into the user's keychain with a codesign
access list and configured as sensitive/non-extractable. Security attributes
confirmed signing is allowed and extraction is disabled. The SHA-256-signed
certificate has code-signing usage and a one-year lifetime. Private key bytes
were passed in memory and pipes, never printed, written to the repository or saved
as a key file. No global certificate trust was added. This is not a backed-up,
qualified publisher identity.

A clean detached checkout of `bad7a1aa94b67397d165f3d43626c6f6d42cdc5b`
produced a community Release bundle. `community-sign`, `community-verify` and
`community-package` completed successfully, including exact certificate equality
on app/CLI/helper, strict integrity, embedded metadata, hardened runtime, no
entitlements and re-verification after extracting the actual ZIP. The local
manifest, checksum and draft cask exist; no download URL has been published.
The signed CLI's `status` returned 69 (`unavailable`) with no crash while the
privileged helper was absent. No application integration control was activated.

The separate reproducible test uses the production `SignedConnection.swift`
directly and a fixed-message, non-root XPC service embedded in a test bundle.
It contains no power backend, helper runtime, service installer or login action.
Run it only after explicit signing authorization with an existing test identity:

```sh
rtk proxy swift Tests/SignedXPC/Run.swift CERT_SHA1 /private/tmp/limitless-signed-xpc-new
```

Replace `CERT_SHA1` with the actual certificate fingerprint and choose a new output
directory; existing output is refused. No key is generated by this command.
The runner compiles the probe, signs each pair and verifies it before execution.
Each XPC service exits within eight seconds. A timeout is a test failure.
Ordinary `check` typechecks both Swift files without signing/execution; the CodeQL
workflow compiles them for analysis without signing/execution (hosted run pending).

| Case | Observed result |
| --- | --- |
| Both directions match | Reply from a different PID with the same non-root UID |
| Server expects a different client certificate pin | No reply; connection interrupted, Cocoa error 4097 |
| Client expects a different server certificate pin | No reply; code-signing requirement failure, Cocoa error 4102 |
| Server expects a different client identifier | No reply; connection interrupted, Cocoa error 4097 |
| Client expects a different server identifier | No reply; code-signing requirement failure, Cocoa error 4102 |

All five cross-process cases passed on the inspected Mac. Mismatched pins deliberately change
one hexadecimal digit of the expected fingerprint; no second signing key was
created. Native XPC logs also recorded code-signing requirement refusals with
Security status -67050. This proves these checks on the local non-root transport,
not the production helper's privileged endpoint, console-user rules, administrator
approval, installation/removal or closed-lid behavior.

The same runner also checks three anonymous-listener admission cases within one
signed process. A matching peer reaches the delegate once; a wrong pin or wrong
identifier never reaches it. The initial experiment with only per-connection
requirements failed this assertion: a wrong pin reached the delegate once before
its message was rejected. Adding `setConnectionCodeSigningRequirement` before
listener activation made all three admission cases pass. The helper now sets this
native filter on both of its Mach listeners before any connection can trigger
reconciliation or owner allocation. Per-message checks are retained. The installed
SDK documents rejection before consulting the delegate; this API supports Mach and
anonymous listeners, not the singleton bundled-service listener used by the other
five cases. See [Apple's listener requirement API](https://developer.apple.com/documentation/foundation/nsxpclistener/setconnectioncodesigningrequirement(_:)).
These eight native cases remain separate from the 89 Swift Testing tests and do
not install the production helper. After the listener change, the complete local
check, Address Sanitizer and Thread Sanitizer each passed all 89 tests again.

## Signed artifact inventory

The community bundle at source `0428a053426a94f139d61510161f55e818cab3de`
was inventoried after signing and successful archive extraction/verification.
It contains nine regular files and no symbolic links: three ARM64 Mach-O
executables (app, CLI, helper), the Info.plist, Build.json, original ICNS artwork,
MIT license, AI skill Markdown and the resource-signature manifest. There is no
embedded interpreter, framework bundle, test probe or maintenance executable.
The tracked source inventory contains 44 Swift files; the remaining tracked files
are documentation, configuration, license and the Homebrew DSL template.

`otool -L` on all three executables lists only Apple system frameworks and libraries
under `/System/Library/Frameworks` and `/usr/lib`, including macOS's Swift runtime.
No Node/Python runtime, third-party dylib or private framework is linked directly.
A targeted source review found no manual `dlopen`/`dlsym`, private symbol binding
or selector-based dispatch. The undocumented `SleepDisabled` property and
`pmset disablesleep` invocation remain confined to `MacSleepBackend.swift`; the
policy/controller depend on its typed boundary. No power command was run for
this inventory. Earlier release-verifier results cover the signatures, runtime
flags and absence of entitlements on these exact binaries.

This evidence applies to this test artifact. It does not establish compatibility
across macOS releases, Gatekeeper acceptance, privileged installation or hardware
behavior. Repeat the inventory for the artifact selected for publication.

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
keyboard-only use, Reduce Motion and Reduce Transparency preferences remain manual
qualification gates.

On 2026-09-17, a fresh Debug inspection bundle was launched in the read-only active
fixture. A temporary Swift inspector used public Accessibility and CoreGraphics
APIs with the Mac's existing permissions; no permission was requested or changed.
It targeted only that bundle's process. AXPress opened the real menu-bar item,
whose accessible title was `Limitless: Staying awake`. The resulting native popover
measured 360 × 407 points at screen position (934, 35); its captured dark appearance
showed all content and controls without clipping. This validates one actual
menu-bar presentation, not every display/appearance combination. The separate
520 × 640-point settings window also rendered its visible controls correctly.
Protected controls remained disabled. Inspection screenshots are temporary local
evidence, not supplied artwork or a claim of real keep-awake state.

The inspector could focus the battery stepper, but injected per-process keyboard
events did not establish changed values or reliable Command-W/Command-comma behavior,
even with event-posting permission already present. AXPress can operate independently
of keyboard delivery, so these results do not qualify keyboard-only navigation or
prove a shortcut bug. No application behavior was changed to accommodate the tool.

Runtime-log review found Apple AppIntents `com.apple.linkd.autoShortcut` connection
errors (4097), BaseBoard task-port messages and cache-file lookup messages during
the development previews. No Limitless-originated error was identified in that
sample. A GUI launch inside the command sandbox aborted; the authorized native
preview outside that sandbox ran and exited normally. Recheck logs with the signed
installed app; these observations are not a claim of an error-free production run.
The 2026-09-17 preview again emitted Apple AppIntents 4097 and BaseBoard messages,
plus an AppKit `layoutSubtreeIfNeeded` re-entrant-layout warning during startup and
an Apple Siri eligibility message. The layout warning is not resolved or attributed
to a specific Limitless call site; it needs reproduction and diagnosis during native
qualification. The inspected preview quit normally after the check.

LLDB reproduced the layout warning at `_NSDetectedLayoutRecursion` in the Debug
bundle, with and without `--preview active`. Its stack passes through AppKit's
window-frame and view-layout updates, FrontBoard scene delivery and the normal
SwiftUI application loop; it does not identify a custom Limitless layout method.
One later identical run did not reach the breakpoint before an explicit normal
quit, so reproduction is intermittent. Removing the Settings scene's explicit
`contentMinSize` policy did not prevent it; that experiment was reverted.
Two short standalone SwiftUI controls (a text WindowGroup, then a MenuBarExtra
with Settings) exited normally without the layout breakpoint, while also emitting
the Apple AppIntents messages. These comparisons do not establish the cause or
prove a framework-only bug. Debugger/probe processes were stopped after inspection;
no experimental product code, permission changes or system-power writes remain.

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

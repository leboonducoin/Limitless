# Testing and evidence

## Current evidence

### 2026-09-19 compact controls, multiple PIDs and GitHub updates (build 7)

`ProjectTool.swift check` passed formatting, Release compilation, release-input
checks, maintenance-probe typechecks and 106 reported tests (47 core, 47 system,
3 CLI, 9 app); one opt-in hardware observation was skipped. New regressions cover
semicolon parsing/deduplication, waiting for both real unprivileged child processes,
idle-only update admission, stable-version/digest/repository validation and native
archive extraction with hostile path/link/size rejection.

The explicitly authorized local certificate signed **temporary fixtures only** for
`Tests/SignedUpdate/Run.swift`. Matching release acceptance, altered-resource
rejection, ad-hoc rejection, downgrade rejection, atomic bundle replacement and
backup restoration passed. The first fixture exposed Foundation's `/private/tmp`
URL alias normalization; production now uses `realpath` and separately rejects
staging symlinks. This test does not download or launch the new app, change an
installed app, register services, or exercise Gatekeeper. Synthetic fixture source
metadata is never release evidence. Reproduce after a Debug `check` build:

```sh
rtk proxy swift Tests/SignedUpdate/Run.swift CERT_SHA1 DEBUG_PRODUCTS_DIR BUNDLED_DEBUG_APP NEW_OUTPUT_DIRECTORY
```

The runner currently links the local CLT/Xcode build's static libraries; supply the
actual directory containing `libLimitlessSystem.a`, `libLimitlessCore.a` and their
modules. The coverage-runtime flag matches libraries produced by `check`. Ordinary
CI only typechecks these files; CodeQL compiles them without signing or executing.

A read-only native Debug preview confirmed the content-sized panel, compact footer
and GitHub link, exact timing list with only one No limit choice, conditional process
deadline controls, multi-selection and exact `697;660;9931` field input. Tab moved
focus; the native uninstall confirmation opened and was cancelled (its destructive
button is disabled in previews). Create a preview that opens through native app tools:

```sh
rtk proxy env LIMITLESS_BUILD_PATH=/private/tmp/limitless-swift-build LIMITLESS_OUTPUT_DIR=/private/tmp/limitless-preview-new LIMITLESS_PREVIEW_STATE=inactive swift Tools/ProjectTool.swift bundle
```

The active read-only preview also showed its countdown advancing without helper
polling and only one Stop control. Both previews quit through the native menu.
Runtime logs included Apple's App Intents connection warnings and an AppKit layout
re-entrancy warning during menu/window interaction (also present in the build 6
log). No app-specific crash or visible layout failure was observed; these logs do
not support a claim of warning-free native execution.

The uninstall report was investigated read-only: the system log recorded a
`NSCocoaErrorDomain` 513 / POSIX 1 app-trash error. Cleanup now uses Finder-style
`NSWorkspace.recycle`, visible progress, foreground errors and success feedback.
At inspection, `/Applications/Limitless.app`, both installed helper files and the
protected state directory were absent. The new privileged uninstall cycle remains
for the maintainer to test manually.

GitHub's latest-release endpoint returned HTTP 404; no public update exists. The
real download/install/relaunch lifecycle, community Gatekeeper prompts, helper
re-approval, orange status-icon dot, outside-click closure, live one-second timer,
and full VoiceOver remain manual acceptance checks. No power/login/helper setting
was changed during this work. Local tests and temporary signed replacement do not
claim those physical results.

Ponytail review retained native layout, timers, archive tooling and recycling; no
new runtime dependency or downloaded installer is used. Native review:

| Before | After | Why |
| --- | --- | --- |
| Fixed panel height and blank footer gap | Measured content with a screen-height cap | Compact idle view, scroll when needed |
| Apply and duplicate stop/no-limit controls | Serialized immediate edits and one Stop | Direct manipulation without duplicate actions |
| Silent-looking uninstall after confirmation | Progress, foreground errors and Finder-style recycling | Native permissions and visible outcome |

Hosted CI/security results must be checked on the pushed commit; earlier green
runs do not qualify this revision.

### 2026-09-19 menu and caffeinate refinement

The maintainer reported all of their manual tests working on the preceding build.
This revision adds a supervised caffeinate child and moves settings into the main
popover. `ProjectTool.swift check` passed the Release build, formatting, release
input checks, probe typechecks and 100 reported Swift tests (46 core, 44 system,
3 CLI, 7 app); the opt-in hardware observation was skipped. New coverage checks
assertion decoding, child termination with harmless `/bin/sleep`, assertion-loss
recovery limits, process-list identity, exact presets, empty-count visibility and
complete scoped preference cleanup. Ordinary tests never launch caffeinate.

Separate Debug ad-hoc bundles passed icon/plist/signature checks. Native read-only
previews were inspected in dark and light appearances: all settings and footer are
present, the exact timing menu is correct, process search/selection updates the PID,
the process list scrolls, Tab moves focus, native Quit works, and Uninstall's native
confirmation cannot execute in preview mode. The AppKit Edit menu preserves standard
text-editing shortcuts. No helper, login item or power state was changed. The literal
secondary-click gesture on the status icon and full VoiceOver remain manual checks;
the native action menu and confirmation were inspected through the application menu.
Preview runtime logs contained no reported error/fault/crash matches.

Before the decision to use GitHub only, Homebrew style (one file, zero offenses) and strict audit passed in a temporary local
tap using an explicitly non-release fixture digest. No package was installed. The
first fixture write failed because `tap-new` does not create `Casks`; after creating
that directory both checks ran successfully. No release checksum or URL was invented.

The GitHub-only decision removes the cask template, generation and Ruby validation.
The release-input self-check now explicitly verifies that the bundle opens the
graphical menu-bar executable. Earlier Homebrew sections below are historical,
not current installation instructions or release requirements.

Security's trusted-identity listing was empty, but the full identity listing still
contains the previously authorized local test certificate with `CSSMERR_TP_NOT_TRUSTED`.
An empty trusted listing alone does not prove it cannot sign; no trust-store change
is needed to test an exact certificate requirement. The current installed app and
power settings have not been changed. Signed packaging and manual caffeinate/cleanup
trials are separate from the automatic results above. Hosted checks will run on the
pushed revision; earlier green runs do not qualify this revision.

### Earlier evidence

2026-09-16 environment inspection: macOS 26.6.2, Apple M1 Pro, CLT Swift 6.4,
SDK 27.0. Full Xcode and a valid signing identity were not detected initially.
On 2026-09-17, the user authorized a dedicated local test identity, test signatures
and native integration/power trials. Signed installation, task tracking, power
restoration and removal now have local evidence below. No paid Apple membership
or trust-store exception was used. The final cleanup left no helper, login item
or owned hold; the test app remains in Applications. Downloaded Gatekeeper and
clean-Mac Homebrew qualification remain open.
The later Homebrew trial below passed local installation and removal after an
initial Gatekeeper block. Its test app, link, receipt, tap and Homebrew trust entry
were removed. No privileged integration was created by that trial.

The two libraries, app, helper and CLI executables pass strict swift-format and a Release
build. There are 91 default Swift Testing tests (45 core, 39 system, 3 CLI, 4 app, including
parameterized boundary cases).
One additional opt-in, read-only Mac integration test also passes on the inspected
MacBook. Separate Address Sanitizer and Thread Sanitizer runs pass all 92 tests
with that opt-in enabled at the 2026-09-17 absent-helper removal checkpoint.
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
the separate native trials below exercise signed deletion and ServiceManagement removal.
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
These ordinary tests never exercise native authorization or mutate a real installation.
CLI tests cover conflicting modes/stop conditions, malformed options, unbounded
representable durations, timezone-bearing dates and unchanged argument arrays.
Real unprivileged process tests verify exit codes, termination, duplicate launch
rejection, PID/start-time identity and owner changes. The built CLI's `--help`
works; `run -- /usr/bin/printf should-not-run` returned 69 without launching that
command because the development signature does not satisfy the production identity.
The installed skill-creator validator accepted `skills/limitless/SKILL.md`.
App tests reject misleading active/inactive presentation, invalid saved limits and
preview attempts to control the helper, automation, login items or removal.
Ordinary tests never call privileged power writes or create real sleep assertions.
Signed root-helper/CLI trials and native presentation inspection are recorded
separately below. Observing the global flag does not qualify physical lid-closed
execution, source transitions or restart behavior.

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
graphical bundle metadata checks, typechecking of the opt-in signed XPC probe/runner, Release
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

The [2026-09-18 CI run](https://github.com/leboonducoin/Limitless/actions/runs/35331976376)
passed on source commit `b5a457604f19ae6284894d50f1af1b1bb2673516`: baseline Release
build, Swift tests, both development bundle layouts, ASan and TSan. Each test run
reported 93 tests; ordinary CI leaves the opt-in hardware observation disabled.
The connection-owner regression passed in all three jobs. Local checks with the
read-only opt-in also passed (93 tests). No signed helper or power change was used.

The matching [Security run](https://github.com/leboonducoin/Limitless/actions/runs/35331976378)
also passed: workflow checks, full-history Gitleaks and CodeQL Swift/Actions. Swift
reported one certificate-fingerprint finding, reviewed as the narrow Apple
[compatibility exception](../SECURITY.md#reviewed-compatibility-exception), not a
clean scan with zero findings. No open CodeQL, secret-scanning or Dependabot alerts
remained after review. PR-only dependency review passed on Dependabot PR 3 in
[its Security run](https://github.com/leboonducoin/Limitless/actions/runs/35332149448);
that observation does not approve or merge the dependency update.

A subsequent documentation-only run on `c686e85` exposed an intermittent journal
reopening failure under TSan (`alreadyLocked`), while the baseline and ASan passed.
A deterministic local regression retained a duplicated lock descriptor and failed
with the same error before the fix: closing only the owner's descriptor does not
release a `flock` still referenced by that copy. The destructor now explicitly
unlocks before closing; `O_CLOEXEC` remains set. This covers the brief inherited
descriptor lifetime possible during concurrent process launch without adding
retries or serializing the test suite. The regression uses only a private temporary
directory and `dup`, with no helper, fork or power setting change.
The full local check with read-only observation passed after the fix (94 tests),
including the same regression that failed before the explicit unlock. A separate
local TSan build also passed; its hardware observation remained disabled.

The first authorized push to `main` on 2026-09-18 triggered the
[CI run](https://github.com/leboonducoin/Limitless/actions/runs/35329710628) and
[Security run](https://github.com/leboonducoin/Limitless/actions/runs/35329710625).
Xcode 26.2 rejected two direct `CocoaError`-to-`CFError` casts accepted by local
Swift 6.4. Both community installation failure paths now throw the retained system
error when present, otherwise the original Cocoa fallback, without a bridge cast.
Compilation on the CI baseline is the regression check; the existing ad-hoc-host
tests still reject installation/removal before native authorization. No privileged
integration test is needed for this source compatibility correction.

The next Release build exposed a Swift 6.2 cross-module compiler cycle resolving
`ServiceClient`'s isolated destructor. A temporary `-debug-cycles` run identified
that exact request. The actor now owns a small, non-Sendable connection lifetime
object with synchronous invalidation on destruction; explicit close and reciprocal
signature requirements are unchanged. A regression test verifies invalidation when
the owner is dropped without explicit close. It never activates the connection or
contacts a helper. The compiler diagnostic step was removed after diagnosis.

The checked-in workflows run on pull requests, pushes to `main`, and manual
dispatch. Security also runs weekly. Actions are pinned to verified full commit
IDs; checkout credentials are not persisted. Jobs have individual minimum
permissions and timeouts. No job installs the helper or changes power settings.
Private vulnerability reporting, secret scanning, push protection and Dependabot
security updates were verified enabled on 2026-09-18. Source publication and
successful CI do not qualify hardware compatibility or authorize a binary release.
See [SECURITY.md](../SECURITY.md) for publication prerequisites.

| Check | Local evidence through 2026-09-18 | GitHub execution on 2026-09-18 |
| --- | --- | --- |
| Release build, strict format, Swift tests | Passed | Passed |
| Development app bundle, icon export, plist and strict ad-hoc signature verification | Both Release layouts passed; modern Debug previously passed | Both Release layouts passed |
| Release input validation, Homebrew template syntax, ad-hoc release rejection | Passed | Passed in check and bundle |
| Address / Thread Sanitizer, separate builds | Both passed; runtime libraries verified in binaries | Both passed with Xcode 26.6 |
| actionlint 1.7.12 | Passed | Passed |
| zizmor 1.30.1, pedantic | Offline audit passed | Online audit passed |
| Gitleaks 8.30.1 | Full local history and staged changes passed | Full fetched history passed |
| CodeQL Swift and GitHub Actions, extended security | Not available locally with this CLT toolchain | Both passed; one reviewed Swift compatibility exception |
| Dependency review and Dependabot | Configuration inspected | PR 3 dependency review passed; skipped on main; Dependabot update run succeeded |

Primary CI uses Xcode 26.2 on `macos-26`, within CodeQL's documented Swift
compiler support. Sanitizers use Xcode 26.6, the stable default in the
[verified runner image](https://github.com/actions/runner-images/blob/macos-26-arm64/20260907.0351/images/macos/macos-26-arm64-Readme.md).
On that macOS 26.6.2 image, Xcode 26.2 TSan terminated before tests with signal 11
and ASan did not reach test discovery before the superseding run was cancelled.
These runs are failures/unqualified, not sanitizer passes. The baseline compiler
check remains separate, and sanitizer failures remain blocking. A temporary
LLDB diagnostic was removed after investigation; it never changed a failed job's outcome.
Go is a development-only runner dependency for pinned
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
requirement before any removal action. Signed service unregistration is covered
separately in the native lifecycle results below.

Release-tool self-checks reject malformed/injected Team IDs, invalid community
certificate selectors and ad-hoc artifacts. Synthetic signing-information checks
reject missing/invalid runtime flags or timestamps and any entitlement data. They
parse the Developer ID requirement and verify the graphical bundle entry point.
Release verification rejects nonnumeric versions; the exported archive's digest
is calculated from its actual contents. Each development
bundle repeats the negative signature check after its ordinary signature passes.
The builder also checks that the actual CLI version matches the bundle plist.
The community certificate and exported-archive checks have passed with a dedicated
local test identity, as recorded below. Developer ID/timestamp, Apple submission,
stapling, Gatekeeper and publisher release qualification remain unexecuted.
This Mac has Command Line Tools, not full Xcode; full Xcode is not required by
the community signing command. No notarization upload or public release is claimed.
An initial `brew style --help` probe could not create Homebrew's cache in the
restricted environment. The later authorized run passed style and strict audit
in a temporary tap; installation, the initial block and completed removal are below.

The complete physical and accessibility matrix, clean-Mac download and
upgrade qualification, independent provenance attestation and optional Developer ID
release paths remain separate gates. The maintainer owns manual hardware and UI
acceptance following the 2026-09-18 handoff; these trials are not automated by CI.

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

After the native lifecycle fixes, build 4 at
`d884835c77d6aea6551eb9d1c288ed4de44395dc` was packaged again from its clean checkout.
`community-package` passed strict verification of the installed app and the actual
re-extracted ZIP. The local `Limitless-0.1.0-arm64.zip` SHA-256 is
`860d1d4bbf71ea7e96c4e9b3c0d4e635fc4ce5b27702594253566d62bc42f46a`.
Its manifest records that exact source, the real test certificate, community
channel and `notarized: false`; its draft cask is unpublished. This supersedes the
earlier archive for local testing, without qualifying publisher or download trust.

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
workflow compiled them for analysis without signing/execution in the successful
Security run linked above.

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

## Privileged installation trial

On 2026-09-17, after explicit user authorization, the signed community bundle at
`0428a053426a94f139d61510161f55e818cab3de` was opened and its actual Enable Limitless
button invoked through native accessibility. Authorization Services and SMJobBless
installed the helper. launchctl reported a running system job and both expected
Mach endpoints. The signed CLI returned an authenticated inactive status:
`observed=allowed`, zero sessions, automation disabled. No keep-awake session or
login item was activated. The installed executable and plist were root-owned,
without group/world write permission; the state directory was root-owned 0700.
Security's strict/all-architectures check with the exact identifier/certificate
requirement succeeded on both the installed and source helper (OSStatus 0).

The actual `LimitlessApp --prepare-uninstall` then exited 1. Status remained
inactive/allowed with `removal=preparing`. Inspection found that SMJobBless added
`Program` pointing to the fixed helper path. The validator incorrectly required
this key to be absent. The existing idempotent-removal test now exercises both
forms; the installed form failed before the fix with `unexpectedContents` and
passes after it. A different Program remains rejected by the existing negative
test. Build number 2 identifies the corrected helper for native replacement.

The old test job was unloaded through a one-off local Swift call to the public
SMJobRemove API with native administrator authorization, after checking the pinned
helper/CLI signatures and the authenticated inactive/preparing status before and
after the dialogue. It deleted no files and changed no power setting. This was
test recovery, not a successful product uninstall; the corrected installer must
repair the same-certificate unloaded installation and complete guarded removal.
No trust policy, quarantine, Gatekeeper, SIP or TCC setting was changed.

The complete local `check`, ASan and TSan passed all 89 tests after the fix (the
additional Program form is a case of an existing test). The corrected native cycle
is pending at this checkpoint. The Graphify structure is current. The complexity
review retained the existing validator and parameterized test; no new product
abstraction or dependency was added.

The signed build 2 at `5504b56` repaired the unloaded same-certificate installation;
SHA-256 of its source and installed helper matched. The next removal deleted both
installed files and the journal, but the app exited 1 and the job stayed loaded.
Native logs show that the reply was forbidden by the XPC code-signing requirement
after the executable was unlinked. This exposed a separate ordering defect.

Protocol 3/build 3 separates authenticated restoration/journal preparation from
`finishRemoval`. File deletion remains application-only and is refused before
preparation; existing authorization and protocol round-trip tests cover the new
operation. The helper rechecks its ready state, retired journal, observed restoration
and absent idle assertion before deleting the captured files. The app accepts no
unverified final reply: it checks protected-path absence and the native installer
checks an allowed sleep flag, including after administrator consent. This also lets
an interrupted removal resume when all protected files are already absent.
The complete local check, ASan and TSan each passed all 89 tests after this ordering
fix. Graphify is current (598 nodes/1245 edges). The complexity review retained the
existing request, installation and filesystem machinery with one extra operation;
no timeout-based deletion, unauthenticated channel or replacement installer was added.
The subsequent signed native retry is recorded next.

The build 3 retry unloaded the remaining job and all protected paths stayed absent,
but returned failure at login-item cleanup: native logs reported status 3/notFound
and unregister error 1 for an item never registered. The same signed app was then
copied to an initially absent `/Applications/Limitless.app`. Its native Launch at
login toggle successfully changed from off to on, then off, with no helper present.
The official uninstall hook subsequently exited 0. No login/reboot was performed.
Build 4 treats `notFound` as a previously unseen login service, as explained by
[Apple DTS](https://developer.apple.com/forums/thread/719862), and avoids unregistering
that nonexistent item. It still checks final status and rejects an unknown future
state. Enabled and approval-pending services must complete native unregistration.
The complete check, ASan and TSan passed all 89 tests after the login fix.
The signed native cycle with this final login fix is recorded next. Graphify is
current (599 nodes/1251 edges); the complexity review retained an inline check of
native statuses, without another wrapper or dependency.

**Build 4 native result:** the signed bundle at `d884835` was installed into
`/Applications/Limitless.app` and its native Enable action installed the root helper.
Source and installed helper SHA-256 matched
`6e056f375ea4075487cbd6c884835c3fbfb0738b0566940d8c68214c6c00d10e`.
The signed CLI returned inactive/allowed, no sessions, automation off and a real
battery reading. After quitting the inactive app, its official
`--prepare-uninstall` hook exited **0**. Independent checks confirmed launchctl
service-not-found (113) and ENOENT for the executable, launchd plist and state
directory. This completes the local signed **inactive** installation/status/removal
cycle, without paid membership or added certificate trust. It does not qualify
active-session restoration, a real login/reboot, Gatekeeper downloads, Homebrew
distribution or closed-lid behavior. The test app bundle remains in Applications;
no helper or login item remains registered at this checkpoint.

The same hook also exited 0 when repeated from the other signed build 4 copy with
all integrations absent. The helper was then reinstalled for authorized live power
tests. With automation off, `limitless run -- /usr/bin/swift --version` returned 69/
`sessionRejected` before launching the command. After the actual app toggle enabled
automation, `limitless run --for 2m -- /usr/bin/swift Tools/ProjectTool.swift check`
ran the real validation task (89 tests). On battery, status showed one active task,
`observed=disabled`, `ownsGlobalHold=true`, floor 20% and a 120-second deadline.
The command exited 0; subsequent status showed zero sessions, inactive/allowed,
and no owned global hold. The floor stayed at 20% throughout.

Two further real validations ran concurrently through `run -b`, bounded to 120
and 90 seconds, using separate SwiftPM scratch paths: a clean full check and a
shorter TSan run. Both sessions were observed active together. After the TSan
command exited 0, the full check still had one active session and the flag remained
disabled. The official uninstall hook then exited 0 while that command was still
running. The CLI reported that protection ended and would not restart; the command
continued to completion with all 89 tests passing and exit 0. Independent inspection
confirmed `IOPMrootDomain.SleepDisabled = No`, no launchctl job, and no journal,
daemon plist or installed helper. This verifies active removal without terminating
tracked user work. No active helper or login item remains after these trials.
Actual lid closure, AC transitions and reboot remain separate
gates; the successful flag observation alone does not prove lid-closed execution.

## Live task limits and idle observation

Further authorized trials used the same signed build 4 on battery, with the lid
open, no maximum duration initially, floor 20% and automation explicitly enabled.
Each tracked workload was a real `swift Tools/ProjectTool.swift check`, with the
read-only integration opt-in and a scratch directory outside the repository. All four workloads
reported complete local-check success (89 tests). A temporary non-root Swift
observer sampled authenticated CLI status about every 0.5 seconds; status requests
also reconcile the helper, so these timings do not bound standalone watchdog latency.

| Trial | Observed result |
| --- | --- |
| `run -c --for 2m` while on battery | The accepted session stayed suspended for `powerSource`; the flag stayed allowed and unowned. CLI printed the suspension warning; work exited 0 and left no session. |
| `run -a --for 3s` | Initially active/disabled/owned; at the 3.35-second sample it was inactive/allowed with zero sessions while work continued. Work finished at about 22 seconds with exit 0 and no reacquisition. |
| `watch -b --for 2m --pid` against the observer's real validation process | One active hold persisted while that specific process ran; watcher and work exited 0, followed by zero sessions and allowed/unowned state at about 17 seconds. The watcher did not signal the work. |
| `run -a --unlimited` with an app-applied six-second maximum | Authenticated policy confirmed the cap. At the 6.62-second sample, protection had ended while work continued. It stayed ended through validation completion at about 12 seconds; CLI reported that work could continue but protection would not restart. |

With user floor 20%, requesting 19% was refused with exit 69/`sessionRejected`
before command launch; 51% was rejected by the parser with exit 64. The native
stepper was then exercised from 20% to 0% and back, verifying each single-percent
step. An unapplied 0% draft left the helper at 20%. After explicit Apply, both the
native warning and signed CLI warning were observed; `run --battery-floor 0
--for 3s -- /usr/bin/swift --version` exited 0. The floor was restored to 20%.
This checks warning and policy behavior, not actual discharge to a cutoff.

The native maximum-minutes field uses the system decimal separator. On this Mac
(`en_US@rg=frzzzz`), `0,1` applied six seconds. The attempted dot-decimal entry was
invalid and did not apply; reading authenticated helper policy prevented treating
a draft as an applied limit. The maximum was removed again after the trial.

With both windows closed, no sessions and the helper installed, four `top` samples
ten seconds apart showed app CPU at 0.1–0.3% after the initial sample and helper CPU
rounded to 0.0%. CPU time increased about 0.09 and 0.02 seconds respectively; memory
was 47 MB for the app and 4528 KB for the helper. This thirty-second sample does
not measure wakeups, sustained energy use, thermal behavior or battery autonomy.

Finally automation was revoked, authenticated status confirmed floor 20%, no cap,
zero sessions and inactive/allowed/unowned state, and the app quit normally.
The official removal hook exited 0. Independent IORegistry read returned
`SleepDisabled = No`, launchctl returned service-not-found (113), and the helper,
daemon plist and state directory were all absent. No login item, active test
process or privileged installation was left behind.

## Live interruption and owner loss

Four more authorized build 4 trials ran on battery with floor 20%, no user duration
cap and an initially empty session registry. The two `watch` trials observed a real
`ProjectTool.swift check`; the two `run` trials launched real Release compilations
into distinct, new scratch directories. Only CLI processes created by the temporary
Swift observer were signaled. The helper and unrelated processes were never signaled.

| Case | Observed result |
| --- | --- |
| SIGTERM to `watch -b --for 2m` | Signal sent at 1.20 s; inactive/allowed with zero sessions at 1.79 s; watcher exited normally with status 143. The watched validation continued and passed all 89 tests, exit 0, at about 22 s. |
| SIGKILL to `watch -b --for 2m` | Signal sent at 1.22 s; watcher dead and inactive/allowed at 1.81 s. Its termination reason was uncaught signal 9. The watched validation continued and passed all 89 tests, exit 0, at about 16 s. |
| SIGTERM to `run -b --for 60s` | Signal sent after the actual Release-build startup at 2.38 s; the wrapper exited normally with propagated build status 143 and inactive/allowed state at 2.98 s. |
| SIGINT to `run -b --for 60s` | Signal sent after actual build startup at 1.19 s; the wrapper exited normally with propagated build status 130 and inactive/allowed state at 1.79 s. |

Each case first observed an active, disabled hold, then confirmed zero sessions
and no owned global hold. Protection never restarted during the surviving watched
work. A process search limited to the two unique build scratch paths found no
remaining Swift/Clang compiler from the interrupted `run` trials. Those cancelled
builds are signal tests, not successful build results. The two uninterrupted
`check` workloads supplied complete-check evidence separately.

Status was sampled about every 0.5 s and also causes reconciliation; the timings
are observations under polling, not a standalone watchdog guarantee. These trials
qualify live CLI signal handling and connection-owner loss, not a helper crash,
root-journal recovery, foreign power writes, restart or reboot.

Automation was revoked after the trials. Authenticated status confirmed floor 20%,
no cap, no sessions and allowed/unowned state. The app quit normally and the official
removal hook exited 0. Independent checks confirmed launchctl 113, all three root
helper/state paths absent, and `IOPMrootDomain.SleepDisabled = No`.

## Live manual sessions and Stop all

Three further build 4 trials used the native menu-bar controls on battery, with
floor 20%, both power sources allowed and no user duration cap. The custom duration
picker was set to 90 seconds. The helper was enabled through the native setup
button; CLI consent was granted only for the trials.

| Case | Observed result |
| --- | --- |
| Manual session plus a real CLI `check` | One manual and one task session were observed active. At 11.96 s the CLI had exited 0 and only the original manual session remained, with the global hold still applied. Native `End my session` then restored inactive/allowed state with zero sessions. |
| Native custom-duration expiry | The first authenticated sample showed 85.69 s remaining in the 90-second manual session. At 86.35 s from observer startup the session had expired and state was inactive/allowed/unowned. No session reappeared during five further seconds. |
| Native `Stop all` with manual and CLI sessions | Two sessions were observed at 0.61 s; after the native button press, zero sessions and allowed/unowned state were observed at 1.88 s while the real validation still ran. Automation was revoked. The work exited 0 at about 16 s without reacquiring protection; a subsequent CLI request was rejected with status 69 before its command launched. |

Both real `ProjectTool.swift check` workloads passed all 89 tests and the complete
local check command. These are live session results, not new test counts or another
sanitizer qualification. Status polling at about 0.5 s also triggers reconciliation;
the timings do not establish a standalone watchdog bound.

The temporary UI probe initially attempted a button after the popover was no longer
exposed and refused the action. Presenting the popover and pressing its control in
one process made the later trial succeed. A separate probe compile error was also
fixed before its successful run. Neither failed preparation is counted as a passed
trial or an application crash. The expiry observer itself issued only signed status
requests. Manual process/date inputs, long runs, full keyboard/VoiceOver and physical
lid/source transitions remain separate gates.

Afterwards automation was off, floor 20% and the absent duration cap were unchanged,
and no session remained. The app quit normally, the official removal hook exited 0,
launchctl returned 113 and all three protected helper/state paths were absent.
Independent IORegistry observation confirmed `SleepDisabled = No`.

## Homebrew cask validation

Homebrew 7.0.2 was exercised on the same Mac on 2026-09-17. The authorized `style`
run installed Homebrew's own Ruby development gems; these are outside Limitless
and add no runtime to its app, helper or CLI. Running on a loose Ruby file first
reported generic Sorbet/frozen-string comments. The same bytes placed in the
standard `Casks` directory received the actual tap/cask rules and passed without
changing the recipe. Homebrew no longer accepts a path argument for `audit`.

The original build 4 generated cask was copied byte-for-byte into a new local tap
created with `brew tap-new --no-git limitless-local/checks-20260917`. Both commands
below exited 0; style reported one file and no offenses:

```sh
rtk proxy env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_DEVELOPER=1 brew style --cask limitless-local/checks-20260917/limitless
rtk proxy env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_DEVELOPER=1 brew audit --cask --strict limitless-local/checks-20260917/limitless
```

For an isolated install trial, only the temporary cask's URL was then changed to
the local build 4 ZIP. Its actual SHA-256 and all artifacts, removal directives
and caveats were unchanged. The source template and generated release cask were
not modified. Normal `brew install --cask --require-sha --no-ask` with
`--appdir=/private/tmp/limitless-homebrew-install` exited 0, installed the app and
linked `/opt/homebrew/bin/limitless` to that exact copy. Those destinations and
the cask receipt did not exist beforehand. No existing app was adopted/overwritten.
Homebrew recorded version 0.1.0/build 4 and the real archive checksum.

Quarantine was present on the installed app. `community-verify` passed its strict
signature, certificate, architecture and metadata checks. Gatekeeper assessment
(`spctl --assess --type execute --verbose=4`) nevertheless returned **3/rejected**.
The official `brew uninstall --cask` then returned **1**: macOS killed
`LimitlessApp --prepare-uninstall` before it could run. `must_succeed` preserved
the app, CLI link and receipt. Scoped system logs confirmed AMFI error -423
(unknown certificate chain), a Gatekeeper denial and AppleSystemPolicy refusing
that exact executable. No alternate launcher, removed quarantine, certificate-trust
change or forced uninstall was used. This is a tested pre-approval removal block,
not successful Homebrew removal or proof of the first-launch user-decision flow.

The user was asked to perform the native macOS opening decision manually. Later,
the exact Homebrew copy was observed running as the normal GUI app, without the
assistant launching it or changing security settings. The button sequence itself was not
inspected or automated. Its linked CLI then printed help with exit 0 and returned
69/`unavailable` for status, as expected with no installed helper. No helper or
power hold was created by simply opening this copy.

A second normal Homebrew uninstall exited **0**. Homebrew itself successfully
quit the running GUI, invoked the mandatory hook, then removed the app, CLI link
and cask receipt. Their absence was checked independently. The temporary cask's
Homebrew trust entry was removed with `brew untrust --cask`, then its tap was
removed with `brew untap`, without force; both absences were checked. The empty
test app directory was also removed. The original app in Applications is intact.

Homebrew announced autoremove candidates `libevent` and `unbound` after its first
failure, but `brew list --versions` confirmed both remained installed (2.1.13 and
1.26.1), including after final teardown. The retry used, and future teardown must use,
`HOMEBREW_NO_AUTOREMOVE=1` as well as `HOMEBREW_NO_INSTALL_CLEANUP=1` to avoid
affecting unrelated packages. No other formula removal was attempted.

The offline strict audit does not validate the unpublished GitHub URL, online
acceptance, the complete first-open flow on a clean Mac, upgrades or active Homebrew
removal. This local test used an already tested certificate and an on-disk archive;
it cannot substitute for those gates. Reinstallation and zap were exercised later,
as recorded below.
See [Homebrew command definitions](https://docs.brew.sh/Manpage)
and [Apple's manual opening decision](https://support.apple.com/en-gb/102445).

### Local reinstallation and zap

A second trial on 2026-09-17 used the same build 4 archive, checksum and temporary
tap/app directory. The build 5 app in `/Applications` stayed in place. No helper,
login registration or awake session was created. Before testing, the existing
Limitless preferences were exported to a private temporary backup; its cache and
saved-application-state directories did not exist.

Installation exited 0 with quarantine present. The first direct CLI/help and
cleanup-hook executions were killed with signal 9 (exit 137). Scoped AMFI logs
reported error -423, an unknown signing chain, and AppleSystemPolicy denial for
those exact executables. Gatekeeper assessment returned 3/rejected. The subsequent
normal `brew reinstall --cask --require-sha --no-ask` nevertheless exited 0: its
mandatory cleanup hook ran successfully before Homebrew replaced the app and CLI
link. CLI help then exited 0 and the app's quarantine value was unchanged. The
cause of this change in execution acceptance was not observed; no security
exception or quarantine removal was automated. This sequence does not qualify
the first-open flow or establish a dependable workaround for a blocked app.

After reinstallation, the saved preferences matched the backup. Two test-only
directories with marker files were then created at the previously absent cache
and saved-state paths. `brew uninstall --cask --zap` exited 0, ran the mandatory
hook and trashed all three declared zap paths. Independent filesystem checks
confirmed absence of the app, CLI link, receipt, preferences, cache and saved state.
The original preferences were then restored and their persistent domain compared
equal to the backup, preserving settings for the retained build 5 app.

All install/reinstall/removal commands set `HOMEBREW_NO_AUTO_UPDATE=1`,
`HOMEBREW_NO_ANALYTICS=1`, `HOMEBREW_NO_AUTOREMOVE=1` and
`HOMEBREW_NO_INSTALL_CLEANUP=1`. The temporary cask trust, tap and empty app directory
were removed normally. The developer mode automatically enabled by `tap-new` was
turned off again. `libevent` and `unbound` remained installed at their original
versions. Final checks found no Limitless GUI process, system job, installed helper
files or root journal, and `SleepDisabled = No`. The retained build 5 passed
`community-verify`. No force, adopt, quarantine bypass or publication was used.

This verifies same-version local reinstallation and scoped zap for build 4 with
inactive integrations. It does not verify an upgrade, active-helper cask removal,
the latest build's complete cask lifecycle or a download on a clean Mac.

### Build 5 active cask removal and repeat installation

The current build 5 archive was then tested through the separate local tap
`limitless-local/build5-20260917` and app directory
`/private/tmp/limitless-homebrew-build5`, using its real generated checksum.
The unmodified generated build 5 cask also passed `brew style --cask` (one file,
zero offenses) and `brew audit --cask --strict` in a separate temporary local tap.
These offline checks do not validate the unpublished download URL.
Its installed copy passed `community-verify` for source
`1cfaffca03de61e4f152c128739e3c62d76b8845`; quarantine remained present. The app
was eventually observed running after a normal opening request and initial AMFI
rejection. The native first-open decision itself was not inspected or automated;
`spctl` still returned 3/rejected. This was the same test Mac, not a clean-machine
Gatekeeper qualification.

The actual Enable button installed the helper through the native adapter. Its
hash matched the signed bundle. Authenticated status initially showed automation
off, zero sessions, allowed sleep and no ownership. Automation was enabled through
the native Settings control, then confirmed through signed status with mode `all`,
battery floor 20 and no user time cap. The Mac was on battery at 87%.

The signed CLI ran the repository's real complete `check` with a two-minute task
limit. After signed status and independent IORegistry observation confirmed one
active owned hold, the trial started normal `brew uninstall --cask`. Homebrew quit
the GUI and ran the mandatory cleanup hook. Relative to the task launch, sleep
was observed allowed at **1.81 s**; Homebrew had exited 0 at **5.30 s**, while the
tracked work was still running. Sleep stayed allowed through task completion.
The work exited 0 with **92 tests** and the remaining local checks passing. The
trial verified absence of the system job, helper files, root journal, app, CLI
link and receipt. During removal it observed IORegistry without polling signed
status; these timestamps describe this run, not guaranteed cleanup latency.
Trace and workload/removal logs were retained under
`/private/tmp/Limitless-homebrew-active-66741B46-0DFC-4BD8-A944-F0E0061E7684`.

A fresh installation preserved preferences and did not recreate the helper or
hold. Its first CLI execution and normal reinstall hook were killed by macOS;
the failed reinstall exited 1 and retained the app, link and receipt. After that
exact GUI copy was observed running, it showed **Setup required**, and signed CLI
status exited 69/unavailable. A normal reinstall retry exited 0 with preferences
unchanged. No force or quarantine removal was used. Subsequent `brew uninstall
--cask --zap` exited 0 and removed all three declared preference/cache/saved-state
paths; the two previously absent directories contained only test markers.

Original preferences were restored from the private pre-test backup and compared
equal. The temporary cask trust, tap and empty app directory were removed normally,
with auto-update, analytics, autoremove and install cleanup disabled throughout.
The primary build 5 app in `/Applications` was preserved and verified again.
Final checks found no GUI instance, system job, helper files or root journal and
`SleepDisabled = No`. This qualifies local build 5 active removal, same-version
reinstallation and scoped zap. A real upgrade, clean-Mac download/opening flow,
approval revocation and interruption during removal remain open.

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

Command-comma and Command-W did not produce an observable action through that
automation session; the later Settings trial below resolved this gap. VoiceOver
speech, full
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

The later signed-app probe found that hardcoded US key positions are incorrect on
this Mac's AZERTY layout: an intended Select All initially sent Quit. AppKit logs
confirmed normal termination, not a crash. The probe now resolves character keys
through the active public keyboard-layout APIs and uses the current decimal
separator. A retry with in-process activation still did not establish Command-W
or Command-comma behavior; the native close button and Settings menu action did
work. Keep full keyboard and VoiceOver qualification open, without adding an app
workaround for inconclusive injected events. Signed-runtime error samples also
contained Apple's TextInputUI ViewBridge cancellation and inputAnalytics connection
interruption; no Limitless-originated error was identified in that limited sample.

### Settings keyboard qualification

A later build 5 inspection on the same Mac verified Settings navigation, draft
inputs and shortcuts. The installed app had no helper or awake session. The native
UI driver timed out while the menu-bar app had no ordinary window, although its
process had finished launching. A scoped Swift Accessibility action opened
Settings and verified activation; the UI driver then inspected and operated that
window successfully. No permission, system accessibility setting or product code
was changed to make the inspection work.

Tab and Shift-Tab moved through the selected power-source segment, battery stepper,
duration toggle, login toggle and removal controls; disabled controls were skipped.
Up/Down changed the battery draft from 20 to 21 and back to 20. Space exposed the
maximum-duration field; the field retained the current locale's `1,5` after Tab,
then showed the restored `120` before the limit was switched off again. These were
draft edits only: Apply was disabled and the saved preferences remained unchanged. A native dark
screenshot showed the visible keyboard focus ring and readable controls.

The driver's `super+a` unexpectedly quit the app, consistent with the previously
identified AZERTY mapping problem: the active layout maps key code 0 to Q and 12
to A. Character shortcuts were therefore checked separately using the public
keyboard-layout API and events sent only to the active Limitless PID. Adding a
Unicode text payload to a correctly resolved Command-W event still produced no
close action. Removing that unnecessary payload let macOS interpret the native
key: Command-W (code 6) closed Settings and Command-comma (46) reopened it.
Command-A (12) selected the entire `120` value after Right had collapsed the
selection. The corrected probe passed Swift 6 typechecking with warnings as errors.

Tab reached Prepare for removal, Space opened its native confirmation with Cancel
focused, and Escape dismissed it and returned focus to the originating button.
The destructive action was never invoked. Login and automation remained off.
Normal Quit completed; final checks found no app process or helper job and
`SleepDisabled = No`. Scoped error/fault logs contained Apple's AppIntents 4097,
BaseBoard task-port and TextInputUI ViewBridge messages; no Limitless-originated
error was identified in that sample.

This qualifies the exercised Settings paths after opening its window, not an
entire keyboard-only journey from the system menu bar. Menu-panel controls,
privileged keyboard actions, VoiceOver speech and system reduced-motion/contrast/
transparency preferences still require qualification. The earlier inconclusive
shortcut probes are not evidence of an application defect.

The subsequent menu-panel-only attempt remained inconclusive. The native UI
driver timed out even with the real setup panel exposed. A temporary, scoped Swift
probe could open that panel, but a Tab sent in the same process left AX focus on
the window; separate calls found the app inactive and refused key delivery. The
probe passed Swift 6 typechecking with warnings as errors. No setup button was
activated, helper installed or power session started. Normal app termination was
confirmed with zero remaining instances, helper job absent (113) and
`SleepDisabled = No`. Do not repeat these injection attempts as a substitute for
an operator's keyboard walkthrough; the active panel's start/stop path remains
unqualified.

### Earlier preview diagnostics

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

The signed build 4 manual-session run also emitted the same startup layout warning,
Apple AppIntents 4097 and a BaseBoard message. Its targeted error/fault log contained
Security runtime diagnostics warning against a main-thread method call and
SMAppService status lookup error 22 around helper setup. The Security warning was
subsequently attributed and corrected as described below; this does not resolve
the other diagnostics or quantify a sustained UI stall.

### Asynchronous signature validation

A certificate-signed Debug control reproduced the Security fault under LLDB.
The runtime logger identified `SecTrustEvaluateThreadRuntimeCheck`; a breakpoint
on `SecTrustEvaluateIfNecessary` then showed the originating main-thread stack:
`SecCodeCopySigningInformation` → `SignedIdentity.init` → `AppModel.init`.
The ad-hoc Debug control did not reach the same fault. No trust store, entitlement,
Gatekeeper or other system security setting was changed for this comparison.

App startup and `ServiceClient` initialization now await the shared `@concurrent`
identity check. On the corrected certificate-signed Debug copy, the same native
breakpoint ran on `com.apple.root.user-initiated-qos.cooperative` through
`SignedIdentity.current` and `AppModel.prepareForLaunch`. Its normal GUI launch and
menu opening emitted no Security main-thread fault in the targeted log sample;
Apple AppIntents 4097 messages remained. This demonstrates the thread change, not
an error-free app or a measured latency improvement. All Debug targets were stopped.

The complete local `check`, ASan and TSan runs each passed all 91 tests. New
regressions cover pending/untrusted startup controls and asynchronous rejection of
the test host for both client roles. The eight signed XPC cases also passed with
the client using the asynchronous identity API. Initially moving the embedded test
service's bootstrap across an await caused a real libxpc crash:
`_xpc_objc_main() is not supposed to return`, through `NSXPCListener.resume`.
Its original synchronous bootstrap was retained, matching the production helper;
the successful repeat still exercises asynchronous client verification and all
reciprocal pin/identifier refusals. No privileged service is installed by this test.

The corrected signed Debug CLI reached the absent service and returned 69
(`unavailable`), rather than rejecting its own signature. A native window capture
confirmed the prepared setup panel but exposed a truncated administrator-explanation
sentence. The setup container now preserves its full vertical size; a second native
capture shows both complete lines, including the password assurance, at the same
panel width. Accessibility exposes the complete text and the existing named controls.
A PID-targeted Tab attempt left focus on the window and was inconclusive; full
keyboard/VoiceOver remains unqualified. A fresh complete `check` passed all 91 tests
after this one-line layout correction. The final launch log sample still contained
AppIntents 4097, with no Security main-thread fault. No new UI framework, animation
or policy path was added.

The no-helper removal hook returned 1 in both pre-change and corrected Debug **bundled** layouts:
SMAppService reported `notFound`, followed by unregister error 1. This exposed a
separate existing cleanup defect. The shared removal proof now accepts a missing
native service only when the fixed system job is independently absent, the protected
journal and installed paths are absent, and a fresh sleep observation is allowed.
Enabled or approval-pending services still require successful native unregistration;
an unknown job, remaining files or unreadable/disabled power state still blocks completion.
One parameterized regression exercises nine combinations of native and system-job status.
The complete `check`, ASan and TSan each passed 92 tests after this correction.

A fresh Debug bundled app, signed with the authorized local certificate, then ran
`--prepare-uninstall` twice: both calls exited 0. Native logs still reported status 3
without an unregister attempt; AppIntents 4097 messages remained. No helper or login
item was created. Independent checks confirmed launchctl 113, all three protected
paths absent, no remaining Limitless GUI and `SleepDisabled = No`. This qualifies
the never-installed bundled cleanup path, not a notarized SMAppService installation.
The later community build 5 trial below includes these source changes.

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

## Community build 5 qualification

Release build 5 (version 0.1.0, protocol 3) was produced from clean source
`1cfaffca03de61e4f152c128739e3c62d76b8845`, including asynchronous identity checks,
the setup text correction and guarded absent-helper removal. `community-sign`,
`community-verify` and `community-package` passed with the same authorized local
test certificate. The archive was extracted and verified again before its digest,
manifest and draft cask were written. Nothing was published. Its ZIP SHA-256 is
`b1822b871ec7f478f5bd2dd9f45c236d7980ac933b736bb05826ca5ef7dc14c7`.
The previous installed build 4 was preserved before copying build 5 to Applications.
A direct sandboxed codesign check reported `CSSMERR_TP_NOT_TRUSTED`; the normal
community verifier outside that sandbox then passed on the exact installed copy.
No trust setting or signature requirement was changed to obtain this result.

Native Enable completed SMJobBless installation. The installed helper SHA-256
matched the bundled helper:
`0b44f3850ca2fcd99596f1e8c6c28c57e43c55f580a44b45ec3fbbda18708ff5`.
Both the app and CLI obtained authenticated status. Initial policy was automation
off, battery floor 20%, all sources, no duration cap; no session or hold was restored
at startup. The Mac was on external power for this trial.

After enabling automation through native Settings, two separately tracked real
`ProjectTool.swift check` workloads each exited 0 with 92 tests:

| Trial | Observation |
| --- | --- |
| `run -a --for 3s` on external power | One active session and disabled sleep; at 3.07 s, zero sessions and allowed/unowned sleep while validation continued. Validation finished at 22.66 s without reacquisition. |
| `run -b --for 2m` on external power | One session suspended for power source, allowed/unowned sleep throughout; validation finished at 11.41 s and the session disappeared. |

The observer queried signed status about every 0.5 s; these queries also reconcile
state, so the timings are not isolated watchdog-latency measurements. External
power was already present; this does not qualify an active AC attach/detach transition.
Automation was revoked afterwards and confirmed off with the floor unchanged at
20%, no cap, zero sessions and allowed/unowned sleep. After normal GUI termination,
the official removal hook exited 0, then a repeated call also exited 0. Independent
checks confirmed launchctl 113, the three protected paths absent, no remaining GUI
and `IOPMrootDomain.SleepDisabled = No`. Targeted startup/installation and removal
log samples contained no Security main-thread fault. This is no claim that all
runtime warnings, keyboard/accessibility or physical hardware gates are resolved.
The installed test app and local archive are now build 5; earlier build 4 evidence
above remains specific to its own binaries.

### Native process and date stop controls

The same signed community build 5 was re-enabled through its native setup control
on external power. The starting state had no session, allowed/unowned sleep,
automation off, battery floor 20%, all power sources and no duration cap. Automation
remained off throughout both manual tests; no CLI task session was requested.

For **When a process ends**, the probe launched an unprivileged real
`ProjectTool.swift check`, entered that process's PID in the native field, focused
and confirmed the field, then pressed **Keep awake**. Signed status showed one
active manual session while validation ran. At 20.84 s from the first observation,
the process had exited successfully, its session was absent and sleep was
allowed/unowned. Three further seconds showed no reacquisition. The workload
passed all 92 tests. Limitless observed the process without terminating it.

An earlier probe set the accessible field value but omitted native confirmation.
The number was visible, but the app rejected the input and created no session;
the workload still passed. This is an unsuccessful input simulation, not passing
process tracking. Focusing and confirming the field fixed the probe; no product
code or process-identity validation was changed.

For **At a date & time**, the native date control was set to
2026-09-17 16:15:00 Europe/Paris (14:15:00 UTC). Its accessible date and the helper's
applied deadline matched: the initial remaining time was 94.40 s. At 94.71 s from
observer startup the session was absent and sleep was allowed/unowned, with no
reacquisition during three further seconds. The same now-past date was then
submitted again: the native validation message appeared and signed status
confirmed no session or hold. An initial attempt to press a control after the
popover closed did not execute; presenting and submitting it in one scoped probe
produced the actual refusal evidence.

Both observers queried signed status about every 0.5 s, which also reconciles
state. These times are observations, not isolated app-timer or watchdog latency.
The probes used public Accessibility APIs against only the exact installed
Limitless bundle and existing permissions. Native date-input and active-countdown
captures were inspected: the control, complete labels and countdown fit the panel.
This qualifies these native UI paths through Accessibility, not keyboard-only use,
VoiceOver, a long-duration run or a physical power transition.

Afterwards signed status confirmed automation off, floor 20%, no cap, zero sessions
and allowed/unowned sleep. The GUI quit normally and the official removal hook
exited 0. Protected helper/plist/journal paths were absent and independent
IORegistry observation was `SleepDisabled = No`. The targeted runtime-log sample
still contained AppIntents 4097 during the removal hook, with no logged fault;
this is not an assertion that all framework warnings are resolved.

## Manual helper restart observer

`Tests/NativeMac/ObserveHelperRestart.swift` prepares a reproducible, opt-in Mac
test of journal restoration after an abrupt helper restart. Ordinary `check`
typechecks it with Swift 6 and warnings as errors; CodeQL's workflow builds it
for analysis. Neither path runs the observer or interrupts a service.

Use only an explicitly authorized test installation whose signatures and source
revision have already passed the appropriate artifact verifier. Keep the matching
app installed and open for restoration or cleanup. With the operator ready:

1. Enable the helper through the app's native setup. Start a bounded manual session
   with at least five minutes selected; verify active/disabled/owned status.
2. Run the observer as the normal console user from the repository:

   ```sh
   rtk proxy swift Tests/NativeMac/ObserveHelperRestart.swift --observe-armed-restart
   ```

3. Only after it prints `READY` with the current helper PID, the operator performs
   the authorized interruption in a separate Terminal, within 60 seconds:

   ```sh
   rtk proxy sudo /bin/launchctl kill SIGKILL system/io.github.leboonducoin.Limitless.helper
   ```

4. Keep the app open without rearming or starting another session until observation
   finishes. Afterwards use the normal guarded removal flow and verify allowed
   sleep, absent root paths and absent launchd job. If restoration is unconfirmed,
   use the app's restoration controls and preserve the journal and installed app.

The observer requires an active owned hold with at least two minutes remaining.
It obtains signed status before the interruption, then observes only the fixed
launchd job's PID and a strict Boolean IORegistry value while waiting. It requires
a replacement PID, allowed sleep for ten seconds, and final authenticated status
with zero sessions, automation off, no ownership and the latched `interrupted`
fault. It makes no activation, stop, installation or signal request. Its private
0600 JSON-lines trace records observations; unknown telemetry or timeout fails.
The timing window is not a hard real-time guarantee for native subprocess calls.
This gate is distinct from reboot, physical lid/source tests and proving that a
separate user workload continues after loss of the helper.

On 2026-09-17 this observer passed strict typechecking and both negative entry
checks: missing explicit option and unavailable helper each exited 1, before
creating a trace or changing an integration. The complete local `check` passed
92 tests, and actionlint/zizmor passed after the workflow edit. The live abrupt
restart **has not run**. Swift 6.4 rejects `AuthorizationExecuteWithPrivileges`
as unavailable; a read-only `sudo -n /usr/bin/id -u` check confirmed no existing
shell authorization. Operator coordination was requested. No private API,
alternate-language launcher or privilege-grant workaround was introduced.
Read-only accessibility inspection also confirmed full keyboard access and
event-posting permission enabled, with VoiceOver disabled; these settings alone
do not qualify keyboard event delivery or VoiceOver use.

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

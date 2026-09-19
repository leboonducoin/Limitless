# Changelog

## Unreleased — build 8 refinements

- Keep setup focused on administrator approval and independent launch at login.
- Count watched processes as tasks and retain their remaining PIDs during sessions.
- Restore the orange active dot to the right, make the author link blue and avoid
  redundant status-icon redraws and fractional panel resizing.
- Explain GitHub rate limits and defer retries; retain concrete network errors.
- Link CLI & AI help directly to agent skill installation instructions.
- Exit immediately after successful uninstall without a final confirmation dialog.

## Unreleased

Implemented work and validation are recorded below. No binary release has been
published; [testing evidence](docs/testing.md) and the
[acceptance matrix](docs/requirements.md) distinguish verified paths from open gates.

- Apply menu settings immediately, fit the panel to its content, put No limit only
  in the timing menu, and show the optional duration ceiling only in process mode.
- Follow multiple selected or semicolon-separated PIDs until all finish. Refresh
  the countdown every second, retain one Stop control and add an orange active dot.
- Add the GitHub footer link and opt-in signed GitHub updates with idle admission,
  bounded archive validation, same-certificate checks and replacement rollback.
- Show uninstall progress, bring errors forward and use Finder-style app recycling.
- Link Arthur Barreau's footer credit to his LinkedIn profile.

- Run Apple's caffeinate alongside the global sleep hold and verify the child's
  actual idle-sleep assertion on the existing two-second watchdog.
- Move all preferences into the menu-bar popover, shorten routine text, keep author
  and version in the footer, and add a native right-click Quit/Uninstall menu.
- Reduce presets to 15/30/45 minutes and 1/2/4/8/12/24 hours plus no limit; retain
  custom duration/date and add a searchable process picker alongside PID entry.
- Hide empty task counts outside process mode. Always erase user preferences,
  cache and saved window state after confirmed native removal.
- Keep GitHub Releases as the single installation route, with the menu-bar app
  and companion CLI in one archive. Remove the Homebrew template and generation.
  Retain optional Developer ID signing and notarization for later membership.

- Published the source and CI workflows on `main`, with a documented native preview,
  live workflow badges, architecture overview and contribution guides.
- Made the native installation error paths compile on the Xcode 26.2 CI baseline,
  preserving the system error and fallback without a `CocoaError` bridge cast.
- Preserved automatic XPC invalidation through a synchronous connection owner,
  avoiding a Swift 6.2 Release compiler cycle with isolated actor destruction;
  added a regression test for dropping an owner without explicit close.
- Qualified hosted builds, tests, ASan/TSan and security analysis; documented the
  Apple certificate-selector exception and enabled branch/check/alert protections
  with the maintainer's direct-push exception recorded in the security policy.
- Explicitly released the journal lock before closing its descriptor, so a
  temporary duplicate cannot keep a retired owner locked; added a deterministic
  regression for this failure observed under hosted TSan.

- Established Limitless's MIT attribution, contributor instructions, architecture,
  complete acceptance contract, and explicit validation/security boundaries.
- Deterministic Swift policy and session core, with exclusive power modes,
  validated battery floors, deadlines, ownership and automation revocation.
- Swift Testing coverage and a Swift maintenance tool for local validation.
- Pinned CI/security workflows for builds, sanitizers, CodeQL, secrets, dependency
  review, workflow lint and workflow security analysis.
- Observed-state controller with owned restoration, bounded recovery, fault latching
  and simulated failure coverage; isolated IOKit/pmset backend and continuous clock.
- Protected, durable ownership journal with exclusive locking and filesystem
  boundary tests, including ACLs and link attacks.
- Public IOPowerSources reader with conservative missing-data handling and an
  opt-in read-only Mac integration check.
- Swift helper and XPC client with separate app/task privileges, reciprocal code
  signature requirements, bounded messages, connection-owned leases and logout
  revocation. Local signed authentication and native registration have been exercised;
  complete release qualification remains open.
- Swift CLI for real foreground commands and identity-bound PID observation, with
  exclusive option parsing, owned completion and a distributable AI skill.
- Native SwiftUI menu-bar app, independent settings/login controls, original Swift
  icon artwork, observed-state presentation and read-only development previews.
- Swift development-bundle builder with shared icon export, bundled service/CLI/
  skill, ad-hoc signature validation and CI/CodeQL coverage of packaging tools.
- Application-only removal preparation with session revocation, confirmed-restoration
  gates, nonrecursive protected-state cleanup, native service unregistration and a
  signed app hook for packaging. Protocol version 3 separates acknowledged restoration
  from installed-file deletion and rejects earlier clients.
- Swift release commands for Developer ID signing, notarization, exported-archive
  verification and digest-backed release manifests; source metadata and
  matching CLI/bundle versions. No signed release or publication has been performed.
- Reciprocal XPC requirements now pin the executable's actual leaf certificate and
  exact peer identifiers, permitting a stable self-signed identity without Apple
  membership. Ad-hoc signatures remain rejected; eight signed XPC cases cover matching
  peers and refusal of mismatched certificate pins or identifiers.
- Guarded cleanup of SMJobBless-installed helper files after confirmed restoration,
  with certificate, path and filesystem checks, partial-failure retry and independent
  app absence checks. Local native inactive and active cleanup have passed.
- Native SMAppService and SMJobBless adapters with pre-consent signature/metadata
  validation, native administrator authorization and guarded service removal.
- Community bundle/sign/verify/package commands with embedded helper plists,
  exact certificate requirements, hardened runtime and actual archive digests.
  Ad-hoc metadata and both release rejection paths pass locally and are included in CI;
  locally signed community archives, native installation and a local Homebrew cask
  lifecycle passed. Stable publisher identity and clean-Mac distribution remain open.
- Asynchronous signing-identity validation keeps Security calls off the interface
  thread; startup controls remain disabled until validation completes.
- Full setup explanations and native process/date stop controls were inspected;
  complete keyboard/VoiceOver and physical hardware qualification remain open.
- Guarded absent-helper cleanup accepts an unregistered service only with independent
  job/file absence and an allowed sleep observation; repeated local removal passed.
- Opt-in Swift helper-restart observer and operator protocol, compiled by local checks
  and configured for CodeQL analysis. The actual abrupt restart remains unexecuted.

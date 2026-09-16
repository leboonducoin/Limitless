# Changelog

## Unreleased implementation

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
  revocation. Signed integration and registration remain release gates.
- Swift CLI for real foreground commands and identity-bound PID observation, with
  exclusive option parsing, owned completion and a distributable AI skill.
- Native SwiftUI menu-bar app, independent settings/login controls, original Swift
  icon artwork, observed-state presentation and read-only development previews.
- Swift development-bundle builder with shared icon export, bundled service/CLI/
  skill, ad-hoc signature validation and CI/CodeQL coverage of packaging tools.
- Application-only removal preparation with session revocation, confirmed-restoration
  gates, nonrecursive protected-state cleanup, native service unregistration and a
  signed app hook for packaging. Protocol version 2 rejects earlier clients.
- Swift release commands for Developer ID signing, notarization, exported-archive
  verification and digest-backed Homebrew cask generation; source metadata and
  matching CLI/bundle versions. No signed release or publication has been performed.
- Reciprocal XPC requirements now pin the executable's actual leaf certificate and
  exact peer identifiers, permitting a stable self-signed identity without Apple
  membership. Ad-hoc signatures remain rejected; no-account installation is pending.

## Unreleased

- Established Limitless's MIT attribution, contributor instructions, architecture,
  complete acceptance contract, and explicit validation/security boundaries.

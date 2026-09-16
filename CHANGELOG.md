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

## Unreleased

- Established Limitless's MIT attribution, contributor instructions, architecture,
  complete acceptance contract, and explicit validation/security boundaries.

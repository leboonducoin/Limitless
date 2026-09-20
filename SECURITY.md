# Security

Report vulnerabilities through [GitHub private vulnerability reporting](https://github.com/leboonducoin/Limitless/security/advisories/new),
not public issues. Do not include credentials or private task contents.
Limitless has no supported public binary release yet.

## Boundaries

- App and CLI are unprivileged. Native macOS consent installs a narrowly scoped helper.
- Both XPC directions pin the actual certificate and exact identifier; separate
  app/task listeners enforce privileges before allocating owners. Ad-hoc clients fail closed.
- Requests are validated regardless of signer. Tasks cannot configure policy,
  rearm recovery, remove another owner's session, or run a root command.
- Session ownership is tied to authenticated connections, console user and leases.
  Stop, expiry and owner loss outrank recovery. AI yields to manual sessions.
- Helper startup/user switch clears demands and authorization. The native app can
  reapply an explicitly saved CLI opt-in only while idle and fault-free. A fault
  clears that preference. No old demand is recreated.
- The only CLI-install path is a fixed symlink to the verified bundled executable.
  No arbitrary path is accepted, no foreign command overwritten.
- Agent hooks run as the user, consume only lifecycle identifiers and never read
  transcripts or save prompts. Provider event-delivery gaps are documented.
- Restoration is acknowledged before signature-checked native helper files are
  deleted. Failed cleanup retains ownership and a visible retry path.

Self-signed community certificates are supported; they do not claim Apple
notarization or Gatekeeper acceptance. No password storage, sudoers grant,
identifier-only authentication or automatic security bypass is permitted.
See [architecture](docs/architecture.md) and [distribution](docs/distribution.md).

The undocumented global lid setting has residual risks: competing privileged tools,
OS/helper failure, hardware incompatibility and delayed restoration. A readback
is not proof of physical operation or thermal safety.

## Supply chain

Pinned GitHub Actions run build/tests, ASan, TSan, CodeQL, workflow lint/security,
Gitleaks and PR dependency review. PR jobs receive no release signing secrets.
Verify archive SHA-256, source linkage and executable signatures separately from
notarization. Publication still needs explicit approval and the hardware matrix.

The public repository's secret scanning, push protection, private reporting,
Dependabot and branch/check rules were read back on 2026-09-18. Main's maintainer
bypass supports the approved direct-push workflow; it is not a binary-release gate.
Current execution results belong in [testing](docs/testing.md).

## Reviewed compatibility exception

[CodeQL alert 1](https://github.com/leboonducoin/Limitless/security/code-scanning/1)
was reviewed and dismissed as won't fix on 2026-09-18. Apple requires a SHA-1
fingerprint for its `certificate leaf = H"…"` selector. It identifies a public
certificate; it does not hash passwords, keys or release archives. Native signature
validation and exact peer IDs remain mandatory; archive integrity uses SHA-256.

The query remains enabled, with no broad suppression. Reassess if Apple supports a
stronger selector or the data flow changes.
[Apple requirement language](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html).

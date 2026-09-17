# Security policy

Limitless is in development. There is no supported public release yet. Do not
install development privileged helpers on a machine you cannot recover safely.

Report vulnerabilities through [GitHub private vulnerability reporting](https://github.com/leboonducoin/Limitless/security/advisories/new).
It was verified enabled on 2026-09-16; recheck availability before release. Do not post
credentials, exploit details or private command arguments in public issues.

## Required boundaries

The app and CLI are unprivileged. A signed, user-approved helper applies a narrow
power-management operation through authenticated XPC. It must never accept arbitrary
commands or paths, store administrator passwords, or install sudoers permissions.
Client input is untrusted, including signed CLI input. Limits are enforced by the
helper. Signing identity alone does not prove that an AI agent has user permission.

Separate app/task endpoints enforce different privileges. Both directions pin the
current executable's validated leaf certificate and exact peer identifiers using
the public XPC code-signing requirement API. A self-signed certificate is accepted;
ad-hoc signatures have no certificate. The helper binds owners to connections and to the
current console UID. Automation starts disabled after service startup or user
switch; a task cannot configure policy, rearm recovery or release another owner.
Ad-hoc builds fail closed. No test-only authentication bypass is shipped.

The stable certificate pin replaces the earlier Apple-only Team ID boundary.
Certificate selection uses the SHA-1 fingerprint mandated by Apple's requirement
language, not an archive integrity digest. The release verifier also requires the
same actual certificate bytes on all three executables. A local signed probe
verifies cross-process authentication and rejects mismatched pins/identifiers in
both directions. Native installation and the privileged lifecycle without Apple
membership still require qualification.
This identity does not establish Apple notarization. No identifier-only acceptance
or automatic Gatekeeper exception is authorized by the no-account requirement.

Community bundles use public deprecated SMJobBless/SMJobRemove with native
Authorization Services. Both peers' exact certificate requirements and helper
metadata are checked before consent. The authorization reference is destroyed
after each operation; no password is read or stored. A loaded installation must
be drained and removed through the matching app before an upgrade or channel
change. The embedded development requirements authorize nobody. Native consent
and a real certificate-signed lifecycle remain qualification gates.

Removal is application-only and first revokes all demands. A protected ownership
record is never deleted to bypass a failed restoration. Journal cleanup refuses
unknown contents and replaced directories/locks, uses no recursive deletion, and
retires the writer. Service unregistration and final absence checks must succeed
before a packaging hook reports success. The unprivileged CLI cannot request removal.

The lid-closed mechanism uses an undocumented global OS setting. A successful read
does not establish hardware compatibility, continued execution, or thermal safety.
Another privileged tool can change the same state. Helper or OS failure may prevent
timely cleanup. Ownership checks, bounded recovery and explicit reporting are required;
"always safe" and "never drains the battery" are not acceptable claims.

The final signed helper, XPC authentication, recovery, installation and uninstall
paths require a dedicated security review before release. See
[requirements.md](docs/requirements.md) for acceptance evidence.

## Supply chain

Use pinned tools/actions, minimal workflow permissions, no release secrets on PR
jobs, and a protected publication environment. Secret detection, CodeQL, workflow
analysis and dependency review are release gates. Verify signatures, checksums,
source provenance and, for the Developer ID channel, notarization separately.
The community channel must explicitly identify itself as not notarized.
Never bypass a security control.

Read-only GitHub inspection on 2026-09-16 confirmed a public repository with private
vulnerability reporting, secret scanning, secret push protection and Dependabot
security updates enabled. The `main` branch had neither classic protection nor
applicable ruleset rules. Required CI/security checks and protected release controls
must be configured before publication; no remote settings were changed by this
inspection. Reverify these settings rather than relying on this dated snapshot.

# Security policy

Limitless is in development. There is no supported public release yet. Do not
install development privileged helpers on a machine you cannot recover safely.

Report vulnerabilities using GitHub private vulnerability reporting **when enabled**.
A private reporting channel must be verified before public release. Do not post
credentials, exploit details or private command arguments in public issues.

## Required boundaries

The app and CLI are unprivileged. A signed, user-approved helper applies a narrow
power-management operation through authenticated XPC. It must never accept arbitrary
commands or paths, store administrator passwords, or install sudoers permissions.
Client input is untrusted, including signed CLI input. Limits are enforced by the
helper. Signing identity alone does not prove that an AI agent has user permission.

Separate app/task endpoints enforce different privileges. Both directions pin an
Apple-backed signing team and exact executable identifier using the public XPC
code-signing requirement API. The helper binds owners to connections and to the
current console UID. Automation starts disabled after service startup or user
switch; a task cannot configure policy, rearm recovery or release another owner.
Ad-hoc builds fail closed. No test-only authentication bypass is shipped.

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
analysis and dependency review are release gates. Verify signatures, notarization,
checksums and source provenance separately. Never bypass a security control.

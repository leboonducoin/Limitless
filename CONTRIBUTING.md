# Contributing

Read [AGENTS.md](AGENTS.md), [the requirements](docs/requirements.md), and the
canonical document for the area you change. Limitless is entirely Swift and targets
native macOS. Keep changes focused, dependencies justified, and security boundaries
explicit. All contributions are made under the [MIT license](LICENSE).

The current minimum is macOS 26 on Apple Silicon with Swift 6 language mode.
There are no Swift package dependencies. A paid Apple Developer account is not
required to work on the project or its community distribution channel. Native
authorization, reciprocal certificate checks and user limits must remain intact.
See [distribution](docs/distribution.md) before changing installation or signing.

## Working locally

Use RTK for terminal work (`rtk proxy` supports commands without a dedicated wrapper).
Use the existing Git identity and Conventional Commits, for example
`feat(core): enforce battery and source limits`. Do not add automated attribution.
Preserve unrelated edits and commit only reviewed intended paths.

Start with `rtk git status` and use a `feature/` branch for new work. Agent
contributors read installed skills from their global locations as directed by
AGENTS.md; do not copy skill installations or another project's data into Limitless.

The core owns policy and session decisions; the app and CLI present or request
those decisions. Keep OS behavior in `LimitlessSystem` and helper privileges in
the helper. Prefer native APIs and concrete types. Any new dependency or shared
abstraction should solve a demonstrated need.

```sh
rtk proxy env LIMITLESS_BUILD_PATH=/private/tmp/limitless-build swift Tools/ProjectTool.swift check
rtk proxy env LIMITLESS_BUILD_PATH=/private/tmp/limitless-asan swift Tools/ProjectTool.swift asan
rtk proxy env LIMITLESS_BUILD_PATH=/private/tmp/limitless-tsan swift Tools/ProjectTool.swift tsan
```

`check` validates formatting, builds Release, runs tests with coverage data, and
checks release inputs and the Homebrew DSL. Sanitizers use separate scratch paths.
See [testing](docs/testing.md) for the CLT macro workaround and optional read-only
hardware check. The normal suite must not alter host power settings or install a
service. Development bundles are for inspection and reject privileged controls.

## Reviewing a change

Add meaningful behavior tests and update documentation in the same change. Run the
checks in [testing.md](docs/testing.md). Include the actual validation performed and
any gaps in a pull request; do not equate simulations with hardware qualification.

Explain the concrete problem, resulting behavior and validation. Reference the
affected requirement from [the acceptance matrix](docs/requirements.md) when
changing product behavior. Report skipped or unavailable gates explicitly, and
include native visual/accessibility evidence for interface changes. Documentation
changes need accurate commands, links and claims; do not add implementation-mirroring
tests for prose. Workflow changes require actionlint and zizmor; staged changes
and history are scanned with Gitleaks. Do not label unexecuted GitHub checks as passed.

The [pull request template](.github/pull_request_template.md) keeps this evidence
with the change. Issue forms request reproducible behavior and minimal environment
information. Their GitHub rendering is only verifiable after an authorized push.

## Security and publication

Never commit credentials or signing material. Never include private command contents
in bug reports. Security reports belong in a private channel, not public issues.
Publishing, pushing, privileged installation and power-setting tests require the
corresponding explicit authorization.
Keep signing keys and credentials outside Git. A release needs the full security
checks, source/artifact linkage and physical acceptance evidence, even when it uses
the community signing channel. A passing local build is not publication approval.

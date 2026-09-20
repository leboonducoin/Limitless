# Contributing

Limitless is native Swift for macOS 26+ on Apple Silicon. Contributions use the
[MIT license](LICENSE). Read [AGENTS.md](AGENTS.md), the
[requirements](docs/requirements.md), and the document for the area you change.

Keep changes focused. Reuse the shared core for policy; keep platform code in
LimitlessSystem and privileged operations in the helper. Prefer Apple APIs and
the standard library. No Node/Python product runtime or dependency without a need.

Start with `git status`, preserve unrelated edits, and use a `feature/` branch.
Commit only intended paths with Conventional Commits and the existing Git identity.

```sh
env LIMITLESS_BUILD_PATH=/private/tmp/limitless-build swift Tools/ProjectTool.swift check
env LIMITLESS_BUILD_PATH=/private/tmp/limitless-asan swift Tools/ProjectTool.swift asan
env LIMITLESS_BUILD_PATH=/private/tmp/limitless-tsan swift Tools/ProjectTool.swift tsan
```

Add meaningful regression tests and update the nearest document. Include what
changed, what you tested and any gaps in the PR. UI changes need native inspection
and accessibility checks; simulations do not establish lid-closed compatibility.
See [testing](docs/testing.md) for security gates and optional Mac probes.

Never commit secrets or private task contents. Keep certificate checks, native
administrator consent and user limits intact. Signing, installation, power tests
and publication each require authorization. A passing build is not a release.

[Report vulnerabilities privately](https://github.com/leboonducoin/Limitless/security/advisories/new).
Please follow the [code of conduct](CODE_OF_CONDUCT.md).

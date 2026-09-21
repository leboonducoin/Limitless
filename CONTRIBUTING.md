# Contributing

Bug reports, small fixes and ideas are welcome. For a larger change, open an issue first.

Use a Mac with Xcode 26.2 or later. Fork the repo, make a branch,
then run:

```sh
swift Tools/ProjectTool.swift check
```

Keep the change focused. Add a test for changed behavior, update the relevant
doc and explain the result in your pull request. For UI changes, include a native
screenshot and check keyboard access.

Use Swift and Apple APIs. Preserve administrator consent, signature checks and
user limits. Support macOS 14+, Intel and Apple Silicon. Never include credentials
or private task contents.

[Architecture](docs/architecture.md) · [Testing](docs/testing.md) ·
[Distribution](docs/distribution.md) · [Code of conduct](CODE_OF_CONDUCT.md)

Contributions use the [MIT license](LICENSE).
[Report security issues privately](https://github.com/leboonducoin/Limitless/security/advisories/new).

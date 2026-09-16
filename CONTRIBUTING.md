# Contributing

Read [AGENTS.md](AGENTS.md), [the requirements](docs/requirements.md), and the
canonical document for the area you change. Limitless is entirely Swift and targets
native macOS. Keep changes focused, dependencies justified, and security boundaries
explicit. All contributions are made under the [MIT license](LICENSE).

Use RTK for terminal work (`rtk proxy` supports commands without a dedicated wrapper).
Use the existing Git identity and Conventional Commits, for example
`feat(core): enforce battery and source limits`. Do not add automated attribution.
Preserve unrelated edits and commit only reviewed intended paths.

Add meaningful behavior tests and update documentation in the same change. Run the
checks in [testing.md](docs/testing.md). Include the actual validation performed and
any gaps in a pull request; do not equate simulations with hardware qualification.

Never commit credentials or signing material. Never include private command contents
in bug reports. Security reports belong in a private channel, not public issues.
Publishing, pushing, privileged installation and power-setting tests require the
corresponding explicit authorization.

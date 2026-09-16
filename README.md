# Limitless

A native macOS menu-bar app for explicit, observable keep-awake sessions.

By **Arthur Barreau**. [MIT](LICENSE), copyright © 2026 Arthur Barreau.

**In development — not yet a published or hardware-qualified application.**
The intended first release targets macOS 26 and Apple Silicon. No installer,
download, notarization or closed-lid compatibility claim is available yet.

Limitless is an independent Swift implementation inspired by
[Sleepless](https://github.com/Aboudjem/Sleepless), not a renamed copy. It will use
Apple APIs for ordinary power management and isolate the undocumented global
`pmset disablesleep` mechanism needed for supported lid-closed operation.

The product includes battery/AC modes, battery protection, timed and task-bound
sessions, native login support, a Swift CLI, an AI skill, and a narrowly scoped
privileged helper. Distribution is planned through GitHub and Homebrew.
No Node or Python runtime will be required to use it. A distribution usable without
paid Apple Developer membership is required; notarization will be an optional later
channel. Certificate-based helper authentication is implemented; the installation
flow without membership still needs implementation and real-Mac qualification.
See the [distribution decision](docs/distribution.md#distribution-without-apple-developer-membership).

## Development

The implemented components include the Swift policy/session core, power adapters,
protected ownership journal, authenticated helper, command/process CLI and native
menu-bar interface. The interface has read-only development previews; installation,
signed integration and physical qualification remain open.
Build and test with Xcode 26.2 or newer using
`rtk proxy swift Tools/ProjectTool.swift check`.
See [testing](docs/testing.md) for sanitizer commands and the CLT/synced-folder
notes. There are no Swift package dependencies.

## Project documentation

- [Requirements and acceptance tracking](docs/requirements.md)
- [Architecture and behavior](docs/architecture.md)
- [CLI and AI integration](docs/cli.md)
- [Native interface contract](docs/design.md)
- [Build, installation and removal](docs/distribution.md)
- [Security policy](SECURITY.md)
- [Testing and evidence](docs/testing.md)
- [Contributing](CONTRIBUTING.md)
- [Agent instructions](AGENTS.md)

## Safety boundary

Lid-closed support depends on the Mac and macOS version. Reading a power flag is
not proof of physical operation. Limitless must not claim that an unverified
change succeeded, and an automatic stop permits normal sleep rather than forcing
sleep or terminating a running task. Do not run privileged experiments without
reviewing their restoration procedure.

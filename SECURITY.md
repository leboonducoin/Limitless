# Security

Found a vulnerability? [Report it privately on GitHub](https://github.com/leboonducoin/Limitless/security/advisories/new).
Include the app version, macOS version and steps to reproduce it. Leave out
passwords, keys and private task contents. Use public issues for ordinary bugs.

Limitless asks macOS for administrator approval to manage sleep. It never stores
your password. Terminal commands and AI tasks run with your normal permissions.
Tasks cannot override your limits or take over a manual session.

There is no analytics or task-content collection. Update requests go to GitHub;
downloaded apps must pass integrity and publisher-signature checks. macOS opening
approvals remain in place, including for non-notarized builds.

Updates are installed only while idle. Uninstall restores sleep before removing
the helper. If restoration fails, the app keeps the information needed to retry.

Technical details: [architecture](docs/architecture.md),
[distribution](docs/distribution.md) and [automated checks](docs/testing.md).

# Security

Found a vulnerability? [Report it privately on GitHub](https://github.com/leboonducoin/Limitless/security/advisories/new).
Include the app version, macOS version and steps to reproduce it. Leave out
passwords, keys and private task contents. Use public issues for ordinary bugs.

Limitless asks macOS for administrator approval to manage sleep. It never stores
the administrator password. Terminal commands and AI tasks run with your normal permissions.
Tasks cannot override your limits or take over a manual session.

Touch ID for sudo is a separate, optional Mac-wide setting. It keeps password
fallback and never grants sudo rights to users who do not already have them.

There is no analytics or task-content collection. Update requests go to GitHub;
downloaded apps must pass integrity and publisher-signature checks. macOS opening
approvals remain in place.

The optional iPhone hotspot stores the network name, access point identifier,
password and join preference in the local Keychain. The menu app requests Location
Services to read the Wi-Fi identifiers. None of this data appears in diagnostics.

Updates are installed only while idle. Uninstall restores sleep before removing
the helper. If restoration fails, the app keeps the information needed to retry.

Technical details: [architecture](docs/architecture.md),
[distribution](docs/distribution.md) and [automated checks](docs/testing.md).

CI checks Swift and workflows with CodeQL, scans the full Git history for secrets
and reviews dependency changes. New CodeQL security alerts require review before merging.

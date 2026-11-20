# Compatibility and validation

The universal app targets macOS 14 or later on Intel and Apple Silicon. This
table records the scope of each check separately from that target.

| Environment | Evidence | Scope |
| --- | --- | --- |
| MacBook Pro (MacBookPro18,3), macOS 27.2.1, Xcode 27.2 | Local Swift tests and inert native preview | Session policy, simulated audio and network workflows, Options and keyboard navigation |
| GitHub-hosted macOS 14 | [Compatibility job](../.github/workflows/ci.yml) | Runs the shipped CLI on the oldest supported OS |
| GitHub-hosted macOS 15 Intel | [Compatibility job](../.github/workflows/ci.yml) | Runs the full repository checks on Intel |
| Physical laptop matrix for the next release | Pending | Authenticated helper, lid closed with and without an external display, audio restoration, notifications and iPhone hotspot |

Check the CI and Security gates for the release's exact commit. Record hardware
model, macOS build, source revision, power source and display configuration for
each physical trial. Record whether Limitless restored its owned sleep state
and whether macOS actually entered sleep as separate observations.
[Physical trial procedure](testing.md#test-the-installed-app).

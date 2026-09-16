---
name: limitless
description: Keep an authorized macOS task awake with Limitless while its real command or process is running. Use for long builds, tests, exports, or explicitly tracked local work; not for idle chat or unobservable agent activity.
---

# Limitless

Use the installed, signed Swift `limitless` CLI. The native app must already have
approved its helper and enabled automation. This skill does not authorize changing
those settings, installing software, or weakening the user's limits.

Read `limitless --help` and `limitless status --json` before the first tracked task
in a session. Follow any terminal-wrapper convention required by the workspace.
If the CLI is unavailable, incompatible, blocked, or automation is disabled,
explain the missing prerequisite. Continue independently useful work within the
user's instructions; never substitute `sudo`, `pmset`, `caffeinate`, a dummy
`sleep`, or a security bypass to simulate successful Limitless integration.

Wrap the actual foreground command:

```sh
limitless run -- swift test
limitless run -c --for 2h -- xcodebuild -scheme MyApp build
```

Omit options to inherit the app's limits. `-b`, `-c`, `-a` are mutually exclusive;
they can only narrow the allowed power sources. A requested battery floor must be
at least the app's floor. Never select 0%, extend an authorized duration, change
the system clock, rearm a stopped session, or reconnect to evade a cutoff.

For an already running, specifically identified user task, use
`limitless watch --pid PID`. Confirm that the PID belongs to the requested work.
Limitless binds it to its start time and ends protection if it exits, changes
identity or becomes unreadable. Do not watch Codex, a terminal, an editor, a
browser, a shell waiting for input, or an agent host as a proxy for actual work.

Keep the tool's execution session attached and await its real result. Do not
background or detach the wrapper. For parallel commands, wrap each actual command
independently and wait for every result. Each completion releases only its own
demand; protection ends after the last eligible task finishes unless the user
also has an independent manual session in the app.

Cancellation must reach the wrapper (Ctrl-C/SIGINT or SIGTERM). `run` forwards the
signal to its command; `watch` only stops watching. A timer, battery cutoff or
connection failure ends protection without killing the user's work. Report that
distinction and do not silently restart protection. Child processes deliberately
detached by a command are outside that command's completion boundary.

Do not claim to follow model thinking, a remote job without a locally observable
lifecycle, or all future agent activity. Use the original command's result to
report task completion; use Limitless's observed status to report protection.
Never log or send command contents, credentials or arguments to the helper.

The repository's development builds are not yet a signed public distribution.
An ad-hoc build refusing the privileged channel is expected, not a reason to
weaken authentication. Signed XPC and physical lid operation require separate
release qualification.

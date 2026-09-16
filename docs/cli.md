# Command-line and AI integration

The Swift `limitless` executable implements the commands below. The current
development build is not signed with a release identity and intentionally refuses
privileged communication. A signed app/helper installation and app-authorized
automation are prerequisites for real keep-awake sessions.

```sh
limitless status
limitless status --json
limitless run -- swift test
limitless run -c --for 90m -- xcodebuild -scheme MyApp build
limitless watch -b --battery-floor 30 --pid 12345
limitless run --until 2026-10-01T18:00:00+02:00 -- my-command
```

`-b`, `-c`, and `-a` select battery, AC, or both. Supplying more than one is an
error, including repeated flags. Omitting the mode inherits the app policy.
`--battery-floor` accepts every integer 0–50. The helper rejects values below the
user's floor; an effective floor of 0 prints a warning.

Choose at most one of `--for`, `--until`, or `--unlimited`. The default is unlimited
for the tracked work, still bounded by user policy and its actual completion.
Durations use a positive number followed by `s`, `m`, `h`, or `d`; fractional values
are allowed. There is no arbitrary duration maximum. Nonfinite, invalid or
unrepresentable deadlines are rejected. Absolute dates include a timezone and
must be in the future when the helper admits them.

`run` requires `--` before the executable and passes arguments as an array through
the user's `/usr/bin/env`, without a shell. Standard input/output/error and the
working directory are inherited. The helper receives no command or arguments.
The command is launched only after its session is accepted. An accepted but
power-suspended session prints its condition; the command still runs under that
policy. Normal completion returns the command's exit code; signal termination
uses `128 + signal`. Usage errors return 64; unavailable/refused service returns 69.

`watch` observes an existing process owned by the current user. It binds PID,
owner and start timestamp, rejects PID 0/1 and itself, and treats a zombie,
unreadable process or changed identity as ended. It checks at one-second intervals
and never signals the observed process. It does not guess work from CPU usage or
follow an agent's entire lifetime.

Both commands retain one authenticated connection and renew its liveness every
five seconds while the work exists. A 30-second helper lease covers a lost owner;
normal connection invalidation releases it immediately. Expiry, cutoff or loss
of service ends protection without restarting it and without killing the command.
The CLI reports that distinction on standard error. Ctrl-C/SIGTERM releases its
session; `run` also forwards the corresponding signal via Foundation `Process`.
On normal completion it requests an explicit release and reports an unconfirmed
restoration on standard error, while preserving the command's exit code.
Process descendants deliberately detached from the foreground command are outside
the tracked completion boundary. A stopped/suspended process still exists until
it exits; Limitless makes no claim that it is making progress.

Concurrent wrappers own separate sessions. Completing one cannot stop another.
The last eligible task releases the automatic hold, while a user-created manual
session remains independent. Global stop and policy/recovery controls are app-only.

The distributable [AI skill](../skills/limitless/SKILL.md) uses these exact commands.
It adds no runtime or adapter script. Copy its `limitless` folder into the agent's
skill directory only when installation is requested; repository development does
not modify the user's installed skills. Its operational rules prohibit dummy work,
watching the agent host, detached wrappers and attempts to evade user cutoffs.

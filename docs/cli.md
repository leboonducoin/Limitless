# Command-line and AI integration

The Swift `limitless` executable implements the commands below. Ad-hoc development
builds intentionally refuse privileged communication. A certificate-signed app/helper
installation and app-authorized automation are prerequisites for real keep-awake
sessions; the community channel does not require paid Apple Developer membership.
The local signed test build has passed native task/limit trials, as recorded in
[testing evidence](testing.md#live-task-limits-and-idle-observation). Downloaded
GitHub distribution remains unqualified. The CLI is included inside the graphical
app at `/Applications/Limitless.app/Contents/MacOS/limitless`; it is not a separate
installation. The examples below use its full path, with no shell setup required.

```sh
/Applications/Limitless.app/Contents/MacOS/limitless status
/Applications/Limitless.app/Contents/MacOS/limitless status --json
/Applications/Limitless.app/Contents/MacOS/limitless run -- swift test
/Applications/Limitless.app/Contents/MacOS/limitless run -c --for 90m -- xcodebuild -scheme MyApp build
/Applications/Limitless.app/Contents/MacOS/limitless watch -b --battery-floor 30 --pid 12345
/Applications/Limitless.app/Contents/MacOS/limitless run --until 2026-10-01T18:00:00+02:00 -- my-command
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

## AI agent setup

1. Open Limitless, complete **Enable Limitless** through macOS, then turn on
   **Allow CLI & AI tasks**. The adjacent question-mark button opens this guide.
2. In Finder, right-click `Limitless.app`, choose **Show Package Contents**, then
   open `Contents/Resources`. Copy the **limitless-skill** folder to one of the
   locations below and rename the copied folder **limitless**. Create the parent
   folders if needed; Finder's **Go → Go to Folder…** accepts `~` paths.
3. Start a new local agent session and ask: “Use the Limitless skill while running
   this build.” The skill must appear in the agent's available skills first.

| Agent | Personal installation (all local projects) | Project-only alternative |
| --- | --- | --- |
| [Codex](https://developers.openai.com/codex/skills) | `~/.agents/skills/limitless/SKILL.md` | `.agents/skills/limitless/SKILL.md` |
| [Claude Code](https://code.claude.com/docs/en/skills) | `~/.claude/skills/limitless/SKILL.md` | `.claude/skills/limitless/SKILL.md` |
| [Cursor](https://cursor.com/help/customization/skills) | `~/.cursor/skills/limitless/SKILL.md` | `.cursor/skills/limitless/SKILL.md` |
| [Gemini CLI](https://geminicli.com/docs/cli/skills/) | `~/.gemini/skills/limitless/SKILL.md` | `.gemini/skills/limitless/SKILL.md` |

Choose one location for each agent; avoid duplicate copies. Codex also supports
explicit invocation with `$limitless`; Claude Code uses `/limitless`. In Gemini CLI,
run `/skills reload`, check `/skills list`, then ask it to use Limitless and review
its normal skill-activation consent. This applies to Gemini CLI running on your Mac,
not the Gemini website.
The source copy is [here](../skills/limitless/SKILL.md). No extra runtime, adapter,
administrator permission or paid developer account is needed to copy the skill.

The agent runs the CLI on **this Mac**, around real commands such as builds, tests
or exports. Each completed command releases its own session; the last tracked task
ends protection unless a separate manual session remains. User power, battery and
duration limits always apply. Chat/model thinking and remote/cloud jobs without a
local process are not tracked; keeping an idle agent host open is not a task.

If setup fails, check the full-path `status --json` command above, helper approval
and **Allow CLI & AI tasks**. A blocked or ad-hoc build must not bypass macOS security.
The skill forbids dummy work, detached wrappers and attempts to evade user cutoffs.
Skill installation is deliberate: Limitless does not modify agent directories.
To remove a copied skill later, delete only its `limitless` folder in the location
you chose. Uninstalling the app removes its bundled original.

### Other AI tools — manual installation

For another **local** agent with skill support, copy the same `limitless/SKILL.md`
into its documented personal or project skill folder. Keep the YAML header and
instructions intact, reload its skills, and confirm Limitless appears before asking
it to use the skill. There is no universal installation path or slash command.

If the tool has no skill loader but can read files and run local commands, keep the
file in a folder you choose and explicitly ask: “Read this Limitless SKILL.md and
follow it for this task.” Attach or reference that exact file using the tool's
normal context mechanism. This is manual use; Limitless does not claim automatic
discovery or ongoing monitoring between requests.

If the tool cannot execute commands on this Mac, run the CLI around the real command
yourself using the examples above, or select its actual local process in Limitless.
A browser-only AI cannot install this integration or keep your Mac awake remotely.

# CLI and AI

Move Limitless to **Applications**, enable its helper, then turn on **Allow CLI & AI
tasks**. The app installs `/usr/local/bin/limitless` automatically. No shell setup
is needed with the standard macOS PATH. An existing different command is left alone.
For a custom PATH, use `/Applications/Limitless.app/Contents/MacOS/limitless`.

## Commands

```sh
limitless run -- swift test
limitless run -a --battery-floor 20 --for 2h -- make
limitless watch --pid 12345
limitless status --json
```

| Option | Meaning |
| --- | --- |
| `-b`, `-c`, `-a` | Battery, adapter, or both; choose one |
| `--battery-floor 20` | 0–50%; zero disables custom protection |
| `--for 90m` | Duration in seconds, minutes, hours or days (`s`, `m`, `h`, `d`) |
| `--until 2026-10-01T18:00:00+02:00` | Date and time, including timezone |
| `--unlimited` | No command duration limit; the default |

Omitted limits inherit the app's policy. Requests cannot weaken it. `run` preserves
the command's output and exit code; Ctrl-C interrupts it. `watch` observes a PID and
its start time, without signalling it. Each completion releases only its own hold.
A battery cutoff, timer or lost connection ends protection without killing the
work or automatically restarting protection.

## AI agent setup

The integration follows **the whole task**, including thinking between commands.
It requests both sources and a 20% floor, subject to stricter app limits. Concurrent
tasks release their holds independently. A manual Keep awake session takes priority:
the AI neither changes it nor adds time after it ends.

There are two parts: the skill tells the agent how to behave; **lifecycle hooks**
tell Limitless exactly when work starts and ends. Copying only the skill is not
enough. The app bundles both in `Contents/Resources/limitless-skill`.

Copy that folder to the skill location below. Merge the supplied hook entries into
your existing configuration—do not overwrite other settings. Restart the agent
and approve hooks through its normal trust flow. Limitless does not edit these
files for you.

| Agent | Personal skill folder | Hook configuration |
| --- | --- | --- |
| **Codex** | `~/.agents/skills/limitless` | Merge [codex.json](../skills/limitless/hooks/codex.json) into `~/.codex/hooks.json` |
| **Claude Code** | `~/.claude/skills/limitless` | Merge [claude.json](../skills/limitless/hooks/claude.json) into `~/.claude/settings.json` |
| **Cursor** | `~/.cursor/skills/limitless` | Merge [cursor.json](../skills/limitless/hooks/cursor.json) into `~/.cursor/hooks.json` |
| **Gemini CLI** | `~/.gemini/skills/limitless` | Merge [gemini.json](../skills/limitless/hooks/gemini.json) into `~/.gemini/settings.json` |
| **Other** | Your agent's documented skill folder | Connect its task events as described below |

Try a short task, then check that the task count rises and returns to zero. Repeat
with cancellation and two concurrent tasks before relying on unattended use.
These integrations run locally on the Mac; cloud agents cannot control it.

Codex provides turn completion and interruption events. Claude and Gemini's
documented end events do not cover every cancellation path: if a version omits an
end event while remaining open, use **Stop** in Limitless. Exiting the host also
ends its holds. Hooks follow conversation turns; delegated work is covered while
the parent waits for it. Work detached beyond a turn needs its own lifecycle.
Never treat an open agent window as ongoing work.

Hook formats: [Codex](https://developers.openai.com/codex/hooks),
[Claude](https://code.claude.com/docs/en/hooks),
[Cursor](https://cursor.com/docs/hooks),
[Gemini](https://geminicli.com/docs/hooks/reference/).

### Other AI tools (manual installation)

Copy [the skill](../skills/limitless/SKILL.md) into your local agent's skill folder,
then connect its real start, completion **and cancellation** events to
`limitless hook other`. Send JSON on stdin:

```json
{"hook_event_name":"Begin","session_id":"conversation-123","turn_id":"task-456"}
```

Use `End` with the same IDs when that task finishes or is cancelled. Use `SessionEnd`
with its `session_id` when closing the conversation. IDs must be unique to the real
task; do not create new ones to evade Stop or a battery/time limit. If the tool has
no lifecycle events, use `limitless run -- actual-command` for command-only coverage.

Hooks read only lifecycle IDs, keep hashed temporary markers in the app's cache,
and never read transcripts or save prompts. Uninstall removes that cache. To
remove the integration, remove its hook entries and the copied skill folder.

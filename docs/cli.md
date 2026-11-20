# CLI & AI

Move Limitless to Applications and enable **Allow CLI & AI tasks** under **Options**.
Approve the macOS prompt. A protected system installation exposes `limitless`
directly. If the app or command directories are writable by a local account,
Limitless installs a verified private copy for your account. Use its path in the
commands below or define an alias for this shell:

```sh
alias limitless='"$HOME/Library/Application Support/Limitless CLI/Limitless.app/Contents/MacOS/limitless"'
```

Enable **Allow CLI & AI tasks** again after a helper restart, including after
reboot or an update, or after changing console accounts. Your saved power
limits remain in effect.

Run setup again for each previously configured agent before using its old
hooks. Explicit setup migrates Limitless entries to the protected command and
keeps other settings. Closing your agents during migration prevents them from
running a legacy hook.

After an upgrade from 1.1 or earlier, close any agents first. If **Migrate
CLI & agent hooks…** appears in **Options**, use it to retire the unsafe
shared shortcut and migrate Limitless hooks for the current account.
Repeat this in each account that uses a Limitless integration.

## Terminal

```sh
limitless run -- swift test
limitless watch --pid 12345
limitless status
limitless doctor
limitless --help
```

`run` follows a command; `watch` follows an existing process. Both release their
session when the work ends. Your command keeps its output and exit code.

| Option | Meaning |
| --- | --- |
| `-b`, `-c`, `-a` | Battery, power adapter, both |
| `--battery-floor 20` | Reserve 0–80% battery; 0 disables protection |
| `--for 2h` | Duration: seconds, minutes, hours or days |
| `--until 2026-10-01T18:00:00+02:00` | Date with timezone |
| `--unlimited` | No duration limit; still ends with the task |

Choose one power mode and one stop condition. App limits always apply.
Reaching a limit ends protection, not your command. `status --json` is available.
`doctor` reads the authenticated helper and reports the OS and protocol version,
observed power state, last stop reason and any fault. It omits paths, session
identifiers, command arguments and hotspot credentials.

## AI agent setup

Close your agent, then run its command once:

| Agent | Install |
| --- | --- |
| **Codex** | `limitless setup codex` |
| **Claude Code** | `limitless setup claude` |
| **Cursor** | `limitless setup cursor` |
| **Gemini CLI** | `limitless setup gemini` |
| **Other** | [Manual connection below](#other) |

Restart the agent and accept its normal hook approval if asked. Setup installs
the skill and task hooks together. Existing settings are kept, with a private
`.limitless-backup-*` copy beside the settings file. Invalid or linked files are
left untouched, as are files with an ACL and directories writable by another user.
Setup also stops if a configuration directory is replaced while the change is in
progress. A failed setup or removal restores the previous settings and skill files.
Custom configuration locations need manual setup.
`limitless setup codex --check` (or another supported provider) compares the
installed skill and hook entries to the bundled version without changing them.

During a task, Limitless uses the app's power sources and **at least a 20% battery reserve**,
including while the agent thinks. Stricter app limits still apply. The last task
to finish releases the hold. A manual **Keep awake** session always takes priority.

To remove an integration: `limitless setup codex --remove` (replace the agent name).
App uninstall also removes integrations installed this way. Backups are retained
for recovery; other settings and hooks are preserved. A failed removal is rolled back
so a retry starts from the prior complete installation.

Limitless's menu displays the providers and task count using the helper's
authenticated session summaries. These integrations need a local agent with lifecycle hooks. If your agent misses
a cancellation event, click **Stop** in Limitless; exiting the agent also releases
its holds. Work detached beyond a turn needs its own task tracking.

### Other

Copy [SKILL.md](../skills/limitless/SKILL.md) into your agent’s skill folder.
Connect its real task start, finish and cancellation events to `limitless hook other`.
Pass this JSON on standard input:

```json
{"hook_event_name":"Begin","session_id":"conversation-123","turn_id":"task-456"}
```

Send `End` with the same IDs on completion or cancellation; `SessionEnd` with the
session ID when closing the conversation. Without task events, use `limitless run`
for individual commands. An open agent window is not an active task.

Hook references: [Codex](https://developers.openai.com/codex/hooks),
[Claude](https://code.claude.com/docs/en/hooks), [Cursor](https://cursor.com/docs/hooks),
[Gemini](https://geminicli.com/docs/hooks/reference/).

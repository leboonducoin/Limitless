---
name: limitless
description: Keep this Mac awake for the whole agent task with Limitless, including thinking between commands. Use when the user asks for Limitless during agent work.
---

# Limitless

Use `limitless` with the installed lifecycle hooks in `hooks/`. They start an
agent session at task start and release it at completion, interruption or session
exit where the agent exposes those events. Keep the hooks active through thinking
and tool calls; do not wrap each command separately.
Wait for delegated work before finishing the turn. Work detached beyond that
turn needs its own real lifecycle; an idle parent is not a valid substitute.

The helper uses both power sources and a 20% battery floor, respecting any stricter
user limits. Each task releases only its own session; the last one ends the hold.
If the user started Keep awake in the menu, leave it alone. Starting a manual
session also ends existing agent holds. Never change app preferences, stop a manual
session, rearm protection, or restart a task hold after a cutoff.

Check `limitless status` if protection is uncertain. If the CLI, helper permission,
or lifecycle hooks are missing, say so; do not claim whole-task coverage. Setup is
documented at https://github.com/leboonducoin/Limitless/blob/main/docs/cli.md#ai-agent-setup.
Installing this skill alone does not install hooks or grant permission to do so.

For another local agent, connect its real start/end/cancel events to
`limitless hook other` as described in the guide. Do not infer work from an open
agent window, poll transcripts, create dummy work, run sudo, or bypass a user limit.

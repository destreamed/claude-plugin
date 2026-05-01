---
description: Run the Destreamed tuner workflow. Use at session start, when the user asks "what's on my plate", or whenever you're about to start work in a tracked project. Walks through tasks, memos, plan-approval, step logging, and task completion.
---

# Destreamed Tune

You are a tuner on Destreamed — an AI agent working alongside humans. This skill walks the canonical 5-step tuner loop. Don't skip steps; the human relies on each one.

## The loop

1. **`mcp__destreamed__tasks` `action: get_my_tasks`** — pull tasks assigned to you. The response includes the relevant stream memos. Show the user a one-line summary per task. If nothing is assigned, ask the user what to work on.

2. **`mcp__destreamed__stream` `action: get_memos`** for the active stream — read the rules out loud (briefly) and follow them strictly for everything that follows. Memos override your defaults.

3. **`mcp__destreamed__beat` `action: add_echo` with `needs_approval: true`** — present your plan for the chosen task as an echo. Approve/Deny lands with the user. **Do not execute until approved.** If the plan is trivial (typo, single-line change), you can skip approval — but err on the side of asking.

4. **`mcp__destreamed__beat` `action: add_echo`** (no approval) — log every meaningful step as you work: commits, decisions, blockers, sub-results. Keep echoes 1–3 lines, no tool-output dumps. The human reads these like a Slack thread.

5. **`mcp__destreamed__tasks` `action: complete_task`** — close with a concise summary: what was done, what changed, anything still open.

## Patterns inside the loop

- **Need to ask the human something?** `mcp__destreamed__beat` `action: drop_beat` with `kind: question`. The user replies via echoes. Don't ask in chat alone — questions in beats survive context resets.
- **Want to propose a new rule for the stream?** `drop_beat` with `kind: memo` and `needs_approval: true`. Same approval gate as plans.
- **Before solving anything that smells like a known problem:** run `/destreamed:search` first.

## Hard rules

- Memos first. Follow them. They're not suggestions.
- `needs_approval: true` means stop and wait. Never proceed without an approve echo from the human.
- No secrets, customer data, or internal tokens in beats or echoes — these are persisted and shareable.
- One echo per logical step. Not per command.

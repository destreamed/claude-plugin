---
description: Submit a plan, decision, or proposed rule to Destreamed with `needs_approval: true` so the human can Approve or Deny before you execute. Use whenever you're about to do something material that the user has not already explicitly told you to do — refactors, deletions, dependency bumps, schema changes, new memos.
---

# Destreamed Propose

The approval gate is how a tuner stays in lockstep with the human. Use it whenever the next move is non-trivial and reversible only with effort.

## When to propose

- **Plans for an open task:** before the first material change, post the plan as an `add_echo` with `needs_approval: true` on the task beat.
- **New memo (stream rule):** `drop_beat` `kind: memo` `needs_approval: true`. The memo only applies to future tuner runs once approved.
- **Schema/data migrations, mass refactors, irreversible deletes, dependency upgrades, prod config changes** — even if you have a task assigned, gate the destructive step.

## How to write the proposal echo

Three sections, terse:

- **What:** the action in one line.
- **Why:** the reasoning, max two lines.
- **Impact:** files touched / records affected / what becomes irreversible.

Example:
```
What: rename `streams.name` to `streams.title` (and migration 0042).
Why: matches the new vocabulary memo; old name was confusing in API.
Impact: schema change + frontend renames in 14 files. Reversible only via fresh migration.
```

## What to do while waiting

Stop. Don't pre-execute "the safe parts". The user reads the proposal, decides, and replies via echo (Approve / Deny / Modify). Only then continue.

If the user denies, log a one-line echo with what you'll do instead, then re-propose if needed.

## Hard rules

- One proposal per material decision — don't bundle unrelated changes.
- Never include credentials, customer data, or internal tokens in the proposal.
- If you're calling this skill mid-task, the proposal echo lands on the **task beat**, not as a free-floating note.

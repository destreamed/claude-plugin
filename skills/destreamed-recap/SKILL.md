---
description: Append a recap echo to the active Destreamed session beat. Use when the user asks for a recap, when wrapping up a session, or when an important decision needs to be persisted out-of-band.
---

# Destreamed Recap

Append a concise echo (1–3 lines) to the active session-recap beat via `mcp__destreamed__beat` with `action: echo`. If no recap beat exists yet, run `/destreamed:onboard` first.

## Format

- **Done:** what completed since the last echo
- **Open:** what's pending or blocked
- **Next:** the immediate next step

## Rules

- Never paste raw tool output — summarize.
- No secrets, credentials, customer data, or internal tokens in echo content.
- One echo per logical step, not per command.

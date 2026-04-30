---
description: Run at the start of every Claude Code session in a Destreamed-tracked project. Finds or creates the matching stream, lists open assigned tasks, and posts a session-recap beat that subsequent echoes will hang off.
---

# Destreamed Onboard

Goal: align this Claude Code session with the user's Destreamed work log so progress, decisions, and blockers are persisted automatically — and so prior solutions are reachable.

## Routine

1. **Find the stream — never create blindly.** First check auto-memory for a known stream ID matching the current working directory. If absent, call `mcp__destreamed__stream` with `action: list` and fuzzy-match against project name and folder name (close spellings count). Save the matched stream ID to auto-memory so future sessions skip the lookup.
2. **Show open tasks.** Call `mcp__destreamed__tasks` with `action: get_my_tasks`. Briefly summarize what's assigned and the status — one line per task.
3. **If a stream exists:** read memos via `mcp__destreamed__stream` `action: get_memos` and follow them strictly. Then drop a recap beat with `mcp__destreamed__beat` (`kind: note`, title `Session Recap — YYYY-MM-DD`) containing branch, working directory, and the session goal. Remember the beat ID locally for the rest of the session.
4. **If no stream exists:** ask the user whether to create one. Suggest a name based on the working directory. Never create unprompted.
5. **Respect opt-out.** If auto-memory contains an entry stating "no Destreamed for this project", skip everything above silently.

## During the session

After each commit, feature completion, decision, or blocker, append a concise echo (1–3 lines, no tool-output dumps) on the recap beat ID via `mcp__destreamed__beat` with `action: echo`.

## Session end

Post a closing echo: what was achieved, what's open, what's next.

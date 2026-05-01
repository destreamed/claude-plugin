#!/usr/bin/env bash
# Destreamed SessionStart hook — fires on fresh Claude Code sessions (startup|clear).
# Reminds Claude to enter the tuner workflow before the first user prompt.

cat > /dev/null  # consume hook input

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"You're a tuner on Destreamed. Before answering the first prompt, run the /destreamed:tune skill — the canonical 5-step loop: (1) mcp__destreamed__tasks action:get_my_tasks (response also includes stream memos), (2) mcp__destreamed__stream action:get_memos and follow them strictly, (3) for any task you start, mcp__destreamed__beat action:add_echo with needs_approval:true containing the plan — STOP and wait for the user's approve echo, never pre-execute, (4) mcp__destreamed__beat action:add_echo (no approval) for each meaningful step as you work, 1–3 lines, no tool-output dumps, (5) mcp__destreamed__tasks action:complete_task with a summary when done. If no tasks are assigned and the user describes work to do, drop_beat kind:task first (one-line restatement of the request, pick or ask for the stream), then continue from step 2 — never bypass the loop. Hard rules: memos override your defaults; needs_approval:true means stop; no secrets in beats; one echo per logical step. If the user explicitly opts out for this project, skip silently."}}
JSON

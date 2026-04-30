#!/usr/bin/env bash
# Destreamed SessionStart hook — fires on fresh Claude Code sessions (startup|clear).
# Reminds Claude to run the onboarding routine before answering the first prompt.

cat > /dev/null  # consume hook input

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Destreamed session start. Run the /destreamed:onboard skill before answering the first user prompt: (1) check auto-memory for a known stream ID matching the current working directory; if missing, call mcp__destreamed__stream action:list and fuzzy-match against project name and folder name. (2) Show the user open assigned tasks via mcp__destreamed__tasks action:get_my_tasks. (3) If a stream exists, read its memos and create a recap beat (kind:note, title 'Session Recap — YYYY-MM-DD') containing branch, working dir, and session goal — remember the beat ID for echoes. (4) If no stream exists, ask the user whether to create one with a suggested name. Throughout the session, append echoes on the recap beat for completed steps, decisions, blockers, and the session-end summary. Skip silently if auto-memory contains an opt-out for this project."}}
JSON

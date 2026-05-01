#!/usr/bin/env bash
# Destreamed UserPromptSubmit hook — when the user reports a problem,
# remind the tuner to search Destreamed first before re-solving.
# Conditional on problem-shaped keywords to avoid context bloat.

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // .user_message // .message // empty' 2>/dev/null)

if printf '%s' "$prompt" | grep -qiE 'error|bug|broken|crash|stuck|fail(ed|s|ing)?|exception|stack ?trace|panic|not work|why.*not|cannot|won.?t work|fehler|problem|kaputt|hängt|funktioniert nicht|geht nicht'; then
  cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"Tuner problem-check: before reasoning about a fix, call mcp__destreamed__search with 2-4 keywords from the user's problem. If a prior solution exists in past beats or echoes, reference it (cite the beat ID) instead of redoing the analysis. Then post the eventual fix as an echo on the active task beat so the next tuner finds it. Run /destreamed:search if you want a structured walkthrough."}}
JSON
fi

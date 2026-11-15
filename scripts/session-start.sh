#!/usr/bin/env bash
# Destreamed SessionStart hook — fires on fresh Claude Code sessions (startup|clear).
# Reminds Claude to enter the tuner workflow before the first user prompt,
# and passes on the service sunset notice (CK-174): Destreamed is
# discontinued at the end of 31.12.2026 (Europe/Berlin). The date comes
# from the public status endpoint, so it follows the server's config.

cat > /dev/null  # consume hook input

API_URL="${DESTREAMED_API_URL:-https://destreamed.com/api/v1}"
API_URL="${API_URL%/}"

TUNE='You'"'"'re a tuner on Destreamed. Before answering the first prompt, run the /destreamed:tune skill — the canonical 5-step loop: (1) mcp__destreamed__tasks action:get_my_tasks (response also includes stream memos), (2) mcp__destreamed__stream action:get_memos and follow them strictly, (3) for any task you start, mcp__destreamed__beat action:add_echo with needs_approval:true containing the plan — STOP and wait for the user'"'"'s approve echo, never pre-execute, (4) mcp__destreamed__beat action:add_echo (no approval) for each meaningful step as you work, 1–3 lines, no tool-output dumps, (5) mcp__destreamed__tasks action:complete_task with a summary when done. If no tasks are assigned and the user describes work to do, drop_beat kind:task first (one-line restatement of the request, pick or ask for the stream), then continue from step 2 — never bypass the loop. Hard rules: memos override your defaults; needs_approval:true means stop; no secrets in beats; one echo per logical step. If the user explicitly opts out for this project, skip silently.'

emit() {
  # $1 = additionalContext text
  if command -v jq >/dev/null 2>&1; then
    jq -cn --arg ctx "$1" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
  else
    # Without jq only the static tuner text is safe to print as JSON.
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"You'"'"'re a tuner on Destreamed. Before answering the first prompt, run the /destreamed:tune skill."}}'
  fi
}

status=""
if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  status=$(curl -s --max-time 3 "$API_URL/sunset" 2>/dev/null || true)
fi

shut_down=""
message=""
if [ -n "$status" ] && printf '%s' "$status" | jq -e '.sunset_at' >/dev/null 2>&1; then
  shut_down=$(printf '%s' "$status" | jq -r '.shut_down')
  message=$(printf '%s' "$status" | jq -r '.message_en // empty')
fi

if [ "$shut_down" = "true" ]; then
  emit "Destreamed has been discontinued — the API answers 410 Gone and the destreamed tools no longer work. Do not run the /destreamed:tune loop. If the user asks about their Destreamed data: they can still sign in on the web and download their own data (Profile → Account → Export). Status: $API_URL/sunset"
elif [ -n "$message" ]; then
  emit "IMPORTANT — tell the user once at the start of this session: $message

$TUNE"
else
  emit "$TUNE"
fi

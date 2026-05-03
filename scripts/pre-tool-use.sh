#!/usr/bin/env bash
# Destreamed PreToolUse hook — sends a heartbeat to the active
# agent-session before each tool call, with a 1-line `current_step`
# inferred from the tool name + args. Throttled to one call per ~2s
# (Destreamed backend rate-limits anything tighter).
#
# Quietly no-op when there's no session file (e.g. registration failed
# at startup, plugin running offline, or user opted out by deleting
# ~/.claude/destreamed-session.json).

# Read the hook input — Claude Code passes a JSON object via stdin
# describing the upcoming tool call.
input="$(cat)"

session_file="${HOME}/.claude/destreamed-session.json"
[[ -r "$session_file" ]] || exit 0
[[ -n "${DESTREAMED_API_URL:-}" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0

session_id="$(jq -r '.session_id // empty' <"$session_file")"
agent_token="$(jq -r '.agent_token // empty' <"$session_file")"
[[ -n "$session_id" && -n "$agent_token" ]] || exit 0

# Throttle: skip if the last heartbeat fired within 2 seconds.
stamp_file="${HOME}/.claude/destreamed-last-heartbeat"
now="$(date +%s)"
if [[ -r "$stamp_file" ]]; then
  last="$(cat "$stamp_file" 2>/dev/null || echo 0)"
  if (( now - last < 2 )); then
    exit 0
  fi
fi
echo "$now" >"$stamp_file" 2>/dev/null

# Build a 1-line `current_step` from the tool name + a few telltale args.
tool_name="$(jq -r '.tool_name // .tool // "unknown"' <<<"$input" 2>/dev/null || echo unknown)"
case "$tool_name" in
  Read|read)
    arg="$(jq -r '.tool_input.file_path // .params.file_path // empty' <<<"$input" 2>/dev/null)"
    step="reading ${arg:-?}";;
  Write|write)
    arg="$(jq -r '.tool_input.file_path // empty' <<<"$input" 2>/dev/null)"
    step="writing ${arg:-?}";;
  Edit|edit)
    arg="$(jq -r '.tool_input.file_path // empty' <<<"$input" 2>/dev/null)"
    step="editing ${arg:-?}";;
  Bash|bash)
    arg="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null | head -c 60)"
    step="bash: ${arg:-?}";;
  *destreamed*beat*)
    action="$(jq -r '.tool_input.action // empty' <<<"$input" 2>/dev/null)"
    needs="$(jq -r '.tool_input.needs_approval // false' <<<"$input" 2>/dev/null)"
    if [[ "$action" == "echo" && "$needs" == "true" ]]; then
      step="proposing plan"
      activity="proposing"
    elif [[ "$action" == "drop" ]]; then
      step="drafting beat"
      activity="drafting"
    else
      step="beat: ${action:-?}"
    fi;;
  *destreamed*search*) step="searching destreamed";;
  *destreamed*) step="$tool_name";;
  *)
    step="$tool_name";;
esac
# Trim to 80 chars to keep the wire small.
step="$(printf '%.80s' "$step")"

activity="${activity:-executing}"

body=$(jq -nc \
  --arg step "$step" \
  --arg act  "$activity" \
  '{activity: $act, current_step: $step}')

curl -sf -m 2 -X PATCH \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DESTREAMED_API_TOKEN:-}" \
  -H "X-Destreamed-Agent-Token: ${agent_token}" \
  -d "$body" \
  "${DESTREAMED_API_URL%/}/api/v1/agents/sessions/${session_id}/heartbeat" \
  >/dev/null 2>&1 || true

exit 0

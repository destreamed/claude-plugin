#!/usr/bin/env bash
# Destreamed Stop hook — fires when the Claude Code session ends.
# Calls DELETE /agents/sessions/:id to release the session and any
# Persona-Lock it held. Quietly no-op if there's nothing to release.

cat > /dev/null  # consume hook input

session_file="${HOME}/.claude/destreamed-session.json"
[[ -r "$session_file" ]] || exit 0
[[ -n "${DESTREAMED_API_URL:-}" ]] || exit 0
command -v curl >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

session_id="$(jq -r '.session_id // empty' <"$session_file")"
agent_token="$(jq -r '.agent_token // empty' <"$session_file")"
[[ -n "$session_id" && -n "$agent_token" ]] || exit 0

curl -sf -m 2 -X DELETE \
  -H "Authorization: Bearer ${DESTREAMED_API_TOKEN:-}" \
  -H "X-Destreamed-Agent-Token: ${agent_token}" \
  "${DESTREAMED_API_URL%/}/api/v1/agents/sessions/${session_id}" \
  >/dev/null 2>&1 || true

# Best-effort: remove the session file so the next startup gets a fresh
# uuid + token. Any errors here are harmless — file may not exist if a
# parallel session already cleaned up.
rm -f "$session_file" 2>/dev/null || true

exit 0

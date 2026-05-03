#!/usr/bin/env bash
# Destreamed SessionStart hook — fires on fresh Claude Code sessions (startup|clear).
#
# Two responsibilities:
#  1. Inject the tuner-workflow reminder into Claude's first turn.
#  2. Register an agent-session against the Destreamed backend so the
#     "Live agents" cockpit sees this client and the Persona-Lock has a
#     handle to enforce against. Token + session_id land in
#     ~/.claude/destreamed-session.json (mode 600), read by the
#     pre-tool-use and stop hooks.
#
# Registration is best-effort: a missing API_URL or token simply skips
# the registration step — the session still works, just without
# presence/lock features.

cat > /dev/null  # consume hook input

# ── Agent-session registration (best-effort) ─────────────────────────────
register_session() {
  local api_url="${DESTREAMED_API_URL:-}"
  local user_token="${DESTREAMED_API_TOKEN:-}"
  if [[ -z "$api_url" || -z "$user_token" ]]; then
    return 0
  fi
  if ! command -v curl >/dev/null 2>&1; then
    return 0
  fi

  # uuidgen ships on macOS by default; on Linux it's in util-linux.
  local session_uuid
  session_uuid="$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || true)"
  [[ -z "$session_uuid" ]] && return 0

  local body persona_field=""
  if [[ -n "${DESTREAMED_PERSONA_ID:-}" ]]; then
    persona_field=",\"persona_id\":\"${DESTREAMED_PERSONA_ID}\""
  fi
  body="{\"session_uuid\":\"${session_uuid}\",\"client_kind\":\"cli\"${persona_field}}"

  local resp
  resp="$(curl -sf -m 3 -X POST \
    -H "Authorization: Bearer ${user_token}" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "${api_url%/}/api/v1/agents/sessions" 2>/dev/null)" || return 0

  local out_dir="${HOME}/.claude"
  mkdir -p "$out_dir"
  local out_file="${out_dir}/destreamed-session.json"
  printf '%s\n' "$resp" >"$out_file"
  chmod 600 "$out_file" 2>/dev/null
}
register_session || true

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"You're a tuner on Destreamed. Before answering the first prompt, run the /destreamed:tune skill — the canonical 5-step loop: (1) mcp__destreamed__tasks action:get_my_tasks (response also includes stream memos), (2) mcp__destreamed__stream action:get_memos and follow them strictly, (3) for any task you start, mcp__destreamed__beat action:add_echo with needs_approval:true containing the plan — STOP and wait for the user's approve echo, never pre-execute, (4) mcp__destreamed__beat action:add_echo (no approval) for each meaningful step as you work, 1–3 lines, no tool-output dumps, (5) mcp__destreamed__tasks action:complete_task with a summary when done. If no tasks are assigned and the user describes work to do, drop_beat kind:task first (one-line restatement of the request, pick or ask for the stream), then continue from step 2 — never bypass the loop. Hard rules: memos override your defaults; needs_approval:true means stop; no secrets in beats; one echo per logical step. If the user explicitly opts out for this project, skip silently."}}
JSON

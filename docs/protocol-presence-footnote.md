# Destreamed API Protocol — Presence Footnote (v1.0 draft)

> Status: **DRAFT**. This is a server/client protocol spec, not a plugin spec. The plugin (`destreamed/claude-plugin`) is one client; the browser extension, npm MCP bridge, claude.ai connector, and any future agent are all peers. This doc lives here while it's being designed; once locked, it should move to `destreamed-backend/docs/api-protocol.md` or a dedicated spec repo.

## Purpose

Every response from a Destreamed API or MCP endpoint carries a metadata footnote (`_meta.destreamed`) that gives the requester a real-time picture of:

- **Who else is active** in the relevant stream (presence)
- **What changed** in the requester's context since last view (drift)
- **What the server wants to advise** the requester about (advisories)
- **The state of the workflow** the requester is participating in (workflow_state)
- **A weak ETag** for cheap "did anything change" checks (presence_etag)

This footnote rides on every normal request. There is **no separate subscription channel, no polling loop, no notification bus** required for basic agent-to-agent (a2a) coordination. The pattern: agents are already making requests to do their work; the footnote piggybacks on those round-trips and keeps each agent's situational awareness current.

## Scope

The footnote applies to:

- All **MCP responses** — placed in the standard MCP `_meta` field of the response envelope
- All **REST API responses** under `/api/v1/*` — placed at the top-level `_meta` field of the JSON body
- **Error responses too** (4xx/5xx) — agents need situational awareness most when something fails

Out of scope: OAuth flow endpoints (`/oauth/*`, `/.well-known/*`), file uploads via presigned URLs, anything outside the authenticated API surface.

## Versioning

- The footnote carries `_meta.destreamed.protocol_version` (semver string, e.g., `"1.0"`).
- Server announces supported protocol versions in `/.well-known/destreamed-protocol`:
  ```json
  { "supported": ["1.0"], "minimum_recommended": "1.0", "latest": "1.0" }
  ```
- Clients declare desired version via header: `X-Destreamed-Protocol-Version: 1.0`. Server responds with the actual version used.
- **Breaking changes** require a new major; the footnote shape under `_meta.destreamed` may evolve additively within `1.x` without breaking clients.
- **Non-aware clients** (older plugins, generic MCP clients, third-party tools) silently ignore `_meta.destreamed`. MCP and REST both tolerate unknown fields. The footnote is **never** load-bearing for the response payload — it's purely advisory.

## Coverage tiers — slim vs rich

Two response classes, distinguished by which fields are populated.

### Slim footnote (every response)

Always present, low byte-cost, computed cheaply server-side:

```json
{
  "_meta": {
    "destreamed": {
      "protocol_version": "1.0",
      "server_time": "2026-05-01T12:03:01Z",
      "presence_etag": "W/\"a3f8b1\"",
      "advisories": [],
      "workflow_state": {
        "focus_task": "DESTREAM-81",
        "current_gate": "human-gate",
        "blocking_on": "user:chris",
        "stale_in_seconds": 71400
      }
    }
  }
}
```

Fields:
| Field | When | Purpose |
|---|---|---|
| `protocol_version` | always | Negotiation |
| `server_time` | always | Clock-skew detection, stale-data check |
| `presence_etag` | always (when actor has stream context) | Cheap "anything changed" |
| `advisories` | always (may be `[]`) | Server-driven behavioral hints |
| `workflow_state` | always when actor has an active focus | Tells agent which gate is blocking and on whom |

### Rich footnote (focus / list / context endpoints)

Adds `presence` and `context_drift` blocks. Returned on endpoints where the agent is *establishing or refreshing* context — not on per-action calls.

```json
{
  "_meta": {
    "destreamed": {
      "protocol_version": "1.0",
      "server_time": "2026-05-01T12:03:01Z",
      "presence_etag": "W/\"a3f8b1\"",
      "advisories": [
        {
          "level": "warn",
          "code": "stream_freeze_active",
          "until": "2026-05-04T00:00:00Z",
          "message": "destreamed-backend is in merge freeze; non-critical material steps will be denied",
          "action_hint": "request override via memo, or work on a non-frozen stream"
        }
      ],
      "workflow_state": { /* … */ },
      "presence": {
        "stream_slug": "destreamed-backend",
        "active": [
          {
            "actor": "user:chris",
            "kind": "human",
            "focus": "DESTREAM-81",
            "activity": "reading_echoes",
            "since": "2026-05-01T12:01:23Z"
          },
          {
            "actor": "tuner:backend-engineer@session_abc",
            "kind": "tuner",
            "focus": "DESTREAM-82",
            "activity": "executing",
            "since": "2026-05-01T12:02:00Z"
          }
        ],
        "truncated": false
      },
      "context_drift": {
        "stream_memos_changed_since_focus": false,
        "echoes_added_since_last_view": [
          { "task": "DESTREAM-81", "count": 2, "by": "user:chris", "latest_at": "2026-05-01T12:00:55Z" }
        ],
        "tasks_assigned_since_last_view": []
      }
    }
  }
}
```

### Endpoint classification

| Endpoint | Tier | Rationale |
|---|---|---|
| `POST /api/v1/agents/register` | rich | Initial state load |
| `POST /api/v1/agents/refresh` | slim | Just renewing token |
| `GET /api/v1/tasks/me/open` | rich | List endpoint, agent reframes view |
| `GET /api/v1/tasks/:id/context` | rich | Focus switch, full context refresh |
| `GET /api/v1/streams/:slug` | rich | Stream-level browse |
| `POST /api/v1/echoes/:id/approve` | slim | One-shot action |
| `POST /api/v1/echoes/:id/deny` | slim | One-shot action |
| `MCP tool: get_my_tasks` | rich | Equivalent of REST list |
| `MCP tool: get_stream` | rich | Stream-level browse |
| `MCP tool: get_memos` | slim | Targeted lookup |
| `MCP tool: search_beats` | slim | Targeted query |
| `MCP tool: drop_beat` | slim | Action |
| `MCP tool: add_echo` | slim | Action |
| `MCP tool: complete_task` | slim | Action |
| All error responses | matches the request tier | Drift info matters during failure |

If a server can't compute a rich footnote within the response SLO, it may downgrade to slim and add advisory `code: "footnote_degraded"`. Agents should not retry just to get richer footnote.

## Agent identity — registration model

Concrete flow, locked decision:

### Step 1: Register at session start

```http
POST /api/v1/agents/register HTTP/1.1
Host: destreamed.com
Authorization: Bearer <oauth_access_token>
Content-Type: application/json

{
  "tuner_slug": "backend-engineer",
  "client_kind": "claude-code",
  "client_version": "0.4.0",
  "session_uuid": "abc123-de45-…",
  "capabilities": ["focus_switching", "subagent_spawn"]
}
```

Response:

```json
{
  "agent_token": "agt_3f8a91b2c3d4…",
  "expires_at": "2026-05-02T12:00:00Z",
  "actor": "tuner:backend-engineer@session_abc123",
  "_meta": { /* rich footnote */ }
}
```

The `agent_token` is opaque to the client; server-side it's bound to:
- the OAuth subject (user identity)
- the declared tuner slug
- the session UUID (so multiple parallel Claude Code instances get distinct presence entries)
- a TTL (24h default, refreshable)

### Step 2: Carry the agent token on every subsequent request

```http
GET /api/v1/tasks/me/open HTTP/1.1
Authorization: Bearer <oauth_access_token>
X-Destreamed-Agent-Token: agt_3f8a91b2c3d4…
```

Both headers required. OAuth proves the user; agent-token proves the session+role.

### Step 3: Refresh before expiry

```http
POST /api/v1/agents/refresh
Authorization: Bearer <oauth_access_token>
X-Destreamed-Agent-Token: agt_3f8a91b2c3d4…
```

Response: new `agent_token` + new `expires_at`. Old token is revoked. Refresh window: last 25 % of TTL (so for 24h tokens, refresh allowed in last 6h).

### Step 4: On 401 with `agent_token_expired` advisory

Re-register. The session_uuid stays the same (continuity for presence), tuner_slug may change if the agent has switched tuners (which is a `/dt` to a task with a different `assigned_tuner`). Server treats this as the same agent, same session, just a tuner-change event — drops the appropriate `tuner_changed` advisory to other observers.

### Why registration vs custom-header (option a) or OAuth-subclaim (option b)

Locked to (c) because:
- **Server has explicit lifecycle** for the agent — register/refresh/revoke. Other clients can list active agents on a stream auditably.
- **Privacy boundary is clean** — server decides what agent info goes into presence (no client-controlled headers leaking).
- **Tuner switching is a first-class event** — re-registering on `/dt <task>` makes the presence transition visible to peers without ad-hoc heuristics.
- **Future a2a primitives** (peer-validate routing, hand-offs) need server-known agent-IDs; registration gives us those without retro-fitting.

Cost: one extra round-trip per session start. Acceptable.

## Presence semantics

- An actor is "active" if the server has seen any authenticated request from it in the **last 60 seconds** (server-configurable per stream via memo: `presence_window_seconds`).
- Presence list returns **up to 25 most-recent actors per stream** (server-configurable: `presence_max_actors`). When truncated, set `truncated: true`.
- Two clients of the same OAuth subject with **different session_uuid** show as **separate presence entries** — Chris-on-laptop and Chris-on-mobile see each other.
- Tuners and humans are both "actors" with `kind: "human" | "tuner"` distinguishing.
- `activity` is a coarse string — server-defined enum:
  - `idle` (no recent state-changing action)
  - `reading_*` (read endpoints recently)
  - `drafting` (echoes posted in last N seconds without `needs_approval`)
  - `proposing` (just dropped a `needs_approval:true` echo)
  - `executing` (action endpoints recently called after an approve)
  - `awaiting_approval` (proposed and waiting)
  - `awaiting_peer` (workflow gate `peer-validate` blocking)
  - `unknown` (fallback)

## Privacy boundaries

Hard rules:

- Presence is **scoped to the stream**. An agent never sees presence in a stream it has no membership of, even via aggregated counts.
- Cross-stream presence aggregation (e.g., "Alice is busy on 4 streams") is **out of scope for v1.0**.
- No conversation content in the footnote. The fact that "Alice is drafting" is OK; what she's drafting is not.
- No PII beyond what's already exposed via the user's display identifier (e.g., display name, but never email/phone).
- All footnote fields are advisory — clients that ignore them get a fully functional API. The footnote never carries authorization-relevant data.

## ETag mechanism

The `presence_etag` is a weak ETag computed server-side from the deterministic fingerprint of:
- the `presence.active` set (actor + activity + focus)
- the `advisories` array
- the `workflow_state` block

Cost-saving flow on subsequent requests:

```http
GET /api/v1/tasks/me/open HTTP/1.1
Authorization: Bearer …
X-Destreamed-Agent-Token: agt_…
If-Destreamed-Presence-None-Match: W/"a3f8b1"
```

If etag matches, server returns:
- the regular response payload (the actual data — tasks, beats, etc.)
- but `_meta.destreamed.presence_unchanged: true` and **omits** `presence` and `context_drift` blocks

If etag mismatches, full footnote is returned with the new etag.

This typically saves 50–90 % of footnote bytes in steady-state agent loops where presence is stable.

## Advisory taxonomy

Server-defined `code` enum, namespaced. Initial set:

| Code | Level | Trigger | Action hint |
|---|---|---|---|
| `stream_freeze_active` | warn | Stream is in freeze window | Defer non-critical material steps |
| `stream_archived` | error | Stream marked archived after focus | Switch focus to active stream |
| `peer_tuner_joining` | info | Another tuner just registered on same stream | Optionally backoff, expect coordination |
| `schema_version_mismatch` | warn | Server schema newer than client expects | Suggest plugin update |
| `rate_limit_close` | warn | Approaching per-actor rate limit | Slow down |
| `rate_limit_exceeded` | error | Limit hit | Backoff with Retry-After |
| `agent_token_expiring` | info | TTL < 5min | Refresh now |
| `agent_token_expired` | error | TTL < 0 | Re-register |
| `oauth_scope_insufficient` | error | Action would require unprovisioned scope | Re-auth with extra scope |
| `workflow_freeze` | warn | Stream's workflow blocks current operation type | Switch operation or get override |
| `footnote_degraded` | info | Server fell back to slim footnote on a rich endpoint | Re-fetch later if richness needed |

Each advisory is `{ code, level, message, action_hint?, until?, details? }`. Clients log unrecognized codes but don't error on them — forward-compat.

## Workflow state

When the actor has an active focus task, this block describes where they are in the workflow:

```json
{
  "focus_task": "DESTREAM-81",
  "current_gate": "human-gate",
  "gate_index": 1,
  "total_gates": 2,
  "blocking_on": "user:chris",
  "stale_in_seconds": 71400,
  "history": [
    { "gate": "plan-first", "satisfied_at": "2026-05-01T11:55:00Z", "satisfied_by": "tuner:backend-engineer@session_abc" }
  ]
}
```

Fields:
- `current_gate` — slug of the gate primitive currently blocking; `null` if all gates passed and tuner is free to execute, or `"completed"` if task is done
- `blocking_on` — actor reference for who/what we're waiting on (`"user:<id>"`, `"tuner:<slug>@<session>"`, `"automated:<check_name>"`, `"timer"`)
- `stale_in_seconds` — seconds until the current gate's stale-deny fires (negative if past)
- `history` — gates already satisfied in this task's lifecycle

`current_gate: "human-gate"` is the only one with full server runtime support in v1.0. The structure is forward-compat for `peer-validate`, `automated-check`, `dual-sign-off` in v0.5+.

## Backwards compatibility

The footnote is **always additive**. Adding new advisories, new fields under `_meta.destreamed`, or new gate primitives must not break older clients. Concretely:

- New top-level fields under `_meta.destreamed` — clients ignore unknown
- New advisory codes — clients log and skip unknown
- Schema fields removed → never. Deprecation cycles only.

Agents should treat the footnote as **read-only reading-aid metadata**. Never authorize on it. Never crash on missing fields. Defaults: empty advisories, no presence, no drift.

## Server implementation notes (non-normative)

- Compute presence by maintaining an in-memory or Redis-backed map `(stream_id) -> [(agent_token, last_seen, activity, focus)]`, expire entries past `presence_window_seconds`.
- ETag computation: stable hash of sorted active-actor-tuples + advisory codes + workflow_state. Use FNV-1a or xxHash64; avoid SHA for cost.
- Drift computation: requires per-agent "last_view" cursors per stream/task. Cheap — store in Redis with 7-day TTL.
- Presence write-amplification: every authenticated request updates the actor's `last_seen`. Use an LRU + write-coalescing buffer to flush every 1–2s.

## Open questions / TBD for v1.1+

- **Real-time push channel**: should there be an SSE endpoint that streams just `_meta.destreamed` deltas? Probably yes for browser-extension and claude.ai-connector parity. Agents on Claude Code (CLI) likely don't need it — they're request-driven.
- **Cross-stream activity hints**: minimal "Alice is in 3 streams right now" without leaking which streams — useful for UX, privacy-sensitive. Defer.
- **Agent-to-agent direct messaging** via beats with `target: tuner:<slug>@<session>` — deferred until peer-validate is built.
- **Workflow-state for paused/parked tasks** — what does the footnote say when the user explicitly parks DESTREAM-81 and switches to DESTREAM-82?
- **Agent capabilities negotiation** — currently `capabilities: []` at register time is informational. Server doesn't reject yet. v1.1 may use this to gate features.

## What this enables for v0.4 plugin

- `/dt` switch shows in chat: "Alice is also focused on this task — last echo 30s ago, current activity: drafting". Tuner adapts (waits or coordinates).
- Stream-freeze advisory makes tuner refuse material proposals automatically with the action_hint.
- `presence_etag` saves bandwidth in long sessions where the tuner is mostly executing within a quiet stream.
- `workflow_state` tells the tuner exactly where it stands without computing it client-side from echo history.
- All this is achievable within the v0.4 plugin client without any extra MCP tools or REST calls — it just reads the footnote that's already there.

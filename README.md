# Destreamed for Claude Code

Turns Claude Code into a Destreamed tuner — an AI agent that picks up tasks, follows stream memos, gates material work behind human approval, and persists every step as echoes the team can read.

## The tuner loop

Every session, Claude follows the canonical 5-step Destreamed workflow:

1. **Get tasks** — `get_my_tasks` pulls what's assigned, including the relevant stream memos.
2. **Read memos** — stream rules override Claude's defaults. Followed strictly.
3. **Propose** — for any non-trivial change, the plan goes back to you as an `add_echo` with `needs_approval: true`. Claude waits for your Approve.
4. **Log** — every meaningful step (commits, decisions, blockers) is a 1–3 line echo on the task beat.
5. **Complete** — `complete_task` with a summary of what was done and what's open.

Two cross-cutting helpers run automatically:
- **Prior-art search** — when you report a problem, Claude searches past beats and echoes before re-solving.
- **Question beats** — when Claude needs input, it drops a `kind: question` beat instead of asking only in chat. Replies survive context resets.

## Install

```text
/plugin marketplace add destreamed/claude-plugin
/plugin install destreamed@destreamed
```

On first MCP call your browser opens for OAuth — sign in to Destreamed, approve the requested scopes, done. The access token lives in your OS keychain and refreshes itself; you'll never see it.

## Slash commands

| Command | What it does |
|---|---|
| `/destreamed:tune` | Walk the 5-step tuner loop manually for the active stream. |
| `/destreamed:propose` | Submit a plan, decision, or rule-change with `needs_approval: true`. |
| `/destreamed:search <keywords>` | Query past beats and echoes for prior solutions before solving. |

## How it hooks in

- **`SessionStart` hook** (matcher `startup|clear`) primes Claude with the tuner-loop reminder before answering the first prompt of a fresh session. Resume and compact don't re-trigger.
- **`UserPromptSubmit` hook** detects problem-shaped prompts (error, bug, broken, crash, exception, …) and reminds the tuner to search prior beats first. Silent on normal prompts.
- **MCP server** (Destreamed's HTTP endpoint) is registered automatically — no manual `.mcp.json` editing.

## Authentication

Authentication uses the standard MCP OAuth 2.0 flow (RFC 9728 / RFC 8414) with PKCE and Dynamic Client Registration. No tokens to paste, no manifests to edit. Requested scopes:

- `streams:read`, `streams:write`
- `beats:read`, `beats:write`
- `vectors:read`

To revoke access later: https://destreamed.com/settings/connections.

## Privacy

This plugin sends Destreamed only what Claude explicitly tools-calls (search queries, beat content, task lookups). Your conversation history is **not** sent. OAuth tokens are stored in your OS keychain and never written to plain files.

## License

MIT — see [LICENSE](./LICENSE).

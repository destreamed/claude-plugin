# Destreamed for Claude Code

Persistent work-log integration. Claude remembers what you've solved before.

## What it does

- **Every session**, Claude finds the matching Destreamed stream for your project, lists your open tasks, and posts a session-recap beat that subsequent echoes hang off.
- **When you report a problem**, Claude searches Destreamed for prior solutions before re-solving from scratch — past fixes, decisions, and discussions are reachable as conversation context.
- **Important steps** (commits, decisions, blockers, session-end summaries) are persisted as echoes on the recap beat — they survive context compaction, conversation resets, and team handoffs.

## Install

```text
/plugin marketplace add destreamed/claude-plugin
/plugin install destreamed@destreamed
```

On first MCP call your browser opens for OAuth — sign in to Destreamed, approve the requested scopes, done. The access token lives in your OS keychain and refreshes itself; you'll never see it.

## Slash commands

| Command | What it does |
|---|---|
| `/destreamed:onboard` | Run the session-start routine manually (find stream, list tasks, create recap beat). |
| `/destreamed:search <keywords>` | Query past beats and echoes for prior solutions. |
| `/destreamed:recap` | Append a recap echo to the current session beat. |

## How it hooks in

- **`SessionStart` hook** (matcher `startup|clear`) reminds Claude to run `/destreamed:onboard` before answering the first prompt of a fresh session. Resume and compact don't re-trigger — your existing recap stays in context.
- **`UserPromptSubmit` hook** detects problem-shaped prompts (error, bug, broken, crash, exception, …) and reminds Claude to search Destreamed for prior solutions first. Silent on normal prompts.
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

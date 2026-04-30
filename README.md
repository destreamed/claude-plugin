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

You'll be prompted for your **Destreamed API token** (generate one at https://destreamed.com/settings/tokens). It's stored in your OS keychain — never written to plain files.

If you self-host Destreamed, also set `destreamed_base_url` during install.

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

## Configuration

| Field | Required | Description |
|---|---|---|
| `destreamed_api_token` | yes | Your API token. Sensitive — keychain only. |
| `destreamed_base_url` | no | Defaults to `https://destreamed.com`. Override only if self-hosting. |

## Privacy

This plugin sends Destreamed only what Claude explicitly tools-calls (search queries, beat content, task lookups). Your conversation history is **not** sent. Bearer tokens never leave your machine in plaintext — they're substituted into the MCP request headers at runtime.

## License

MIT — see [LICENSE](./LICENSE).

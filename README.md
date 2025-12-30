# Ensue Memory Network

**Get smarter alongside your AI.**

Your intelligence shouldn't reset every conversation. Ensue adds a persistent, external memory layer to Claude Code - what you learn today enriches tomorrow's reasoning, and important context can carry forward across sessions, and optionally across tools and agents.

## The Idea

Every conversation with an LLM starts from zero. You explain context, re-establish preferences, repeat decisions you've already made. Your knowledge doesn't compound, and for longer-running work, especially when you use multiple AI tools in your workflows, this quickly leads to duplication and drift.

Ensue changes that:

- **Your knowledge persists** - Build a tree of intelligence that spans conversations and is stored outside the session
- **Context carries forward** - Prior research, decisions, and insights inform new work
- **Context can be shared** - Memory isn’t tied to a single agent or tool. Context created in Claude can be reused in Codex, Manus, Cursor, or other agents — and vice versa. Specific parts can also be shared with a team.

Think of it as extended memory outside the agent. When you ask about GPU inference, the LLM checks what you already know and can retrieve relevant context you've already saved - even if that context was created in a different tool or on a different platform.

When you make an architecture decision, it connects to past decisions in similar domains. Your accumulated knowledge becomes part of every conversation, usable by mulltiple agents operating over the same evolving state.

## Install (Claude Code)

```
/plugin marketplace add https://github.com/mutable-state-inc/ensue-skill
```

```
/plugin install ensue-memory
```

Restart Claude Code. The skill will guide you through setup.

## Configuration

| Variable | Description |
|----------|-------------|
| `ENSUE_API_KEY` | Required. Get one at [dashboard](https://www.ensue-network.ai/dashboard) |
| `ENSUE_READONLY` | Set to `true` to disable auto-logging (session tracking, tool capture). Manual `remember`/`recall` still works. |

```bash
# Disable auto-logging for a session
ENSUE_READONLY=true claude

# Or add to ~/.zshrc for permanent read-only mode
export ENSUE_READONLY=true
```

## Try it

```
"remember my preferred stack is React + Postgres"
"what do I know about caching strategies?"
"check my research/distributed-systems/ notes"
```

## Links

[Docs](https://www.ensue-network.ai/docs) · [Dashboard](https://www.ensue-network.ai/dashboard) · [Homepage](https://ensue.dev) · API: `https://api.ensue-network.ai`

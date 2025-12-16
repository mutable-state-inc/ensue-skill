# Ensue Memory Network

Persistent memory layer for AI agents. Store, recall, search, and share memories with semantic vector search.

## Installation

```bash
claude /plugin marketplace add https://github.com/mutable-state-inc/ensue-skill
claude /plugin install ensue-memory
```

## Setup

1. Get an API key from [ensue.dev](https://ensue.dev)

2. Add the MCP server to Claude Code:
```bash
claude mcp add memory-network-ensue https://api.ensue-network.ai/ --header "Authorization: Bearer YOUR_API_KEY"
```

## Usage

Once installed, the skill triggers on natural language like:

| You say | What happens |
|---------|--------------|
| "Remember that the API key is stored in .env" | Creates a memory |
| "What was the database schema?" | Searches memories |
| "Search memories for authentication" | Semantic search |
| "Update the project notes" | Updates a memory |
| "List my memory keys" | Lists stored keys |
| "Share this with the team" | Shares a memory |

## How It Works

The skill uses curl to interact with the Ensue Memory Network API via JSON-RPC. Tools are discovered dynamically, so the skill stays current with server updates.

## Links

- Homepage: [ensue.dev](https://ensue.dev)
- API: [api.ensue-network.ai](https://api.ensue-network.ai)

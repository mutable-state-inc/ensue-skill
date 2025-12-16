---
name: ensue-memory
description: Persistent memory layer for AI agents via Ensue Memory Network API. Use when users ask to remember, recall, search memories, manage permissions, or subscribe to updates. Triggers on "remember this", "recall", "search memories", "update memory", "list keys", "share", "subscribe to", "permissions", or any persistent storage request.
---

# Ensue Memory Network

Dynamic memory service accessed via curl for fast CLI execution.

## Initialization (REQUIRED FIRST)

**Before doing anything else**, check for API key:

```bash
claude mcp get memory-network-ensue
```

If this returns a Bearer token in the headers, extract it and proceed.

If not configured, notify the user:
> "Ensue Memory Network is not configured. To set up:
> 1. Get an API key from https://ensue.dev
> 2. Run: `claude mcp add memory-network-ensue https://api.ensue-network.ai/ --header \"Authorization: Bearer YOUR_API_KEY\"`"

**Do not proceed until API key is available.**

## Tool Discovery

After confirming API key, discover available tools:

```bash
curl -X POST https://api.ensue-network.ai/ \
  -H "Authorization: Bearer <API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
```

This returns current tool names, descriptions, and input schemas. **Always check schemas before calling** - they may change.

## Tool Invocation

Call tools via JSON-RPC:

```bash
curl -X POST https://api.ensue-network.ai/ \
  -H "Authorization: Bearer <API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"<tool_name>","arguments":{<args>}},"id":1}'
```

## Intent Mapping

| User says | Tool to call |
|-----------|--------------|
| "remember...", "save...", "store..." | create_memory |
| "what was...", "recall...", "get..." | get_memory or search_memories |
| "search for...", "find..." | search_memories |
| "update...", "change..." | update_memory |
| "delete...", "remove..." | delete_memory |
| "list keys", "show memories" | list_keys |
| "share with...", "give access..." | share |
| "who can access...", "permissions" | list_permissions |
| "notify when...", "subscribe..." | subscribe_to_memory |

## Key Naming

Use hierarchical paths: `category/subcategory/name`

Examples: `preferences/theme`, `project/api-keys`, `notes/meeting-2024-01`

---
name: ensue-memory
description: Persistent memory layer for AI agents via Ensue Memory Network API. Use when users ask to remember, recall, search memories, manage permissions, subscribe to updates, or ask what they can do with Ensue. Triggers on "remember this", "recall", "search memories", "update memory", "list keys", "share", "subscribe to", "permissions", "what can I do with ensue", or any persistent storage request.
---

# Ensue Memory Network

Dynamic memory service accessed via curl.

## IMPORTANT: Do NOT use native MCP tools

**NEVER use these for ANY Ensue query (including capability questions):**
- `listMcpResources`
- `listMcpTools`
- `mcp__*` tools
- Any native MCP tool calls

**ONLY use curl** as described below. This ensures consistent behavior and dynamic schema discovery.

## Execution Order (MUST FOLLOW)

**Step 1: Get API key**

Check for the `ENSUE_API_KEY` environment variable:

```bash
echo $ENSUE_API_KEY
```

If empty or not set, ask the user to provide their API key or set the environment variable:
> "I need your Ensue API key to continue. You can either:
> 1. Provide it now, or
> 2. Set the environment variable: `export ENSUE_API_KEY=your_key`
>
> Get an API key from https://www.ensue-network.ai/dashboard"

**Step 2: List available tools (REQUIRED before any tool call)**

```bash
curl -X POST https://api.ensue-network.ai/ \
  -H "Authorization: Bearer <API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
```

This returns tool names, descriptions, and input schemas. **Never skip this step.**

**Step 3: Call the appropriate tool**

```bash
curl -X POST https://api.ensue-network.ai/ \
  -H "Authorization: Bearer <API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"<tool_name>","arguments":{<args>}},"id":1}'
```

Use the schema from Step 2 to construct correct arguments.

## Batch Operations

When performing multiple operations (e.g., creating several memories, searching multiple keys, or any repetitive task), **write a bash script** instead of executing curl commands one at a time. This is more efficient and reduces latency.

**Example: Creating multiple memories in batch**

```bash
#!/bin/bash
API_KEY="$ENSUE_API_KEY"
API_URL="https://api.ensue-network.ai/"

# Array of memories to create
declare -a memories=(
  '{"key":"notes/meeting-jan","value":"Discussed Q1 roadmap"}'
  '{"key":"notes/meeting-feb","value":"Budget review completed"}'
  '{"key":"notes/meeting-mar","value":"Launched new feature"}'
)

for memory in "${memories[@]}"; do
  key=$(echo "$memory" | jq -r '.key')
  value=$(echo "$memory" | jq -r '.value')

  curl -s -X POST "$API_URL" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"create_memory\",\"arguments\":{\"key\":\"$key\",\"value\":\"$value\"}},\"id\":1}"

  echo "Created: $key"
done
```

**Example: Batch search across multiple keys**

```bash
#!/bin/bash
API_KEY="$ENSUE_API_KEY"
API_URL="https://api.ensue-network.ai/"

keys=("notes/meeting-jan" "notes/meeting-feb" "preferences/theme")

for key in "${keys[@]}"; do
  echo "=== $key ==="
  curl -s -X POST "$API_URL" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"get_memory\",\"arguments\":{\"key\":\"$key\"}},\"id\":1}" | jq '.result'
done
```

**When to use batch scripts:**
- Creating 3+ memories at once
- Deleting multiple keys
- Searching across multiple categories
- Migrating or backing up memories
- Any repetitive API operation

## Intent Mapping

| User says | Action |
|-----------|--------|
| "what can I do", "capabilities", "help" | Steps 1-2 only (summarize tools/list response) |
| "remember...", "save...", "store..." | create_memory |
| "what was...", "recall...", "get..." | get_memory or search_memories |
| "search for...", "find..." | search_memories |
| "update...", "change..." | update_memory |
| "delete...", "remove..." | delete_memory ⚠️ |
| "list keys", "show memories" | list_keys |
| "share with...", "give access..." | share |
| "revoke access...", "remove user..." | revoke_share ⚠️ |
| "who can access...", "permissions" | list_permissions |
| "notify when...", "subscribe..." | subscribe_to_memory |

## ⚠️ Destructive Operations Warning

**Before executing operations marked with ⚠️, warn the user and request confirmation:**

### Delete Operations
Before calling `delete_memory` (single or batch):
1. **Show what will be deleted** - List the key(s) and count
2. **Warn**: "This will permanently delete [N] memories. This cannot be undone."
3. **Request confirmation**: Wait for user to confirm

Example:
> ⚠️ Deleting 3 memories: `notes/jan`, `notes/feb`, `notes/mar`. This cannot be undone. Proceed?

### Revoking User Access
Before calling `revoke_share`:
1. **Show who will lose access**: List affected user(s)
2. **Warn about impact**: "This will immediately revoke access for [user(s)]"
3. **Request confirmation**

Example:
> ⚠️ Revoking access for `alice@example.com` to `project/secrets`. They will immediately lose access. Proceed?

## Key Naming

Use hierarchical paths: `category/subcategory/name`

Examples: `preferences/theme`, `project/api-keys`, `notes/meeting-2024-01`

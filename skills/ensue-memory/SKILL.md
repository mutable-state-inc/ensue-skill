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

## Security: API Key Handling

**CRITICAL: Never expose the API key in the session.**

- **NEVER** use `echo $ENSUE_API_KEY` or any command that prints the key
- **NEVER** accept the API key inline from the user in the conversation
- **NEVER** interpolate the key into commands in a way that could be logged
- **ALWAYS** require the key to be set as an environment variable before proceeding

## Execution Order (MUST FOLLOW)

**Step 1: Verify API key is set**

Check if `ENSUE_API_KEY` is set WITHOUT revealing its value:

```bash
[ -z "$ENSUE_API_KEY" ] && echo "ENSUE_API_KEY is not set" || echo "ENSUE_API_KEY is set"
```

If not set, tell the user:
> "The `ENSUE_API_KEY` environment variable is not set. Please set it before continuing:
>
> ```bash
> export ENSUE_API_KEY=your_key
> ```
>
> Get an API key from https://www.ensue-network.ai/dashboard
>
> For security, I cannot accept the API key directly in this conversation."

**Do not proceed until the environment variable is confirmed set.**

**Step 2: List available tools (REQUIRED before any tool call)**

```bash
curl -s -X POST https://api.ensue-network.ai/ \
  -H "Authorization: Bearer $ENSUE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
```

This returns tool names, descriptions, and input schemas. **Never skip this step.**

**Step 3: Call the appropriate tool**

```bash
curl -s -X POST https://api.ensue-network.ai/ \
  -H "Authorization: Bearer $ENSUE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"<tool_name>","arguments":{<args>}},"id":1}'
```

Use the schema from Step 2 to construct correct arguments.

## Batch Operations

When performing multiple operations (e.g., creating several memories, searching multiple keys, or any repetitive task), **write a bash script** instead of executing curl commands one at a time. This is more efficient and reduces latency.

**Example: Creating multiple memories in batch**

```bash
#!/bin/bash
# ENSUE_API_KEY must be set in the environment - never echo or log it
[ -z "$ENSUE_API_KEY" ] && { echo "Error: ENSUE_API_KEY not set"; exit 1; }

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
    -H "Authorization: Bearer $ENSUE_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"create_memory\",\"arguments\":{\"key\":\"$key\",\"value\":\"$value\"}},\"id\":1}"

  echo "Created: $key"
done
```

**Example: Batch search across multiple keys**

```bash
#!/bin/bash
# ENSUE_API_KEY must be set in the environment - never echo or log it
[ -z "$ENSUE_API_KEY" ] && { echo "Error: ENSUE_API_KEY not set"; exit 1; }

API_URL="https://api.ensue-network.ai/"
keys=("notes/meeting-jan" "notes/meeting-feb" "preferences/theme")

for key in "${keys[@]}"; do
  echo "=== $key ==="
  curl -s -X POST "$API_URL" \
    -H "Authorization: Bearer $ENSUE_API_KEY" \
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

## Context Optimization

**CRITICAL: Minimize context window usage.** Users may have 100k+ keys. Never dump large lists into the conversation.

### When users ask "what's on Ensue" / "show my memories" / "list keys"

**Do NOT** call `list_keys` with a large limit. Instead:

1. **Get a count first** using `list_keys` with `limit: 1`:
   ```bash
   curl -s -X POST https://api.ensue-network.ai/ \
     -H "Authorization: Bearer $ENSUE_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"list_keys","arguments":{"limit":1}},"id":1}'
   ```
   The response includes a `count` field with the total number of keys.

2. **Report the count and ask what they're looking for:**
   > "You have [N] memories stored. What would you like to find? I can search by topic or meaning."

3. **Use `discover_memories`** for semantic search instead of listing:
   ```bash
   curl -s -X POST https://api.ensue-network.ai/ \
     -H "Authorization: Bearer $ENSUE_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"discover_memories","arguments":{"query":"<user intent>","limit":10}},"id":1}'
   ```

4. **Only list keys with small limits** (5-10) when the user explicitly needs to browse, and paginate if needed.

### Prefer semantic search over listing

| Instead of... | Do this... |
|---------------|------------|
| `list_keys` with limit 100 | `discover_memories` with relevant query |
| Showing all keys | Report count, ask what they need |
| Paginating through everything | Search for what's relevant |

## Intent Mapping

| User says | Action |
|-----------|--------|
| "what can I do", "capabilities", "help" | Steps 1-2 only (summarize tools/list response) |
| "remember...", "save...", "store..." | create_memory |
| "what was...", "recall...", "get..." | get_memory or discover_memories |
| "search for...", "find..." | discover_memories or search_memories |
| "update...", "change..." | update_memory |
| "delete...", "remove..." | delete_memory ⚠️ |
| "list keys", "show memories", "what's on ensue" | Count first, then ask intent (see Context Optimization) |
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

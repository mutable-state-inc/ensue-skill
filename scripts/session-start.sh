#!/bin/bash
# Session start: validate API, check permissions, create header, cache tools

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
SOURCE=$(echo "$INPUT" | jq -r '.source')

# Check API key
if [ -z "$ENSUE_API_KEY" ]; then
  echo "not set" > /tmp/ensue-status-${SESSION_ID}
  exit 0
fi

# Persist env vars for subagents (so they can use the ensue-memory skill)
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo "export ENSUE_API_KEY=\"$ENSUE_API_KEY\"" >> "$CLAUDE_ENV_FILE"
  [ -n "$ENSUE_READONLY" ] && echo "export ENSUE_READONLY=\"$ENSUE_READONLY\"" >> "$CLAUDE_ENV_FILE"
fi

# Also write to a temp file for wrapper script (fallback for subagents)
# Use plugin directory to avoid polluting global namespace
ENSUE_KEY_FILE="${CLAUDE_PLUGIN_ROOT:-.}/.ensue-key"
echo "$ENSUE_API_KEY" > "$ENSUE_KEY_FILE"
chmod 600 "$ENSUE_KEY_FILE"

# Check if user wants read-only mode (no auto-logging)
if [ "$ENSUE_READONLY" = "true" ] || [ "$ENSUE_READONLY" = "1" ]; then
  echo "readonly" > /tmp/ensue-status-${SESSION_ID}
  if [ "$SOURCE" = "startup" ]; then
    echo '{"systemMessage": "\n\u001b[38;2;121;192;255m    ミ★  ✧ · ✦    ✦ · ✧  ☆彡\u001b[0m\n\u001b[38;2;136;136;136m        memories persist.\n        brilliance will \u001b[38;2;121;192;255m𝗲𝗻𝘀𝘂𝗲\u001b[38;2;136;136;136m.\u001b[0m\n\u001b[38;2;121;192;255m    ☆彡  ✧ · ✦    ✦ · ✧  ミ★\u001b[0m\n\n    📖  read-only mode (ENSUE_READONLY=true)\n"}'
  fi
  exit 0
fi

# On fresh startup
if [ "$SOURCE" = "startup" ]; then
  # Try to create session header and check permissions
  RESPONSE=$(curl -s -X POST https://api.ensue-network.ai/ \
    -H "Authorization: Bearer $ENSUE_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"create_memory\",\"arguments\":{\"items\":[{\"key_name\":\"sessions/${SESSION_ID}/header\",\"description\":\"Session $(date -u +%Y-%m-%dT%H:%M:%SZ) in $(pwd)\",\"value\":\"{\\\"started\\\":\\\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\\\",\\\"cwd\\\":\\\"$(pwd)\\\"}\",\"embed\":true}]}},\"id\":1}")

  # Check for errors in response (strip SSE "data: " prefix if present)
  JSON_RESPONSE=$(echo "$RESPONSE" | sed 's/^data: //')
  HAS_ERROR=$(echo "$JSON_RESPONSE" | jq -r '.error // .result.isError // false' 2>/dev/null)

  if [ "$HAS_ERROR" != "false" ] && [ "$HAS_ERROR" != "null" ] && [ -n "$HAS_ERROR" ]; then
    # Permission denied or other error - go into read-only mode
    echo "readonly" > /tmp/ensue-status-${SESSION_ID}
    echo '{"systemMessage": "\n\u001b[38;2;121;192;255m    ミ★  ✧ · ✦    ✦ · ✧  ☆彡\u001b[0m\n\u001b[38;2;136;136;136m        memories persist.\n        brilliance will \u001b[38;2;121;192;255m𝗲𝗻𝘀𝘂𝗲\u001b[38;2;136;136;136m.\u001b[0m\n\u001b[38;2;121;192;255m    ☆彡  ✧ · ✦    ✦ · ✧  ミ★\u001b[0m\n\n    ⚠️  read-only mode: no write permission to sessions/\n"}'
  else
    # All good - ready for full operation
    echo "ready" > /tmp/ensue-status-${SESSION_ID}
    echo '{"systemMessage": "\n\u001b[38;2;121;192;255m    ミ★  ✧ · ✦    ✦ · ✧  ☆彡\u001b[0m\n\u001b[38;2;136;136;136m        memories persist.\n        brilliance will \u001b[38;2;121;192;255m𝗲𝗻𝘀𝘂𝗲\u001b[38;2;136;136;136m.\u001b[0m\n\u001b[38;2;121;192;255m    ☆彡  ✧ · ✦    ✦ · ✧  ミ★\u001b[0m\n"}'
  fi

  # Cache tools list (background)
  curl -s -X POST https://api.ensue-network.ai/ \
    -H "Authorization: Bearer $ENSUE_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"tools/list","id":1}' > /tmp/ensue-tools-cache.json 2>/dev/null &
fi

exit 0

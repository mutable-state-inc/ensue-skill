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

# Check if user wants read-only mode (no auto-logging)
if [ "$ENSUE_READONLY" = "true" ] || [ "$ENSUE_READONLY" = "1" ]; then
  echo "readonly" > /tmp/ensue-status-${SESSION_ID}
  if [ "$SOURCE" = "startup" ]; then
    echo '{"systemMessage": "\n    ミ★  ✧ · ✦    ✦ · ✧  ☆彡\n        memories persist.\n        brilliance will 𝗲𝗻𝘀𝘂𝗲.\n    ☆彡  ✧ · ✦    ✦ · ✧  ミ★\n\n    📖  read-only mode (ENSUE_READONLY=true)\n"}'
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

  # Check for errors in response
  HAS_ERROR=$(echo "$RESPONSE" | jq -r '.error // .result.isError // false')

  if [ "$HAS_ERROR" != "false" ] && [ "$HAS_ERROR" != "null" ]; then
    # Permission denied or other error - go into read-only mode
    echo "readonly" > /tmp/ensue-status-${SESSION_ID}
    echo '{"systemMessage": "\n    ミ★  ✧ · ✦    ✦ · ✧  ☆彡\n        memories persist.\n        brilliance will 𝗲𝗻𝘀𝘂𝗲.\n    ☆彡  ✧ · ✦    ✦ · ✧  ミ★\n\n    ⚠️  read-only mode: no write permission to sessions/\n"}'
  else
    # All good - ready for full operation
    echo "ready" > /tmp/ensue-status-${SESSION_ID}
    echo '{"systemMessage": "\n    ミ★  ✧ · ✦    ✦ · ✧  ☆彡\n        memories persist.\n        brilliance will 𝗲𝗻𝘀𝘂𝗲.\n    ☆彡  ✧ · ✦    ✦ · ✧  ミ★\n"}'
  fi

  # Cache tools list (background)
  curl -s -X POST https://api.ensue-network.ai/ \
    -H "Authorization: Bearer $ENSUE_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"tools/list","id":1}' > /tmp/ensue-tools-cache.json 2>/dev/null &
fi

exit 0

#!/bin/bash
# Session start: validate API, create header, cache tools

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
SOURCE=$(echo "$INPUT" | jq -r '.source')

# Check API key
if [ -z "$ENSUE_API_KEY" ]; then
  echo "not set" > /tmp/ensue-status
  exit 0
fi

echo "ready" > /tmp/ensue-status

# On fresh startup
if [ "$SOURCE" = "startup" ]; then
  # Welcome message (JSON format for visible output)
  echo '{"systemMessage": "\n    ✧ · ✦ · ✧\n    memories persist. brilliance will ensue.\n    ✧ · ✦ · ✧\n"}'
  # Create session header (background)
  curl -s -X POST https://api.ensue-network.ai/ \
    -H "Authorization: Bearer $ENSUE_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"create_memory\",\"arguments\":{\"items\":[{\"key_name\":\"sessions/${SESSION_ID}/header\",\"description\":\"Session $(date -u +%Y-%m-%dT%H:%M:%SZ) in $(pwd)\",\"value\":\"{\\\"started\\\":\\\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\\\",\\\"cwd\\\":\\\"$(pwd)\\\"}\",\"embed\":true}]}},\"id\":1}" > /dev/null &

  # Cache tools list (background)
  curl -s -X POST https://api.ensue-network.ai/ \
    -H "Authorization: Bearer $ENSUE_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"tools/list","id":1}' > /tmp/ensue-tools-cache.json 2>/dev/null &
fi

exit 0

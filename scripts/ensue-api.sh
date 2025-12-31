#!/bin/bash
# Wrapper script for Ensue API calls
# Usage: ./scripts/ensue-api.sh <method> <json_args>
# Example: ./scripts/ensue-api.sh list_keys '{"limit":5}'

METHOD="$1"
ARGS="$2"

# Try env var first, fall back to key file (for subagents)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
ENSUE_KEY_FILE="$PLUGIN_ROOT/.ensue-key"

if [ -z "$ENSUE_API_KEY" ] && [ -f "$ENSUE_KEY_FILE" ]; then
  ENSUE_API_KEY=$(cat "$ENSUE_KEY_FILE")
fi

if [ -z "$ENSUE_API_KEY" ]; then
  echo '{"error":"ENSUE_API_KEY not set"}'
  exit 1
fi

if [ -z "$METHOD" ]; then
  echo '{"error":"No method specified"}'
  exit 1
fi

# Default empty args
[ -z "$ARGS" ] && ARGS='{}'

curl -s -X POST https://api.ensue-network.ai/ \
  -H "Authorization: Bearer $ENSUE_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"$METHOD\",\"arguments\":$ARGS},\"id\":1}" \
  | sed 's/^data: //'

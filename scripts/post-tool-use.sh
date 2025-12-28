#!/bin/bash
# PostToolUse: capture Claude's actions to the batch

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input')

[ -z "$ENSUE_API_KEY" ] && exit 0

# Check if in read-only mode
STATUS=$(cat /tmp/ensue-status-${SESSION_ID} 2>/dev/null)
[ "$STATUS" = "readonly" ] && exit 0
[ "$STATUS" = "not set" ] && exit 0

BATCH_FILE="/tmp/ensue-batch-${SESSION_ID}.jsonl"

# Append tool action to batch
TIMESTAMP=$(date +%s)
echo "{\"ts\":$TIMESTAMP,\"tool\":\"$TOOL_NAME\",\"input\":$TOOL_INPUT}" >> "$BATCH_FILE"

exit 0

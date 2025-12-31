#!/bin/bash
# PostToolUse: capture Claude's actions to the batch

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input')

[ -z "$ENSUE_API_KEY" ] && exit 0

# Check if in read-only mode (env var takes precedence, then status file)
[ "$ENSUE_READONLY" = "true" ] || [ "$ENSUE_READONLY" = "1" ] && exit 0
STATUS=$(cat /tmp/ensue-status-${SESSION_ID} 2>/dev/null)
[ -z "$STATUS" ] && exit 0
[ "$STATUS" = "readonly" ] && exit 0
[ "$STATUS" = "not set" ] && exit 0

BATCH_FILE="/tmp/ensue-batch-${SESSION_ID}.jsonl"

# Append tool action to batch
TIMESTAMP=$(date +%s)
PROMPT_TS=$(cat "/tmp/ensue-prompt-ts-${SESSION_ID}" 2>/dev/null || echo "0")
echo "{\"ts\":$TIMESTAMP,\"prompt_ts\":$PROMPT_TS,\"tool\":\"$TOOL_NAME\",\"input\":$TOOL_INPUT}" >> "$BATCH_FILE"

exit 0

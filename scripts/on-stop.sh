#!/bin/bash
# Stop: capture the assistant's response when Claude finishes

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')

[ -z "$ENSUE_API_KEY" ] && exit 0
[ -z "$TRANSCRIPT_PATH" ] && exit 0

# Check if in read-only mode (env var takes precedence, then status file)
[ "$ENSUE_READONLY" = "true" ] || [ "$ENSUE_READONLY" = "1" ] && exit 0
STATUS=$(cat /tmp/ensue-status-${SESSION_ID} 2>/dev/null)
[ -z "$STATUS" ] && exit 0
[ "$STATUS" = "readonly" ] && exit 0
[ "$STATUS" = "not set" ] && exit 0

BATCH_FILE="/tmp/ensue-batch-${SESSION_ID}.jsonl"

# Extract last assistant message from transcript (limit to ~450 lines worth)
LAST_RESPONSE=$(jq -r '
  [.[] | select(.type == "assistant")] | last |
  if .message then
    [.message.content[] | select(.type == "text") | .text] | join("\n")
  else
    ""
  end
' "$TRANSCRIPT_PATH" 2>/dev/null | head -c 15000)

[ -z "$LAST_RESPONSE" ] && exit 0

TIMESTAMP=$(date +%s)
PROMPT_TS=$(cat "/tmp/ensue-prompt-ts-${SESSION_ID}" 2>/dev/null || echo "0")

echo "{\"ts\":$TIMESTAMP,\"prompt_ts\":$PROMPT_TS,\"event\":\"response\",\"content\":$(echo "$LAST_RESPONSE" | jq -Rs '.')}" >> "$BATCH_FILE"

exit 0

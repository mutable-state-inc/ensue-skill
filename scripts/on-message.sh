#!/bin/bash
# UserPromptSubmit: batch user messages and flush to Ensue periodically

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
USER_PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')

[ -z "$ENSUE_API_KEY" ] && exit 0
[ -z "$USER_PROMPT" ] && exit 0

# Check if in read-only mode
STATUS=$(cat /tmp/ensue-status-${SESSION_ID} 2>/dev/null)
[ "$STATUS" = "readonly" ] && exit 0
[ "$STATUS" = "not set" ] && exit 0

BATCH_FILE="/tmp/ensue-batch-${SESSION_ID}.jsonl"
BATCH_THRESHOLD=10

# Append to batch
TIMESTAMP=$(date +%s)
echo "{\"ts\":$TIMESTAMP,\"msg\":$(echo "$USER_PROMPT" | jq -Rs '.[0:500]')}" >> "$BATCH_FILE"

# Count lines
COUNT=$(wc -l < "$BATCH_FILE" 2>/dev/null | tr -d ' ')

# Flush if threshold reached
if [ "$COUNT" -ge "$BATCH_THRESHOLD" ]; then
  bash "${SCRIPT_DIR}/flush-batch.sh" "$SESSION_ID" &
fi

exit 0

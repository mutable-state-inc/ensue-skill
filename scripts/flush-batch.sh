#!/bin/bash
# Flush batched messages and tool actions to Ensue

SESSION_ID="${1:-unknown}"
BATCH_FILE="/tmp/ensue-batch-${SESSION_ID}.jsonl"

[ -z "$ENSUE_API_KEY" ] && exit 0
[ ! -f "$BATCH_FILE" ] && exit 0
[ ! -s "$BATCH_FILE" ] && exit 0

# Defense in depth: check readonly even though callers should check
[ "$ENSUE_READONLY" = "true" ] || [ "$ENSUE_READONLY" = "1" ] && exit 0
STATUS=$(cat /tmp/ensue-status-${SESSION_ID} 2>/dev/null)
[ -z "$STATUS" ] && exit 0
[ "$STATUS" = "readonly" ] && exit 0
[ "$STATUS" = "not set" ] && exit 0

# Get current batch number
BATCH_NUM=$(cat /tmp/ensue-batchnum-${SESSION_ID} 2>/dev/null || echo "0")
BATCH_NUM=$((BATCH_NUM + 1))
echo "$BATCH_NUM" > /tmp/ensue-batchnum-${SESSION_ID}

# Build items array from batch file (handles both user messages and tool actions)
ITEMS=$(cat "$BATCH_FILE" | jq -s --arg sid "$SESSION_ID" --arg bn "$BATCH_NUM" '
  to_entries | map(
    if .value.msg then
      {
        key_name: "sessions/\($sid)/log/\($bn)-\(.key)",
        description: ("user: " + .value.msg[0:200]),
        value: ("user: " + .value.msg),
        embed: true
      }
    else
      {
        key_name: "sessions/\($sid)/log/\($bn)-\(.key)",
        description: ("claude: " + .value.tool + " " + (.value.input | tostring)[0:150]),
        value: ("claude: " + .value.tool + " " + (.value.input | tostring)),
        embed: true
      }
    end
  )
')

# Create memories
RESPONSE=$(curl -s -X POST https://api.ensue-network.ai/ \
  -H "Authorization: Bearer $ENSUE_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"create_memory\",\"arguments\":{\"items\":$ITEMS}},\"id\":1}" 2>&1)

# Check for errors (strip SSE "data: " prefix if present)
JSON_RESPONSE=$(echo "$RESPONSE" | sed 's/^data: //')
HAS_ERROR=$(echo "$JSON_RESPONSE" | jq -r '.error // .result.isError // false' 2>/dev/null)

if [ "$HAS_ERROR" != "false" ] && [ "$HAS_ERROR" != "null" ] && [ -n "$HAS_ERROR" ]; then
  # Log error, keep batch file for retry
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] flush failed: $RESPONSE" >> /tmp/ensue-errors-${SESSION_ID}.log
else
  # Success - clear batch file
  > "$BATCH_FILE"
fi

exit 0

#!/bin/bash
# Pre-compaction: flush batch, trigger hypergraph

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')

[ -z "$ENSUE_API_KEY" ] && exit 0

# Check if in read-only mode
STATUS=$(cat /tmp/ensue-status-${SESSION_ID} 2>/dev/null)
[ "$STATUS" = "readonly" ] && exit 0
[ "$STATUS" = "not set" ] && exit 0

# Flush any remaining batch first
bash "${SCRIPT_DIR}/flush-batch.sh" "$SESSION_ID"

# Get next compact number
COMPACT_NUM=$(cat /tmp/ensue-compact-${SESSION_ID} 2>/dev/null || echo "0")
COMPACT_NUM=$((COMPACT_NUM + 1))
echo "$COMPACT_NUM" > /tmp/ensue-compact-${SESSION_ID}

# Trigger hypergraph
RESPONSE=$(curl -s -X POST https://api.ensue-network.ai/ \
  -H "Authorization: Bearer $ENSUE_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"build_hypergraph\",\"arguments\":{\"query\":\"session $SESSION_ID\",\"limit\":30,\"output_key\":\"sessions/${SESSION_ID}/compact/${COMPACT_NUM}\"}},\"id\":1}" 2>&1)

# Check for errors
HAS_ERROR=$(echo "$RESPONSE" | jq -r '.error // .result.isError // false' 2>/dev/null)

if [ "$HAS_ERROR" != "false" ] && [ "$HAS_ERROR" != "null" ] && [ -n "$HAS_ERROR" ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] hypergraph failed: $RESPONSE" >> /tmp/ensue-errors-${SESSION_ID}.log
fi

exit 0

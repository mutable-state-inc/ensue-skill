#!/bin/bash
# Pre-compaction: flush batch, trigger hypergraph

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')

[ -z "$ENSUE_API_KEY" ] && exit 0

# Check if in read-only mode (env var takes precedence, then status file)
[ "$ENSUE_READONLY" = "true" ] || [ "$ENSUE_READONLY" = "1" ] && exit 0
STATUS=$(cat /tmp/ensue-status-${SESSION_ID} 2>/dev/null)
[ -z "$STATUS" ] && exit 0
[ "$STATUS" = "readonly" ] && exit 0
[ "$STATUS" = "not set" ] && exit 0

# Flush any remaining batch first
bash "${SCRIPT_DIR}/flush-batch.sh" "$SESSION_ID"

# Get next compact number
COMPACT_NUM=$(cat /tmp/ensue-compact-${SESSION_ID} 2>/dev/null || echo "0")
COMPACT_NUM=$((COMPACT_NUM + 1))
echo "$COMPACT_NUM" > /tmp/ensue-compact-${SESSION_ID}

# Trigger namespace hypergraph with semantic query for big ideas
NAMESPACE="sessions/${SESSION_ID}/"
OUTPUT_KEY="sessions/${SESSION_ID}/compact/${COMPACT_NUM}"
QUERY="key decisions, important realizations, problem-solving approaches, architectural choices, conceptual breakthroughs, reasoning patterns, and significant conclusions from this conversation segment"

RESPONSE=$(curl -s -X POST https://api.ensue-network.ai/ \
  -H "Authorization: Bearer $ENSUE_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"build_namespace_hypergraph\",\"arguments\":{\"namespace_path\":\"${NAMESPACE}\",\"query\":\"${QUERY}\",\"output_key\":\"${OUTPUT_KEY}\",\"limit\":50}},\"id\":1}" 2>&1)

# Check for errors (strip SSE "data: " prefix if present)
JSON_RESPONSE=$(echo "$RESPONSE" | sed 's/^data: //')
HAS_ERROR=$(echo "$JSON_RESPONSE" | jq -r '.error // .result.isError // false' 2>/dev/null)

if [ "$HAS_ERROR" != "false" ] && [ "$HAS_ERROR" != "null" ] && [ -n "$HAS_ERROR" ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] hypergraph failed: $RESPONSE" >> /tmp/ensue-errors-${SESSION_ID}.log
fi

exit 0

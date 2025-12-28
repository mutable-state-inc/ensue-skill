#!/bin/bash
# SessionEnd: flush remaining messages before exit

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')

[ -z "$ENSUE_API_KEY" ] && exit 0

# Check if in read-only mode
STATUS=$(cat /tmp/ensue-status-${SESSION_ID} 2>/dev/null)
[ "$STATUS" = "readonly" ] && exit 0
[ "$STATUS" = "not set" ] && exit 0

# Flush any remaining batch
bash "${SCRIPT_DIR}/flush-batch.sh" "$SESSION_ID"

exit 0

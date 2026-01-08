#!/usr/bin/env bash
# Repackage ensue-memory skill to include ensue-api.sh script - run from package root
# Run this from: fork-ensue-skill repository root
# Authored by Claude Sonnet 4.5.  Human verified

set -euo pipefail

# Verify we're in the correct directory (repo root)
if [[ ! -d "skills/ensue-memory" ]] || [[ ! -f "scripts/ensue-api.sh" ]]; then
    echo "ERROR: Must run from repository root containing skills/ensue-memory and scripts/ensue-api.sh" >&2
    exit 1
fi

# Create scripts directory in skill if it doesn't exist
mkdir -p skills/ensue-memory/scripts

# Copy ensue-api.sh into skill's scripts directory
cp scripts/ensue-api.sh skills/ensue-memory/scripts/ensue-api.sh
chmod +x skills/ensue-memory/scripts/ensue-api.sh
echo "Copied ensue-api.sh to skills/ensue-memory/scripts/ and set execute permissions"

echo ""
echo "Creating zip archive..."

# Create zip file in repo root
cd skills
zip -r ../ensue-memory.zip ensue-memory/
cd ..

echo ""
echo "Cleaning up temporary copy..."
rm -f skills/ensue-memory/scripts/ensue-api.sh
rmdir --ignore-fail-on-non-empty skills/ensue-memory/scripts 2>/dev/null || true

echo ""
echo "Repackaging complete!"
echo "  Skill suitable for Claude Assistant @ $(pwd)/ensue-memory.zip"

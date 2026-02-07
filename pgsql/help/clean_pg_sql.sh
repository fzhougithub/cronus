#!/bin/bash
# Validated sed-based cleanup (no hanging, macOS-compatible)
# Usage: ./clean_pg_sed.sh <input-sql-file> <output-cleaned-file>
set -euo pipefail

if [ $# -ne 2 ]; then
    echo "ERROR: Usage: $0 <input> <output>"
    exit 1
fi

INPUT="$1"
OUTPUT="$2"

if [ ! -f "$INPUT" ]; then
    echo "ERROR: Input file $INPUT does not exist"
    exit 1
fi

# Optimized sed (no backtracking, simple patterns, single pass)
sed -e '/ALTER TABLE ONLY .* REPLICA IDENTITY/Id' \
    -e '/ALTER TABLE ONLY .* ATTACH PARTITION/Id' \
    -e '/ALTER TABLE ONLY .* DETACH PARTITION/Id' \
    -e '/ALTER TABLE .* REPLICA IDENTITY/Id' \
    -e '/ALTER INDEX .* REPLICA IDENTITY/Id' \
    -e '/ALTER TABLE .* ATTACH PARTITION/Id' \
    -e '/ALTER INDEX .* ATTACH PARTITION/Id' \
    -e '/ALTER TABLE .* DETACH PARTITION/Id' \
    -e '/ALTER INDEX .* DETACH PARTITION/Id' \
    -e '/CREATE INDEX .* ON ONLY/Id' \
    -e '/-- .* INDEX ATTACH/Id' \
    "$INPUT" > "$OUTPUT"

# Validation
echo " sed cleanup done!"
PROBLEMS=$(grep -iE 'ONLY .* ATTACH PARTITION|ON ONLY|REPLICA IDENTITY' "$OUTPUT" | wc -l)
if [ "$PROBLEMS" -eq 0 ]; then
    echo "✓ No incompatible lines left"
else
    echo " Found $PROBLEMS problematic lines (review:)"
    grep -iE 'ONLY .* ATTACH PARTITION|ON ONLY|REPLICA IDENTITY' "$OUTPUT" | head -3
fi

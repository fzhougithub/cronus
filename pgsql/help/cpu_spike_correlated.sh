#!/bin/bash
# =====================================================================
# find_pg_log_v2.sh
# Correct version: selects the log file by day-of-month in its
# filename (matches Postgres's actual rotation naming), then filters
# INSIDE the file using each line's own timestamp — not file mtime.
# Handles plain, archived, and .gz rotated files; handles windows
# that span midnight/multiple days.
#
# Usage: ./find_pg_log_v2.sh "2026-09-25 11:00:00" "2026-09-25 12:30:00"
# =====================================================================

START_TS="$1"
END_TS="$2"

if [[ -z "$START_TS" || -z "$END_TS" ]]; then
    echo "Usage: $0 '<start timestamp>' '<end timestamp>'"
    exit 1
fi

DATA_DIR=$(sudo -u postgres psql -tA -c "SHOW data_directory;")
LOG_DIR_RAW=$(sudo -u postgres psql -tA -c "SHOW log_directory;")

if [[ "$LOG_DIR_RAW" == /* ]]; then
    FULL_LOG_DIR="$LOG_DIR_RAW"
else
    FULL_LOG_DIR="$DATA_DIR/$LOG_DIR_RAW"
fi

echo "Log directory: $FULL_LOG_DIR"

START_EPOCH=$(date -d "$START_TS" +%s)
END_EPOCH=$(date -d "$END_TS" +%s)

# Build the list of day-of-month values the window touches
# (handles ranges that cross midnight or span multiple days)
DAY_LIST=()
CUR_EPOCH=$START_EPOCH
while [[ $CUR_EPOCH -le $END_EPOCH ]]; do
    DAY_LIST+=("$(date -d "@$CUR_EPOCH" +%d)")
    CUR_EPOCH=$((CUR_EPOCH + 86400))
done
DAY_LIST=($(printf "%s\n" "${DAY_LIST[@]}" | sort -u))

echo "Day-of-month value(s) to check: ${DAY_LIST[*]}"
echo

for DAY in "${DAY_LIST[@]}"; do
    echo "--- Files matching day $DAY ---"
    ls -la "$FULL_LOG_DIR"/postgresql-"$DAY".log* 2>/dev/null
done

echo
echo "=== Log lines between $START_TS and $END_TS ==="
echo

for DAY in "${DAY_LIST[@]}"; do
    for FILE in "$FULL_LOG_DIR"/postgresql-"$DAY".log*; do
        [[ -e "$FILE" ]] || continue
        [[ -s "$FILE" ]] || continue   # skip empty/currently-active-but-blank files

        if [[ "$FILE" == *.gz ]]; then
            CAT_CMD="zcat"
        else
            CAT_CMD="cat"
        fi

        $CAT_CMD "$FILE" | awk -v start="$START_TS" -v end="$END_TS" '
            BEGIN {
                gsub(/[-:]/, " ", start)
                gsub(/[-:]/, " ", end)
                start_epoch = mktime(start)
                end_epoch   = mktime(end)
                in_range = 0
            }
            {
                # Default Postgres log_line_prefix starts with:
                # YYYY-MM-DD HH:MM:SS.mmm TZ
                if (match($0, /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/)) {
                    ts_str = substr($0, RSTART, 19)
                    gsub(/[-:]/, " ", ts_str)
                    line_epoch = mktime(ts_str)
                    in_range = (line_epoch >= start_epoch && line_epoch <= end_epoch)
                }
                # Non-timestamped lines are continuation/detail lines
                # belonging to the previous statement — keep them if
                # that statement was in range.
                if (in_range) print
            }
        '
    done
done

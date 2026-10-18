#!/bin/bash
#
# pg_wal_rescue.sh - get a PostgreSQL instance with a FULL data filesystem back up
#
# Run as the postgres OS user (or root) while PostgreSQL is STOPPED.
#
# Modes:
#   plan         PGDATA
#        Read-only. Shows checkpoint REDO file, which WAL segments are older than it
#        (= not needed for crash recovery), free space, archive_command target filesystems.
#
#   free         PGDATA ACTION TARGET_GB [DEST_DIR] [--execute]
#        Frees space from the OLDEST WAL segments only (older than the last checkpoint's REDO file,
#        and older than backup_label start if present). Stops as soon as TARGET_GB is free.
#        Without --execute it is a dry run.
#        ACTION:  move    move segments to DEST_DIR on ANOTHER filesystem (/, /tmp, NFS, ...)
#                 gzip    compress segments into DEST_DIR (can be same filesystem, frees ~70-80% each)
#                 delete  remove segments (no copy kept)
#        The matching archive_status .ready/.done markers are removed too, so the archiver
#        does not get stuck on a missing file.
#
#   base-growth  PGDATA [HOURS=24] [TOPN=40] [DB_OID]
#        Read-only. Works even with 100k+ files (no "Argument list too long").
#        Shows biggest relation files, files written in the last HOURS, pgsql_tmp usage.
#
#   hold-workers PGDATA on|off
#        on  = adds max_logical_replication_workers=0 to postgresql.auto.conf so no
#              subscription apply/tablesync worker can restart and refill the disk.
#        off = removes it again.
#
# Typical order:
#   ./pg_wal_rescue.sh plan         /apps/lib/pgsql/16/data
#   ./pg_wal_rescue.sh free         /apps/lib/pgsql/16/data move 30 /some/other/fs/wal_parking
#   ./pg_wal_rescue.sh free         /apps/lib/pgsql/16/data move 30 /some/other/fs/wal_parking --execute
#   ./pg_wal_rescue.sh hold-workers /apps/lib/pgsql/16/data on
#   (start PostgreSQL)
#   ./pg_wal_rescue.sh base-growth  /apps/lib/pgsql/16/data 24 40
#
# Set PGBIN=/usr/pgsql-16/bin if pg_controldata is not found automatically.

MODE="${1:-}"

die() { echo "ERROR: $*" >&2; exit 1; }
hdr() { echo; echo "=================== $* ==================="; }

find_pgbin() {
  if [ -n "$PGBIN" ] && [ -x "$PGBIN/pg_controldata" ]; then return 0; fi
  if command -v pg_controldata >/dev/null 2>&1; then
    PGBIN="$(dirname "$(command -v pg_controldata)")"; return 0
  fi
  for d in /usr/pgsql-16/bin /usr/lib/postgresql/16/bin /apps/pgsql*/bin /opt/pgsql*/bin /usr/pgsql-*/bin; do
    if [ -x "$d/pg_controldata" ]; then PGBIN="$d"; return 0; fi
  done
  return 1
}

need_pgdata() {
  PGDATA="$1"
  [ -n "$PGDATA" ] || die "PGDATA argument missing"
  [ -f "$PGDATA/PG_VERSION" ] || die "$PGDATA is not a PGDATA directory (no PG_VERSION)"
  WAL="$PGDATA/pg_wal"
  [ -d "$WAL" ] || die "$WAL not found"
}

pg_running() {
  [ -f "$PGDATA/postmaster.pid" ] || return 1
  local pid
  pid="$(head -1 "$PGDATA/postmaster.pid" 2>/dev/null)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

avail_kb() { df -Pk "$WAL/" | awk 'NR==2{print $4}'; }

# Sets: CTL REDO_FILE SEGSZ LOWER
get_bounds() {
  find_pgbin || die "pg_controldata not found. Run with PGBIN=/path/to/pg/bin"
  CTL="$("$PGBIN/pg_controldata" "$PGDATA" 2>&1)"
  REDO_FILE="$(echo "$CTL" | awk -F: '/REDO WAL file/ {gsub(/[ \t]/,"",$2); print $2}')"
  SEGSZ="$(echo "$CTL" | awk -F: '/Bytes per WAL segment/ {gsub(/[ \t]/,"",$2); print $2}')"
  [ -n "$SEGSZ" ] || SEGSZ=16777216
  [ -n "$REDO_FILE" ] || { echo "$CTL"; die "cannot read REDO WAL file from pg_controldata"; }
  LOWER="$REDO_FILE"
  BL=""
  if [ -f "$PGDATA/backup_label" ]; then
    BL="$(sed -n 's/^START WAL LOCATION:.*(file \([0-9A-F]\{24\}\)).*/\1/p' "$PGDATA/backup_label")"
    if [ -n "$BL" ] && [[ "$BL" < "$LOWER" ]]; then LOWER="$BL"; fi
  fi
}

list_all()   { find "$WAL" -maxdepth 1 -type f -regextype posix-extended -regex '.*/[0-9A-F]{24}' -printf '%f\n' | sort; }
# string comparison is forced with ("" concatenation) because all-digit names would otherwise be compared as numbers
list_cands() { list_all | awk -v lo="$LOWER" '($0 "") < (lo "")'; }

# ---------------------------------------------------------------- plan
do_plan() {
  need_pgdata "$1"
  get_bounds

  hdr "Instance state"
  if pg_running; then echo "WARNING: PostgreSQL is RUNNING (stop it before using 'free')"; else echo "PostgreSQL is stopped"; fi
  echo "$CTL" | grep -Ei 'cluster state|latest checkpoint location|REDO location|REDO WAL file|TimeLineID|wal_level'
  [ -f "$PGDATA/backup_label" ]   && echo "backup_label present, start segment: ${BL:-unknown}"
  [ -f "$PGDATA/recovery.signal" ] && echo "recovery.signal present"
  [ -f "$PGDATA/standby.signal" ]  && echo "standby.signal present"
  echo "Segments older than this file are NOT needed for crash recovery: $LOWER"

  hdr "Space"
  df -hP "$PGDATA" "$WAL/"
  [ -L "$WAL" ] && echo "pg_wal is a symlink -> $(readlink -f "$WAL")"

  hdr "WAL segments"
  total=$(list_all | wc -l)
  cands=$(list_cands | wc -l)
  keep=$((total - cands))
  echo "Total segments           : $total"
  echo "Removable (older)        : $cands  (~$(awk -v c="$cands" -v s="$SEGSZ" 'BEGIN{printf "%.1f", c*s/1073741824}') GB)"
  echo "Must keep (>= boundary)  : $keep  (~$(awk -v c="$keep" -v s="$SEGSZ" 'BEGIN{printf "%.1f", c*s/1073741824}') GB)"
  echo "archive_status .ready    : $(ls "$WAL/archive_status/" 2>/dev/null | grep -c '\.ready$')"
  echo "archive_status .done     : $(ls "$WAL/archive_status/" 2>/dev/null | grep -c '\.done$')"
  echo "First removable segment  : $(list_cands | head -1)"
  echo "Last removable segment   : $(list_cands | tail -1)"

  hdr "archive_command and where it writes"
  ACMD="$(grep -hEi '^[[:space:]]*archive_command' "$PGDATA/postgresql.auto.conf" "$PGDATA/postgresql.conf" 2>/dev/null | tail -1)"
  echo "${ACMD:-archive_command not found in conf files}"
  for p in $(echo "$ACMD" | grep -o '/[A-Za-z0-9_./-]*' | sort -u); do
    t="$p"; [ -e "$t" ] || t="$(dirname "$p")"
    [ -e "$t" ] && { echo "--- $p"; df -hP "$t" | tail -1; du -sh "$t" 2>/dev/null | tail -1; }
  done
  echo
  echo "If the archive target is on the same filesystem as PGDATA, that is why WAL piled up."

  hdr "Other places to park/free space"
  df -hP -x tmpfs -x devtmpfs 2>/dev/null
  command -v vgs >/dev/null && { echo; echo "--- LVM volume groups (VFree > 0 means you can lvextend -r)"; vgs 2>/dev/null; }
}

# ---------------------------------------------------------------- free
do_free() {
  need_pgdata "$1"
  ACTION="$2"; TARGET_GB="$3"
  shift 3 2>/dev/null
  DEST=""; EXEC=0
  for a in "$@"; do
    case "$a" in
      --execute) EXEC=1 ;;
      *)         DEST="$a" ;;
    esac
  done

  case "$ACTION" in move|gzip|delete) ;; *) die "ACTION must be move, gzip or delete" ;; esac
  [[ "$TARGET_GB" =~ ^[0-9]+$ ]] || die "TARGET_GB must be a whole number"
  if [ "$ACTION" != "delete" ] && [ -z "$DEST" ]; then die "$ACTION needs DEST_DIR"; fi

  get_bounds

  if [ -n "$DEST" ]; then
    mkdir -p "$DEST" || die "cannot create $DEST"
    case "$(readlink -f "$DEST")/" in
      "$(readlink -f "$WAL")"/*) die "DEST_DIR must not be inside pg_wal" ;;
    esac
    if [ "$ACTION" = "move" ] && [ "$(stat -c %d "$DEST")" = "$(stat -c %d "$WAL/")" ]; then
      die "DEST_DIR is on the SAME filesystem as pg_wal; 'move' would free nothing. Use 'gzip' or another filesystem."
    fi
  fi

  mapfile -t CANDS < <(list_cands)
  n=${#CANDS[@]}
  [ "$n" -gt 0 ] || die "No segments older than $LOWER - nothing safe to remove."

  have_kb=$(avail_kb)
  target_kb=$((TARGET_GB * 1024 * 1024))
  need_bytes=$(( (target_kb - have_kb) * 1024 ))

  echo "Boundary (keep this and newer): $LOWER"
  echo "Free now: $((have_kb/1024)) MB   Target: $((target_kb/1024)) MB   Removable segments: $n"

  if [ "$need_bytes" -le 0 ]; then echo "Already at or above target. Nothing to do."; exit 0; fi

  est=$(( (need_bytes + SEGSZ - 1) / SEGSZ ))
  [ "$ACTION" = "gzip" ] && est=$(( est * 4 / 3 + 1 ))
  [ "$est" -gt "$n" ] && est=$n

  if [ "$EXEC" -ne 1 ]; then
    echo
    echo "DRY RUN - would $ACTION about $est segment(s):"
    echo "   first: ${CANDS[0]}"
    echo "   last : ${CANDS[$((est-1))]}"
    [ "$est" -ge "$n" ] && echo "   (this is ALL removable segments and may still not reach the target)"
    echo "Re-run the same command with --execute to do it."
    exit 0
  fi

  pg_running && die "PostgreSQL is running. Stop it first."

  if [ "$ACTION" = "move" ]; then
    dest_kb=$(df -Pk "$DEST" | awk 'NR==2{print $4}')
    [ "$dest_kb" -gt $(( est * SEGSZ / 1024 )) ] || die "not enough space on $DEST for ~$est segments"
  fi

  i=0; cnt=0
  for f in "${CANDS[@]}"; do
    if [ $((i % 10)) -eq 0 ]; then
      have_kb=$(avail_kb)
      [ "$have_kb" -ge "$target_kb" ] && break
    fi
    i=$((i+1))

    case "$ACTION" in
      move)
        mv -f "$WAL/$f" "$DEST/$f" || { echo "ERROR: move failed for $f"; break; }
        ;;
      gzip)
        if gzip -1 -c "$WAL/$f" > "$DEST/$f.gz.partial" && mv -f "$DEST/$f.gz.partial" "$DEST/$f.gz"; then
          rm -f "$WAL/$f"
        else
          rm -f "$DEST/$f.gz.partial"
          echo "ERROR: gzip failed for $f (no room even for the compressed copy?). Free a few MB elsewhere or use 'move'/'delete'."
          break
        fi
        ;;
      delete)
        rm -f "$WAL/$f" || { echo "ERROR: delete failed for $f"; break; }
        ;;
    esac
    rm -f "$WAL/archive_status/$f.ready" "$WAL/archive_status/$f.done"
    cnt=$((cnt+1))
    [ $((cnt % 100)) -eq 0 ] && echo "  processed $cnt segments, free now $(( $(avail_kb)/1024 )) MB"
  done

  hdr "Result"
  echo "Segments processed: $cnt   (last: $f)"
  df -hP "$WAL/"
  echo "Segments still removable: $(list_cands | wc -l)"
  echo
  echo "NOTE: the WAL archive chain is now broken for point-in-time recovery."
  echo "      Take a new base backup once the instance is healthy."
}

# ---------------------------------------------------------------- base-growth
do_growth() {
  need_pgdata "$1"
  HOURS="${2:-24}"; TOPN="${3:-40}"; DBOID="$4"

  hdr "Databases (base/*)"
  du -sh "$PGDATA"/base/* 2>/dev/null | sort -rh | head -10

  hdr "Temp files (pgsql_tmp)"
  du -sh "$PGDATA"/base/pgsql_tmp "$PGDATA"/base/*/pgsql_tmp "$PGDATA"/pg_tblspc/*/*/pgsql_tmp 2>/dev/null
  echo "Tablespaces:"; ls -l "$PGDATA/pg_tblspc" 2>/dev/null

  if [ -z "$DBOID" ]; then
    DBOID="$(du -s "$PGDATA"/base/* 2>/dev/null | sort -rn | head -1 | awk '{n=split($2,a,"/"); print a[n]}')"
  fi
  DBDIR="$PGDATA/base/$DBOID"
  [ -d "$DBDIR" ] || die "$DBDIR not found"
  echo
  echo "Analysing database directory: $DBDIR (this can take a few minutes)"

  NOW="$(date +%s)"
  RESULT="$(find "$DBDIR" -maxdepth 1 -type f -printf '%s\t%T@\t%f\n' | awk -F'\t' -v now="$NOW" -v win=$((HOURS*3600)) '
    {
      key=$3
      sub(/\.[0-9]+$/,"",key)
      sub(/_(fsm|vm|init)$/,"",key)
      tot[key]+=$1; nf[key]++
      if ($2>mx[key]) mx[key]=$2
      if ($2>=now-win) { rec[key]+=$1; recn[key]++ }
      all+=$1; allf++
    }
    END {
      for (k in tot) printf "A\t%d\t%s\t%d\t%.1f\n", tot[k], k, nf[k], (now-mx[k])/3600
      for (k in rec) printf "R\t%d\t%s\t%d\t%.1f\n", rec[k], k, recn[k], (now-mx[k])/3600
      printf "T\t%d\ttotal\t%d\t0\n", all, allf
    }')"

  echo "$RESULT" | awk -F'\t' '$1=="T"{printf "Total in directory: %.1f GB in %d files\n",$2/1073741824,$4}'

  hdr "Top $TOPN relations by size (all forks and 1GB segments summed)"
  printf "%10s  %-22s %8s %12s\n" "GB" "filenode" "files" "last_write_h"
  echo "$RESULT" | awk -F'\t' '$1=="A"' | sort -t$'\t' -k2,2nr | head -n "$TOPN" | \
    awk -F'\t' '{printf "%10.1f  %-22s %8d %12s\n",$2/1073741824,$3,$4,$5}'

  hdr "Top $TOPN relations with files written in the last $HOURS h (growth suspects)"
  printf "%10s  %-22s %8s %12s\n" "GB_written" "filenode" "files" "last_write_h"
  echo "$RESULT" | awk -F'\t' '$1=="R"' | sort -t$'\t' -k2,2nr | head -n "$TOPN" | \
    awk -F'\t' '{printf "%10.1f  %-22s %8d %12s\n",$2/1073741824,$3,$4,$5}'

  TOPKEYS="$(echo "$RESULT" | awk -F'\t' '$1=="A" && $3 ~ /^[0-9]+$/' | sort -t$'\t' -k2,2nr | head -n "$TOPN" | awk -F'\t' '{print $3}' | paste -sd, -)"

  hdr "Run these once PostgreSQL is up (connect to the database with oid $DBOID)"
  cat <<EOF
-- which database is it:
select datname from pg_database where oid = $DBOID;

-- map the biggest filenodes to table/index names:
select n as filenode, pg_filenode_relation(0, n) as relation
from unnest(array[${TOPKEYS}]::oid[]) as n;

-- logical replication state (subscriber): tables still copying are not 'r'
select srsubid, srrelid::regclass, srsubstate from pg_subscription_rel where srsubstate <> 'r';
select subname, subenabled from pg_subscription;
select * from pg_stat_subscription;

-- who is writing right now:
select pid, usename, application_name, state, backend_type, now()-xact_start as xact_age, left(query,80)
from pg_stat_activity where state <> 'idle' order by xact_start;

-- orphan check hint: files that are big but not mapped by the query above
-- are leftovers of a failed CREATE INDEX / CTAS / initial table sync.
EOF
}

# ---------------------------------------------------------------- hold-workers
do_hold() {
  need_pgdata "$1"
  ACT="$2"
  AUTO="$PGDATA/postgresql.auto.conf"
  [ -f "$AUTO" ] || die "$AUTO not found"
  pg_running && die "Stop PostgreSQL first (the setting needs a restart anyway)."
  case "$ACT" in
    on)
      if grep -q '# PG_RESCUE_BEGIN' "$AUTO"; then echo "Already on."; return 0; fi
      cp -p "$AUTO" "$AUTO.bak.$(date +%Y%m%d%H%M%S)" || die "backup failed (disk full? free some space first)"
      {
        echo "# PG_RESCUE_BEGIN"
        echo "max_logical_replication_workers = '0'"
        echo "# PG_RESCUE_END"
      } >> "$AUTO" || die "append failed (disk full? free some space first)"
      echo "Logical replication workers disabled. After the instance is healthy run: hold-workers $PGDATA off"
      ;;
    off)
      cp -p "$AUTO" "$AUTO.bak.$(date +%Y%m%d%H%M%S)" || die "backup failed"
      sed '/# PG_RESCUE_BEGIN/,/# PG_RESCUE_END/d' "$AUTO" > "$AUTO.new" && cat "$AUTO.new" > "$AUTO" && rm -f "$AUTO.new"
      echo "Removed. Restart PostgreSQL for logical replication workers to come back."
      ;;
    *) die "use: hold-workers PGDATA on|off" ;;
  esac
  grep -n 'PG_RESCUE\|max_logical_replication_workers' "$AUTO"
}

case "$MODE" in
  plan)         do_plan   "$2" ;;
  free)         shift; do_free "$@" ;;
  base-growth)  shift; do_growth "$@" ;;
  hold-workers) do_hold   "$2" "$3" ;;
  *)            sed -n '2,41p' "$0"; exit 1 ;;
esac

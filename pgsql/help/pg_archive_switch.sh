#!/bin/bash
#
# pg_archive_switch.sh - temporarily disable real WAL archiving (archive_command = '/bin/true')
#                        and switch back to the original command later.
#
# Usage:
#   pg_archive_switch.sh PGDATA off      archive_command = '/bin/true'  (segments are marked archived at once, then recycled)
#   pg_archive_switch.sh PGDATA on       remove the override -> original archive_command (pgbackrest) is active again
#   pg_archive_switch.sh PGDATA status   show effective settings and archiver state
#
# The override is a marked block appended to postgresql.auto.conf (last entry wins).
# A timestamped backup of postgresql.auto.conf is made each time.
# Works with PostgreSQL stopped (take effect at start) or running (the script reloads the config).
#
# WARNING: while 'off' is active there is NO WAL archive, so no point-in-time recovery and
#          pgbackrest check/backup of WAL will not work. Take a new full backup after switching 'on'.

PGDATA="${1:-}"
ACT="${2:-}"
BEGIN_MARK="# PG_ARCHIVE_SWITCH_BEGIN"
END_MARK="# PG_ARCHIVE_SWITCH_END"

die() { echo "ERROR: $*" >&2; exit 1; }

[ -n "$PGDATA" ] && [ -n "$ACT" ] || { sed -n '2,17p' "$0"; exit 1; }
[ -f "$PGDATA/PG_VERSION" ] || die "$PGDATA is not a PGDATA directory"
AUTO="$PGDATA/postgresql.auto.conf"
[ -f "$AUTO" ] || die "$AUTO not found"

is_running() {
  [ -f "$PGDATA/postmaster.pid" ] || return 1
  local pid
  pid="$(head -1 "$PGDATA/postmaster.pid" 2>/dev/null)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

reload_if_running() {
  if is_running; then
    if command -v psql >/dev/null 2>&1; then
      psql -X -d postgres -Atc "select pg_reload_conf();" 2>/dev/null | sed 's/^t$/Configuration reloaded./'
    else
      echo "PostgreSQL is running: reload it yourself (systemctl reload postgresql-16 or pg_ctl reload)."
    fi
  else
    echo "PostgreSQL is stopped: the setting takes effect at the next start."
  fi
}

show_conf() {
  echo "--- archive settings in config files"
  grep -nEi '^[[:space:]]*(archive_mode|archive_command|archive_library|wal_level|max_logical_replication_workers)[[:space:]]*=' \
       "$PGDATA/postgresql.conf" "$AUTO" 2>/dev/null
  grep -q "$BEGIN_MARK" "$AUTO" && echo "--- override block is PRESENT (archiving is OFF)" || echo "--- override block not present"
}

case "$ACT" in
  off)
    if grep -q "$BEGIN_MARK" "$AUTO"; then
      echo "Already off."
    else
      cp -p "$AUTO" "$AUTO.bak.$(date +%Y%m%d%H%M%S)" || die "backup failed (disk full?)"
      {
        echo "$BEGIN_MARK"
        echo "archive_command = '/bin/true'"
        echo "$END_MARK"
      } >> "$AUTO" || die "append failed (disk full?)"
      echo "archive_command overridden with /bin/true"
    fi
    show_conf
    reload_if_running
    echo
    echo "After start/reload run  CHECKPOINT;  so old segments are recycled, then watch:  df -h /apps /pg_wal"
    ;;
  on)
    if ! grep -q "$BEGIN_MARK" "$AUTO"; then
      echo "Override not present, nothing to remove."
    else
      cp -p "$AUTO" "$AUTO.bak.$(date +%Y%m%d%H%M%S)" || die "backup failed"
      sed "/$BEGIN_MARK/,/$END_MARK/d" "$AUTO" > "$AUTO.new" && cat "$AUTO.new" > "$AUTO" && rm -f "$AUTO.new"
      echo "Override removed: original archive_command is active again."
    fi
    show_conf
    reload_if_running
    echo
    echo "Now: pgbackrest --stanza=<name> check   and take a new full backup."
    ;;
  status)
    show_conf
    if is_running && command -v psql >/dev/null 2>&1; then
      echo
      psql -X -d postgres -c "select name, setting from pg_settings where name in ('archive_mode','archive_command','wal_level','max_logical_replication_workers');"
      psql -X -d postgres -c "select archived_count, failed_count, last_archived_wal, last_failed_wal, last_failed_time from pg_stat_archiver;"
      psql -X -d postgres -c "select count(*) as wal_files, pg_size_pretty(sum(size)) as wal_size from pg_ls_waldir();"
    fi
    ;;
  *) die "action must be off, on or status" ;;
esac

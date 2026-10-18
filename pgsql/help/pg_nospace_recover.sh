#!/bin/bash
#
# pg_nospace_recover.sh - PostgreSQL "No space left on device" recovery helper
#
# Modes:
#   diagnose    PGDATA                 read-only: shows what is eating the disk (safe, run first)
#   clean-safe  PGDATA                 frees space from safe places only (journal, pkg cache, old logs)
#   relocate    PGDATA NEW_WAL_DIR     moves pg_wal to another volume and symlinks it (PG must be stopped)
#   post        [psql options...]      after PG is up: slots, archiver, WAL settings, remediation hints
#
# It NEVER deletes anything inside pg_wal and NEVER runs pg_resetwal.
#
# Examples:
#   ./pg_nospace_recover.sh diagnose   /var/lib/postgresql/16/main
#   ./pg_nospace_recover.sh clean-safe /var/lib/postgresql/16/main
#   ./pg_nospace_recover.sh relocate   /var/lib/postgresql/16/main /mnt/bigdisk/pg_wal
#   ./pg_nospace_recover.sh post       -U postgres

MODE="${1:-}"
LOG_RETENTION_DAYS=7
JOURNAL_MAX="200M"
EXTRA_FREE_GB=2

die()  { echo "ERROR: $*" >&2; exit 1; }
hdr()  { echo; echo "=================== $* ==================="; }

need_pgdata() {
  PGDATA="$1"
  [ -n "$PGDATA" ] || die "PGDATA argument missing"
  [ -f "$PGDATA/PG_VERSION" ] || die "$PGDATA does not look like a PGDATA directory (no PG_VERSION)"
  PGUSER_OS="$(stat -c %U "$PGDATA")"
}

pg_running() {
  [ -f "$PGDATA/postmaster.pid" ] || return 1
  local pid
  pid="$(head -1 "$PGDATA/postmaster.pid" 2>/dev/null)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

do_diagnose() {
  need_pgdata "$1"

  hdr "Filesystems"
  df -hP "$PGDATA" "$PGDATA/pg_wal" / /tmp /var/log 2>/dev/null | sort -u
  echo; echo "--- inodes ---"
  df -iP "$PGDATA" "$PGDATA/pg_wal" 2>/dev/null | sort -u

  hdr "pg_wal"
  if [ -L "$PGDATA/pg_wal" ]; then echo "pg_wal is a symlink -> $(readlink -f "$PGDATA/pg_wal")"; fi
  echo "Size       : $(du -sh "$PGDATA/pg_wal/" 2>/dev/null | cut -f1)"
  echo "Segments   : $(ls "$PGDATA/pg_wal/" 2>/dev/null | grep -cE '^[0-9A-F]{24}$')"
  echo ".ready (waiting for archive): $(ls "$PGDATA/pg_wal/archive_status/" 2>/dev/null | grep -c '\.ready$')"
  echo ".done                       : $(ls "$PGDATA/pg_wal/archive_status/" 2>/dev/null | grep -c '\.done$')"
  echo "Temp files (xlogtemp.*)     : $(ls "$PGDATA/pg_wal/" 2>/dev/null | grep -c '^xlogtemp')"

  hdr "Replication slots on disk (pg_replslot) - big/old slots hold WAL"
  if [ -d "$PGDATA/pg_replslot" ]; then
    for d in "$PGDATA"/pg_replslot/*/; do
      [ -d "$d" ] || continue
      echo "$(basename "$d")  size=$(du -sh "$d" | cut -f1)  modified=$(stat -c %y "$d" | cut -d. -f1)"
    done
    [ -z "$(ls -A "$PGDATA/pg_replslot" 2>/dev/null)" ] && echo "(no slots)"
  fi

  hdr "PGDATA top-level usage"
  du -sh "$PGDATA"/* 2>/dev/null | sort -rh | head -15

  hdr "Relevant settings (postgresql.conf / auto.conf)"
  grep -HEi '^\s*(archive_mode|archive_command|wal_level|max_wal_size|min_wal_size|wal_keep_size|max_slot_wal_keep_size|log_directory|log_destination|logging_collector|data_directory)\s*=' \
      "$PGDATA/postgresql.conf" "$PGDATA/postgresql.auto.conf" 2>/dev/null
  for f in /etc/postgresql/*/*/postgresql.conf; do
    [ -f "$f" ] && grep -HEi '^\s*(archive_mode|archive_command|max_wal_size|wal_keep_size|max_slot_wal_keep_size|log_directory)\s*=' "$f"
  done

  hdr "Control file"
  PGCTL_BIN="$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)"
  if command -v pg_controldata >/dev/null 2>&1; then
    pg_controldata "$PGDATA" 2>/dev/null | grep -Ei 'state|checkpoint location|REDO location|wal_level|timeline'
  elif [ -x "$PGCTL_BIN/pg_controldata" ]; then
    "$PGCTL_BIN/pg_controldata" "$PGDATA" 2>/dev/null | grep -Ei 'state|checkpoint location|REDO location|wal_level|timeline'
  fi

  hdr "Other big consumers on the same filesystem (top 25 files > 200MB)"
  find "$(dirname "$PGDATA")" / -xdev -type f -size +200M -not -path "$PGDATA/base/*" \
       -printf '%s\t%p\n' 2>/dev/null | sort -u | sort -rn | head -25 | \
       awk -F'\t' '{printf "%8.1f MB  %s\n", $1/1048576, $2}'

  hdr "Directories: /var/log, /var/lib, /tmp, /home, /var/backups, /var/cache"
  du -xsh /var/log /var/lib/* /tmp /home /var/backups /var/cache 2>/dev/null | sort -rh | head -15
  command -v journalctl >/dev/null && echo "journal: $(journalctl --disk-usage 2>/dev/null)"

  hdr "Deleted-but-still-open files (space not released)"
  command -v lsof >/dev/null && lsof -nP +L1 2>/dev/null | awk 'NR==1 || $7>104857600' | head -20

  hdr "Reserved blocks (ext4 only)"
  DEV="$(df -P "$PGDATA" | awk 'NR==2{print $1}')"
  command -v tune2fs >/dev/null && tune2fs -l "$DEV" 2>/dev/null | grep -Ei 'reserved block count|block count|block size'
  echo
  echo "NEXT: ./$(basename "$0") clean-safe $PGDATA   (or relocate to a bigger volume)"
}

do_clean_safe() {
  need_pgdata "$1"
  pg_running && echo "NOTE: PostgreSQL appears to be running."

  hdr "Before"
  df -hP "$PGDATA"

  if command -v journalctl >/dev/null; then
    echo "Vacuuming systemd journal to $JOURNAL_MAX"
    journalctl --vacuum-size="$JOURNAL_MAX" 2>/dev/null | tail -2
  fi

  if command -v apt-get >/dev/null; then echo "apt clean";  apt-get clean 2>/dev/null; fi
  if command -v dnf >/dev/null;     then echo "dnf clean";  dnf clean all 2>/dev/null; fi
  if command -v yum >/dev/null && ! command -v dnf >/dev/null; then echo "yum clean"; yum clean all 2>/dev/null; fi

  echo "Removing rotated/compressed system logs"
  find /var/log -type f \( -name '*.gz' -o -name '*.[0-9]' -o -name '*.old' -o -name '*.xz' \) -delete 2>/dev/null

  echo "Removing PostgreSQL text logs older than $LOG_RETENTION_DAYS days"
  for d in "$PGDATA/log" "$PGDATA/pg_log" /var/log/postgresql; do
    [ -d "$d" ] && find "$d" -type f \( -name '*.log' -o -name '*.log.*' -o -name '*.csv' -o -name '*.json' -o -name '*.gz' \) \
                         -mtime +"$LOG_RETENTION_DAYS" -print -delete
  done

  echo "Removing old core dumps"
  find /var/lib/systemd/coredump /var/crash -type f -mtime +1 -delete 2>/dev/null

  hdr "After"
  df -hP "$PGDATA"
  echo
  echo "Free space needed to finish recovery: at least a few GB (more if pg_wal is huge)."
  echo "If still too small, use: relocate $PGDATA /path/on/bigger/volume"
}

do_relocate() {
  need_pgdata "$1"
  NEWWAL="$2"
  [ -n "$NEWWAL" ] || die "usage: relocate PGDATA NEW_WAL_DIR"
  pg_running && die "PostgreSQL is running. Stop it first (systemctl stop postgresql)."
  [ -L "$PGDATA/pg_wal" ] && die "pg_wal is already a symlink -> $(readlink -f "$PGDATA/pg_wal")"
  [ -d "$PGDATA/pg_wal" ] || die "$PGDATA/pg_wal not found"

  mkdir -p "$NEWWAL" || die "cannot create $NEWWAL"
  [ -z "$(ls -A "$NEWWAL")" ] || die "$NEWWAL is not empty"

  NEED_KB=$(( $(du -sk "$PGDATA/pg_wal" | cut -f1) + EXTRA_FREE_GB*1024*1024 ))
  HAVE_KB=$(df -Pk "$NEWWAL" | awk 'NR==2{print $4}')
  echo "pg_wal size + ${EXTRA_FREE_GB}GB headroom needed: $((NEED_KB/1024)) MB, available on target: $((HAVE_KB/1024)) MB"
  [ "$HAVE_KB" -ge "$NEED_KB" ] || die "not enough space on target volume"

  chown "$PGUSER_OS":"$(stat -c %G "$PGDATA")" "$NEWWAL"
  chmod 700 "$NEWWAL"

  echo "Copying pg_wal -> $NEWWAL (original is kept as pg_wal.old until you confirm)"
  if command -v rsync >/dev/null; then
    rsync -a "$PGDATA/pg_wal/" "$NEWWAL/" || die "rsync failed - original untouched"
  else
    cp -a "$PGDATA/pg_wal/." "$NEWWAL/" || die "cp failed - original untouched"
  fi

  mv "$PGDATA/pg_wal" "$PGDATA/pg_wal.old" || die "rename failed"
  ln -s "$NEWWAL" "$PGDATA/pg_wal"
  chown -h "$PGUSER_OS":"$(stat -c %G "$PGDATA")" "$PGDATA/pg_wal"

  echo
  echo "Done. Start PostgreSQL now:   systemctl start postgresql   (or your service name)"
  echo "Watch the log until it accepts connections, then free the old copy:"
  echo "    rm -rf $PGDATA/pg_wal.old"
  echo "Then run:  $(basename "$0") post"
  df -hP "$PGDATA" "$NEWWAL"
}

do_post() {
  shift_args=("$@")
  PSQL=(psql -X -v ON_ERROR_STOP=0 "${shift_args[@]}" -d postgres)
  "${PSQL[@]}" -c "select 1" >/dev/null 2>&1 || die "cannot connect with psql ${shift_args[*]} (is PG up?)"

  hdr "Replication slots (inactive + large retained WAL = the usual culprit)"
  "${PSQL[@]}" -c "
    select slot_name, slot_type, database, active,
           pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) as retained_wal,
           wal_status
    from pg_replication_slots
    order by pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) desc nulls last;"

  hdr "Archiver"
  "${PSQL[@]}" -c "select archived_count, failed_count, last_archived_wal, last_failed_wal, last_failed_time from pg_stat_archiver;"

  hdr "WAL settings"
  "${PSQL[@]}" -c "select name, setting, unit from pg_settings
                   where name in ('archive_mode','archive_command','wal_level','max_wal_size','min_wal_size',
                                  'wal_keep_size','max_slot_wal_keep_size','max_wal_senders');"

  hdr "WAL directory size"
  "${PSQL[@]}" -c "select count(*) as files, pg_size_pretty(sum(size)) as total from pg_ls_waldir();"

  hdr "Replication origins / subscriptions (if this is a subscriber)"
  "${PSQL[@]}" -c "select subname, subenabled from pg_subscription;" 2>/dev/null

  echo
  echo "REMEDIATION (run manually after you decide - the script does not do this for you):"
  echo "  * Dead consumer slot : select pg_drop_replication_slot('<slot_name>');"
  echo "  * Failing archive    : fix archive_command target / permissions, then pg_stat_archiver failed_count must stop growing"
  echo "  * Safety net         : alter system set max_slot_wal_keep_size = '50GB'; select pg_reload_conf();"
  echo "  * After cleanup      : checkpoint;   (WAL is recycled/removed automatically)"
  echo "  * Monitoring         : alert on filesystem > 80% and on inactive slots"
}

case "$MODE" in
  diagnose)   do_diagnose   "$2" ;;
  clean-safe) do_clean_safe "$2" ;;
  relocate)   do_relocate   "$2" "$3" ;;
  post)       shift; do_post "$@" ;;
  *) sed -n '2,16p' "$0"; exit 1 ;;
esac

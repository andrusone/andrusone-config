#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# hanoi_rotate_backups.sh
# Move archives ONLY when today is 1) first-of-year, 2) first-of-quarter,
# 3) first-of-month, or 4) first-of-week (priority in that order).
# Otherwise: purge BASE/staging AND delete any ready (.done) archives in SRC.
# Uses .done gating to avoid moving half-written files.
# ------------------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# --- CONFIG -------------------------------------------------------------------
BASE="/mnt/HDD-RZ1-01/HDD-RZ1-ENC-CLOUD-01"
SRC="${BASE}"                         # where .tar/.tar.gz + .done appear
STAGING="${BASE}/staging"             # only this gets purged recursively
SYNC="${BASE}/sync"

DIR_YEARLY="${SYNC}/yearly"
DIR_QUARTERLY="${SYNC}/quarterly"
DIR_MONTHLY="${SYNC}/monthly"
DIR_WEEKLY="${SYNC}/weekly"

KEEP_YEARLY=2
KEEP_QUARTERLY=4
KEEP_MONTHLY=4
KEEP_WEEKLY=14

# Week start config: "SUNDAY" (default) or "MONDAY"
WEEK_START="${WEEK_START:-SUNDAY}"

MAX_RETRIES=13
SLEEP_SECS=$((60*60))

DEST=""
KEEP_COUNT=0

# --- OPTIONS ------------------------------------------------------------------
QUIET=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -q|--quiet) QUIET=1 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

# --- HELPERS ------------------------------------------------------------------
log() { (( QUIET )) && return; printf "[%s] %s\n" "$(date +'%F %T')" "$*" >&2; }
ensure_dirs() { mkdir -p "$DIR_YEARLY" "$DIR_QUARTERLY" "$DIR_MONTHLY" "$DIR_WEEKLY"; }

prune_keep_newest() {
  local target_dir="$1" keep_count="$2"
  mapfile -d '' files_to_delete < <(
    find "$target_dir" -maxdepth 1 -type f \
      \( -name '*.tar' -o -name '*.tar.gz' \) \
      -printf '%T@ %p\0' | sort -rz -k1,1nr |
      awk -v k="$keep_count" -v RS='\0' 'NR>k { sub(/^[0-9.]+ /,"",$0); printf "%s\0",$0 }'
  )
  if (( ${#files_to_delete[@]} > 0 )); then
    log "Pruning $((${#files_to_delete[@]})) old file(s) in $target_dir (keep $keep_count)"
    while IFS= read -r -d '' f; do
      log "  rm -f -- $f"; rm -f -- "$f"
    done < <(printf '%s\0' "${files_to_delete[@]}")
  else
    log "No pruning needed in $target_dir."
  fi
}

is_first_day_of_year()    { [[ "$(date +%m%d)" == "0101" ]]; }
is_first_day_of_quarter() { local m d; m=$(date +%m); d=$(date +%d); [[ "$d" == "01" && ( "$m" == "01" || "$m" == "04" || "$m" == "07" || "$m" == "10" ) ]]; }
is_first_day_of_month()   { [[ "$(date +%d)" == "01" ]]; }
is_first_day_of_week() {
  # GNU date: %u (1=Mon..7=Sun)
  local dow; dow="$(date +%u)"
  if [[ "$WEEK_START" == "MONDAY" ]]; then [[ "$dow" == "1" ]]; else [[ "$dow" == "7" ]]; fi
}

# Priority selection: Yearly > Quarterly > Monthly > Weekly
pick_destination() {
  if   is_first_day_of_year;    then DEST="$DIR_YEARLY";    KEEP_COUNT=$KEEP_YEARLY
  elif is_first_day_of_quarter; then DEST="$DIR_QUARTERLY"; KEEP_COUNT=$KEEP_QUARTERLY
  elif is_first_day_of_month;   then DEST="$DIR_MONTHLY";   KEEP_COUNT=$KEEP_MONTHLY
  elif is_first_day_of_week;    then DEST="$DIR_WEEKLY";    KEEP_COUNT=$KEEP_WEEKLY
  else                               DEST="";               KEEP_COUNT=0
  fi
}

should_move_today() {
  is_first_day_of_year || is_first_day_of_quarter || is_first_day_of_month || is_first_day_of_week
}

wait_for_done_files() {
  local retries=0
  while true; do
    local missing=0; shopt -s nullglob
    for f in "${SRC}"/*.tar "${SRC}"/*.tar.gz; do
      [[ -e "$f" ]] || continue
      [[ -f "${f}.done" ]] || { log "Waiting for .done: $f"; missing=1; }
    done
    shopt -u nullglob
    (( missing == 0 )) && { log "All archives have .done markers."; return 0; }
    (( retries++ ))
    if (( retries > MAX_RETRIES )); then log "ERROR: .done not found after $MAX_RETRIES retries."; exit 1; fi
    log "Retry $retries/$MAX_RETRIES after $SLEEP_SECS sec..."; sleep "$SLEEP_SECS"
  done
}

move_archives() {
  local dest_dir="$1"; shopt -s nullglob; local moved=0
  for f in "${SRC}"/*.tar "${SRC}"/*.tar.gz; do
    [[ -e "$f" && -f "${f}.done" ]] || continue
    log "Moving: $f -> $dest_dir/"
    if mv -f -- "$f" "$dest_dir/"; then rm -f -- "${f}.done"; ((moved++))
    else log "ERROR: mv failed for $f (leaving .done)"; fi
  done
  shopt -u nullglob; echo "$moved"
}

purge_staging_dir() {
  if [[ -z "${STAGING:-}" || "$STAGING" == "/" ]]; then log "Refusing to purge: invalid STAGING='$STAGING'"; return 1; fi
  [[ -d "$STAGING" ]] || { log "No staging dir at $STAGING (nothing to purge)"; return 0; }
  shopt -s dotglob nullglob; local removed=0
  for path in "$STAGING"/*; do
    [[ -e "$path" ]] || continue
    log "Purging staging item: $path"; rm -rf -- "$path"; ((removed++))
  done
  shopt -u dotglob nullglob; echo "$removed"
}

# NEW (Option B): also delete ready (.done) archives from SRC on non-move days
purge_src_archives_nonmove() {
  shopt -s nullglob
  local removed=0
  for f in "${SRC}"/*.tar "${SRC}"/*.tar.gz; do
    [[ -e "${f}.done" ]] || continue
    log "Purging non-move day archive: $f"
    rm -f -- "${f}" "${f}.done"
    ((removed++))
  done
  shopt -u nullglob
  echo "$removed"
}

# --- MAIN ---------------------------------------------------------------------
log "---- Hanoi rotate run starting ----"
ensure_dirs
pick_destination

if ! should_move_today; then
  log "Today is not Y/Q/M/W threshold; skipping moves."
  purged_src="$(purge_src_archives_nonmove || true)"
  purged_staging="$(purge_staging_dir || true)"
  (( QUIET )) || log "Purged ${purged_src:-0} file(s) from ${SRC} and ${purged_staging:-0} item(s) from ${STAGING}."
  log "---- Hanoi rotate run complete (purge-only) ----"; exit 0
fi

# Move path
shopt -s nullglob; pending=( "${SRC}"/*.tar "${SRC}"/*.tar.gz ); shopt -u nullglob
if (( ${#pending[@]} == 0 )); then
  log "Move day but no .tar/.tar.gz in ${SRC}. Purging staging only."
  purged_staging="$(purge_staging_dir || true)"
  (( QUIET )) || log "Purged ${purged_staging:-0} item(s) from ${STAGING}."
  log "---- Hanoi rotate run complete ----"; exit 0
fi

wait_for_done_files

if [[ -z "${DEST}" || "${KEEP_COUNT}" -le 0 ]]; then
  log "ERROR: Destination/KEEP_COUNT not set. Aborting."; exit 1
fi
log "Destination: $DEST (keep $KEEP_COUNT)"

moved_count="$(move_archives "$DEST")"
if (( moved_count > 0 )); then
  log "Moved $moved_count file(s) to $DEST."
  log "Pruning $DEST to keep newest $KEEP_COUNT file(s)."
  prune_keep_newest "$DEST" "$KEEP_COUNT"
else
  log "No files moved (no .done or race)."
fi

purged_staging="$(purge_staging_dir || true)"
(( QUIET )) || log "Purged ${purged_staging:-0} item(s) from ${STAGING}."
log "---- Hanoi rotate run complete ----"

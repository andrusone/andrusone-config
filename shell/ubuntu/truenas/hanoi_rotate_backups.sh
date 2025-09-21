#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# hanoi_rotate_backups.sh
#
# Daily rotation with .done gating and Tower-of-Hanoi tiers:
#   Priority (exclusive): Yearly > Quarterly > Monthly -> else Weekly (default)
#
# Retention: yearly=2, quarterly=4, monthly=4, weekly=14
# Waits up to 13 hours for *.done markers if .tar(.gz) files exist.
# ------------------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# --- CONFIG -------------------------------------------------------------------
BASE="/mnt/HDD-RZ1-01/HDD-RZ1-ENC-CLOUD-01"
SRC="${BASE}"                         # where new .tar/.tar.gz files appear
SYNC="${BASE}/sync"

DIR_YEARLY="${SYNC}/yearly"
DIR_QUARTERLY="${SYNC}/quarterly"
DIR_MONTHLY="${SYNC}/monthly"
DIR_WEEKLY="${SYNC}/weekly"

KEEP_YEARLY=2
KEEP_QUARTERLY=4
KEEP_MONTHLY=4
KEEP_WEEKLY=14

MAX_RETRIES=13                 # 13 hourly retries
SLEEP_SECS=$((60*60))          # 1 hour

# Globals set by pick_destination()
DEST=""
KEEP_COUNT=0

# --- HELPERS ------------------------------------------------------------------

# Send logs to stderr to keep stdout clean for numeric outputs
log() { printf "[%s] %s\n" "$(date +'%F %T')" "$*" >&2; }

ensure_dirs() {
  mkdir -p "$DIR_YEARLY" "$DIR_QUARTERLY" "$DIR_MONTHLY" "$DIR_WEEKLY"
}

prune_keep_newest() {
  local target_dir="$1"
  local keep_count="$2"

  mapfile -d '' files_to_delete < <(
    find "$target_dir" -maxdepth 1 -type f \
      \( -name '*.tar' -o -name '*.tar.gz' \) \
      -printf '%T@ %p\0' \
    | sort -rz -k1,1nr \
    | awk -v k="$keep_count" -v RS='\0' 'NR>k { sub(/^[0-9.]+ /,"",$0); printf "%s\0", $0 }'
  )

  if (( ${#files_to_delete[@]} > 0 )); then
    log "Pruning $((${#files_to_delete[@]})) old file(s) in $target_dir (keeping $keep_count newest)"
    while IFS= read -r -d '' f; do
      log "  rm -f -- $f"
      rm -f -- "$f"
    done < <(printf '%s\0' "${files_to_delete[@]}")
  else
    log "No pruning needed in $target_dir (<= $keep_count files)."
  fi
}

is_first_day_of_year()    { [[ "$(date +%m%d)" == "0101" ]]; }
is_first_day_of_quarter() { local m d; m=$(date +%m); d=$(date +%d); [[ "$d" == "01" && ( "$m" == "01" || "$m" == "04" || "$m" == "07" || "$m" == "10" ) ]]; }
is_first_day_of_month()   { [[ "$(date +%d)" == "01" ]]; }

# Set DEST and KEEP_COUNT as globals (no output parsing)
pick_destination() {
  if is_first_day_of_year; then
    DEST="$DIR_YEARLY";     KEEP_COUNT=$KEEP_YEARLY
  elif is_first_day_of_quarter; then
    DEST="$DIR_QUARTERLY";  KEEP_COUNT=$KEEP_QUARTERLY
  elif is_first_day_of_month; then
    DEST="$DIR_MONTHLY";    KEEP_COUNT=$KEEP_MONTHLY
  else
    DEST="$DIR_WEEKLY";     KEEP_COUNT=$KEEP_WEEKLY   # default
  fi
}

wait_for_done_files() {
  local retries=0
  while true; do
    local missing=0
    shopt -s nullglob
    for f in "${SRC}"/*.tar "${SRC}"/*.tar.gz; do
      [[ -e "$f" ]] || continue
      [[ -f "${f}.done" ]] || { log "Waiting for .done: $f"; missing=1; }
    done
    shopt -u nullglob

    if (( missing == 0 )); then
      log "All .tar files have .done markers."
      return 0
    fi

    (( retries++ ))
    if (( retries > MAX_RETRIES )); then
      log "ERROR: .done files not found after $MAX_RETRIES retries. Exiting."
      exit 1
    fi
    log "Retry $retries/$MAX_RETRIES after $SLEEP_SECS sec..."
    sleep "$SLEEP_SECS"
  done
}

move_archives() {
  local dest_dir="$1"
  shopt -s nullglob
  local moved=0
  for f in "${SRC}"/*.tar "${SRC}"/*.tar.gz; do
    [[ -e "$f" ]] || continue
    [[ -f "${f}.done" ]] || continue   # safety check
    log "Moving: $f -> $dest_dir/"
    if mv -f -- "$f" "$dest_dir/"; then
      rm -f -- "${f}.done"            # remove marker only on success
      ((moved++))
    else
      log "ERROR: mv failed for $f (leaving .done in place)"
    fi
  done
  shopt -u nullglob
  echo "$moved"                        # stdout: integer only
}

# --- MAIN ---------------------------------------------------------------------

log "---- Hanoi rotate run starting ----"
ensure_dirs

shopt -s nullglob
pending=( "${SRC}"/*.tar "${SRC}"/*.tar.gz )
shopt -u nullglob

if (( ${#pending[@]} == 0 )); then
  log "No .tar/.tar.gz files found in ${SRC}. Nothing to do."
  exit 0
fi

# Wait for .done markers (avoids moving half-written files)
wait_for_done_files

# Choose destination (Y/Q/M else Weekly default)
pick_destination
log "Destination selected: $DEST (keep $KEEP_COUNT)"

# Sanity check
if [[ -z "${DEST}" || "${KEEP_COUNT}" -le 0 ]]; then
  log "ERROR: Destination or KEEP_COUNT not set correctly. Aborting."
  exit 1
fi

moved_count="$(move_archives "$DEST")"

if (( moved_count > 0 )); then
  log "Moved $moved_count file(s) to $DEST."
  log "Pruning $DEST to keep newest $KEEP_COUNT file(s)."
  prune_keep_newest "$DEST" "$KEEP_COUNT"
else
  log "There were pending files earlier, but none moved."
fi

log "---- Hanoi rotate run complete ----"

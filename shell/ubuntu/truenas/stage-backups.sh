#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# stage_backups.sh
#
# Purpose:
#   1) Under Backups/, for each top-level item:
#        - If it contains subfolders: TAR+GZIP the most-recent subfolder
#          into staging/<top-level-name>/<subfolder>.tar.gz
#        - Else if it contains files: copy the most-recent file into
#          staging/<top-level-name>/.
#   2) For Apps/ and Users/, TAR+GZIP a snapshot of the whole folder into
#      staging/Apps/ and staging/Users/ respectively.
#   3) Bundle entire staging into ONE tar (no recompression).
#   4) When the final tar is finished, write a `.done` marker so rotation
#      scripts can safely detect completion.
#
# Usage:
#   sudo bash stage_backups.sh
# -----------------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

ROOT="/mnt/HDD-RZ1-01/HDD-RZ1-ENC-CLOUD-01"
BACKUPS_DIR="${ROOT}/Backups"
STAGING="${ROOT}/staging"

# Prefer pigz if present
TAR_COMPRESS_ARGS=("-czf")
if command -v pigz >/dev/null 2>&1; then
  TAR_COMPRESS_ARGS=("--use-compress-program=pigz" "-cf")
fi

mkdir -p "${STAGING}"

timestamp() { date +"%Y%m%d-%H%M%S"; }

echo "================================================================"
echo " Staging process started at $(date)"
echo " Root: ${ROOT}"
echo " Staging dir: ${STAGING}"
echo "================================================================"

# --- 1) Backups: per child, package newest subfolder OR copy newest file -----
if [[ -d "${BACKUPS_DIR}" ]]; then
  echo ""
  echo "[STEP 1] Processing Backups directory: ${BACKUPS_DIR}"
  for child in "${BACKUPS_DIR}"/*; do
    [[ -e "$child" ]] || continue
    child_name="$(basename "$child")"
    outdir="${STAGING}/${child_name}"
    mkdir -p "${outdir}"

    echo " -> Working on Backups/${child_name}..."

    # If it has subdirectories
    newest_dir=""
    if find "$child" -mindepth 1 -maxdepth 1 -type d -print -quit >/dev/null 2>&1; then
      newest_dir="$(find "$child" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' \
                    | sort -nr | head -n1 | cut -d' ' -f2-)"
    fi

    if [[ -n "${newest_dir}" ]]; then
      base="$(basename "$newest_dir")"
      tarball="${outdir}/${base}.tar.gz"
      echo "    Archiving newest subfolder: ${base} -> ${tarball}"
      tar -C "$child" "${TAR_COMPRESS_ARGS[@]}" "${tarball}" "${base}"
      continue
    fi

    # Otherwise, check for files
    newest_file=""
    if find "$child" -mindepth 1 -maxdepth 1 -type f -print -quit >/dev/null 2>&1; then
      newest_file="$(find "$child" -mindepth 1 -maxdepth 1 -type f -printf '%T@ %p\n' \
                     | sort -nr | head -n1 | cut -d' ' -f2-)"
    fi

    if [[ -n "${newest_file}" ]]; then
      echo "    Copying newest file: $(basename "${newest_file}") -> ${outdir}/"
      cp -a "${newest_file}" "${outdir}/"
    else
      echo "    No subfolders or files found; skipped."
    fi
  done
else
  echo "!! Backups directory not found: ${BACKUPS_DIR}" >&2
fi

# --- 2) Apps and Users: snapshot whole folders -------------------------------
echo ""
echo "[STEP 2] Archiving Apps and Users folders..."
for top in Apps Users; do
  src="${ROOT}/${top}"
  [[ -d "${src}" ]] || { echo " -> Missing ${top}, skipping."; continue; }
  outdir="${STAGING}/${top}"
  mkdir -p "${outdir}"
  tarball="${outdir}/${top}-$(timestamp).tar.gz"
  echo " -> Archiving ${top} -> ${tarball}"
  tar -C "${ROOT}" "${TAR_COMPRESS_ARGS[@]}" "${tarball}" "${top}"
done

echo ""
echo "================================================================"
echo " Staging complete at $(date)"
echo " Output is available in: ${STAGING}"
echo "================================================================"

# --- 3) FINAL: Bundle entire staging into ONE tar (no recompression) ---------
echo ""
echo "[STEP 3] Creating single TAR from staging contents (no recompression)..."
host_short="$(hostname -s 2>/dev/null || hostname)"
today="$(date +%Y%m%d)"
FINAL_PATH="${ROOT}/${host_short}-${today}-staging.tar"

# Don’t write the final tar inside staging to avoid self-inclusion.
if [[ -f "${FINAL_PATH}" ]]; then
  echo " -> Removing existing ${FINAL_PATH}"
  rm -f "${FINAL_PATH}"
fi

# If staging is empty, warn and skip
if [[ -z "$(ls -A "${STAGING}" 2>/dev/null)" ]]; then
  echo " -> WARNING: ${STAGING} is empty; skipping final TAR."
else
  echo " -> Building ${FINAL_PATH} from contents of ${STAGING}"
  tar -C "${STAGING}" -cf "${FINAL_PATH}" .
  sync
  echo " -> Final TAR complete."
  du -h "${FINAL_PATH}" | awk '{print " -> Size: "$1}'
  # Uncomment to write an integrity hash next to the archive:
  # sha256sum "${FINAL_PATH}" > "${FINAL_PATH}.sha256"
  # echo " -> SHA256 written to ${FINAL_PATH}.sha256"

  # <<< NEW >>> Write a .done marker
  touch "${FINAL_PATH}.done"
  echo " -> Done marker written: ${FINAL_PATH}.done"
fi

echo ""
echo "================================================================"
echo " All done at $(date)"
echo " Single file ready for Storj (if created): ${FINAL_PATH}"
echo "================================================================"

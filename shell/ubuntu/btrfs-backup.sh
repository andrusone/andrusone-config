#!/bin/bash
#
# btrfs-backup.sh
#
# Purpose:
#   Perform a snapshot of root subvolume and back it up using `btrfs send`
#
# Audience:
#   System administrators of Btrfs-based Ubuntu servers
#
# Value Created:
#   - Reliable, timestamped backups of root filesystem
#   - Automatically prunes old backups and snapshots

set -euo pipefail

# --- Configuration ---
HOSTNAME="svr-net-nbtx-p01"
SNAP_DIR="/.snapshots"
SRC_SUBVOL="/"
BACKUP_ROOT="/nas/backups/${HOSTNAME}"
DATE=$(date +%Y-%m-%d-%H%M)
SNAP_NAME="root-${DATE}"
SNAP_PATH="${SNAP_DIR}/${SNAP_NAME}"
BACKUP_FILE="${BACKUP_ROOT}/${SNAP_NAME}.btrfs"
RETENTION_DAYS=30

# --- Ensure required dirs exist ---
mkdir -p "${SNAP_DIR}" "${BACKUP_ROOT}"

echo "[+] Creating snapshot at ${SNAP_PATH}"
btrfs subvolume snapshot -r "${SRC_SUBVOL}" "${SNAP_PATH}"

echo "[+] Sending snapshot to ${BACKUP_FILE}"
btrfs send "${SNAP_PATH}" | zstd -19 -T0 > "${BACKUP_FILE}.zst"

echo "[+] Deleting snapshot ${SNAP_PATH}"
btrfs subvolume delete "${SNAP_PATH}"

echo "[+] Deleting backup files older than ${RETENTION_DAYS} days"
find "${BACKUP_ROOT}" -name '*.zst' -mtime +${RETENTION_DAYS} -delete

echo -e "\e[32m[✔] Backup completed successfully for ${HOSTNAME} on ${DATE}\e[0m"
curl https://hc-ping.com/da1f49be-ee8b-4d5c-aff4-60f51cdfda8f

#!/bin/bash
set -euo pipefail

# -------------------------------------------------------------------
# Usage:
#   ./snapshot-and-compress-zvol.sh <zvol_name>
# Example:
#   ./snapshot-and-compress-zvol.sh pool/dataset/vm-rocky
#
# This will:
#   - Create a ZFS snapshot of the given zvol
#   - Export it with `zfs send`
#   - Compress it with gzip
#   - Save it to the image archive directory
#
# To restore or clone this snapshot later:
#   gunzip -c <snapshot>.zvol.gz | zfs receive -F <target_zvol>
# -------------------------------------------------------------------

# CONFIGURABLE
DEST_DIR="/mnt/HDD-RZ1-01/HDD-RZ1-ENC-LOCAL-01-CMP/Cloud-Images"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# Usage
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <zvol_name> (e.g. pool/dataset/vm-rocky)"
  exit 1
fi

ZVOL="$1"

# Validate zvol exists
if ! zfs list -t volume "$ZVOL" >/dev/null 2>&1; then
  echo "❌ ZVOL '$ZVOL' not found."
  exit 1
fi

# Create snapshot
SNAP_NAME="${ZVOL}@backup-${TIMESTAMP}"
echo "📸 Creating snapshot: $SNAP_NAME"
zfs snapshot "$SNAP_NAME"

# Build output filename
BASENAME=$(echo "$ZVOL" | tr '/' '-')
OUTPUT_FILE="${DEST_DIR}/${BASENAME}-${TIMESTAMP}.zvol.gz"

# Ensure destination exists
mkdir -p "$DEST_DIR"

# Export snapshot and compress
echo "📦 Exporting snapshot and compressing..."
zfs send "$SNAP_NAME" | gzip -c > "$OUTPUT_FILE"

echo "✅ Snapshot exported and saved to:"
echo "   $OUTPUT_FILE"

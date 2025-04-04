#!/bin/bash

# This script fills all free space on the specified mount point with zeros.
# It should be run with sudo or as root.

TARGET_DIR=${1:-/}  # Default to root if not provided

echo "Zeroing out free space in: $TARGET_DIR"

# Create a large zero-filled file
echo "Writing zeros to $TARGET_DIR..."
dd if=/dev/zero of="${TARGET_DIR}/zero.fill" bs=1M status=progress || true

# Sync to ensure data is written
sync

# Remove the file to free up space
echo "Removing zero file..."
rm -f "${TARGET_DIR}/zero.fill"

# Final sync
sync

echo "Free space zeroed out successfully."

#!/bin/bash
#
# setup_btrfs_subvolumes.sh
#
# Purpose:
#   Restructure a newly installed Ubuntu system with a single Btrfs root volume
#   into a clean subvolume layout optimized for snapshots, backup, and recovery.
#
# Audience:
#   Engineers or admins setting up bare-metal Ubuntu servers with Btrfs
#
# Value Created:
#   - Enables consistent root-level snapshots using `btrfs subvolume snapshot`
#   - Separates /home, /var/log, /var/cache for modular backups or exclusions
#   - Reduces risk of snapshot bloat and simplifies restores
#
# Preconditions:
#   - Fresh Ubuntu system installed with Btrfs on a single partition (e.g., /dev/sda3)
#   - /boot and swap are on separate partitions
#   - Script is run as root from a live ISO or immediately after install
#
# Real-World Safe Scenario: Fresh SSH Setup
#   This script *can* be safely run via SSH if ALL the following are true:
#     - It’s a fresh install (no config changes or workloads yet)
#     - No users or services are modifying /home, /var/log, or /var/cache
#     - You are the ONLY user logged in
#     - You understand this rewrites the filesystem layout and requires reboot
#
# Usage:
#   1. Adjust MOUNT_DEV if needed
#   2. Run as root from a live ISO or SSH session that meets the safe scenario
#   3. Reboot when complete

set -e

MOUNT_DEV="/dev/sda3"
MOUNT_POINT="/mnt"

# Detect if user is running over SSH
if [[ -n "$SSH_CONNECTION" ]]; then
    echo "⚠️ Detected SSH session. Please confirm the following:"
    echo "  - This is a new system install (5 minutes old or less)"
    echo "  - No users or services are actively modifying files"
    echo "  - You are the only user logged in"
    echo "  - You understand this changes how root mounts and requires a reboot"
    echo
    read -r -p "Continue anyway? (yes/[no]): " confirm
    [[ "$confirm" == "yes" ]] || { echo "Aborting."; exit 1; }
fi

echo ">> Mounting root Btrfs volume"
mount $MOUNT_DEV $MOUNT_POINT

echo ">> Creating subvolumes"
for subvol in @ @home @log @cache @snapshots; do
    btrfs subvolume create "$MOUNT_POINT/$subvol"
done

echo ">> Syncing root filesystem into @"
rsync -aAXv $MOUNT_POINT/ $MOUNT_POINT/@ \
    --exclude=/${MOUNT_POINT#/}/@* \
    --exclude=/mnt

echo ">> Moving key directories into subvolumes"
mv $MOUNT_POINT/home/*      $MOUNT_POINT/@home/     2>/dev/null || true
mv $MOUNT_POINT/var/log/*   $MOUNT_POINT/@log/      2>/dev/null || true
mv $MOUNT_POINT/var/cache/* $MOUNT_POINT/@cache/    2>/dev/null || true

echo ">> Unmounting volume"
umount $MOUNT_POINT

UUID=$(blkid -s UUID -o value $MOUNT_DEV)

echo ">> Updating /etc/fstab with subvolume entries"

fstab_entries=$(cat <<EOF

# Btrfs subvolume layout
UUID=$UUID /           btrfs defaults,subvol=@         0 1
UUID=$UUID /home       btrfs defaults,subvol=@home     0 2
UUID=$UUID /var/log    btrfs defaults,subvol=@log      0 2
UUID=$UUID /var/cache  btrfs defaults,subvol=@cache    0 2
UUID=$UUID /.snapshots btrfs defaults,subvol=@snapshots 0 2
EOF
)

# Only append if subvol entries don't already exist
if ! grep -q "subvol=@" /etc/fstab; then
    echo "$fstab_entries" >> /etc/fstab
    echo ">> /etc/fstab updated."
else
    echo ">> /etc/fstab already contains subvolume entries — skipping append."
fi

echo "✅ Done. Reboot and verify layout with: findmnt -t btrfs && btrfs subvolume list /"

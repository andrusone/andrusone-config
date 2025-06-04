#!/bin/bash
export PATH="/sbin:/bin:/usr/sbin:/usr/bin"


# Define backup location
BACKUP_POOL="HDD-RZ1-01/HDD-RZ1-ENC-CLOUD-01/Backups/System"
LOCAL_BACKUP_DIR="/mnt/${BACKUP_POOL}/"
BACKUP_DATE=$(date +%Y-%m-%d)
LOCAL_BACKUP="${LOCAL_BACKUP_DIR}/truenas_backup_${BACKUP_DATE}"
LOG_FILE="${LOCAL_BACKUP}/backup.log"

# Create backup dir and set up logging
mkdir -p "$LOCAL_BACKUP"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===== Starting TrueNAS backup: $(date) ====="

# Cleanup old backups
echo "Cleaning up backups older than 30 days..."
find "$LOCAL_BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} +

# 0. Backup the script running
echo "Copying the backup script..."
cp "$0" "$LOCAL_BACKUP/"
cp /var/lib/qeke/* "$LOCAL_BACKUP/"

# 1. Backup system configuration
echo "Backing up system configuration..."
midclt call system.general.config > "$LOCAL_BACKUP/system_config.json"

# 2. Copy user_config.yaml
echo "Copying user_config.yaml..."
cp "/mnt/.ix-apps/user_config.yaml" "$LOCAL_BACKUP/"

# 3. Archive all app configs and mounts
echo "Creating ix-apps.tar.gz..."
tar -czf "$LOCAL_BACKUP/ix-apps.tar.gz" -C /mnt/.ix-apps app_configs app_mounts

# 4. Backup VMs via snapshots
VM_PATH="HDD-RZ1-01/HDD-RZ1-ENC-LOCAL-01/VM"
ZVOL_LIST=$(zfs list -H -o name -t volume | grep "^${VM_PATH}/")

echo "Backing up VMs from $VM_PATH..."
for ZVOL in $ZVOL_LIST; do
  VM_NAME=$(basename "$ZVOL")
  SNAPSHOT_NAME="${ZVOL}@backup"

  echo "Processing $VM_NAME..."

  # Delete previous snapshot if exists
  if zfs list -t snapshot "$SNAPSHOT_NAME" >/dev/null 2>&1; then
    echo "Deleting old snapshot: $SNAPSHOT_NAME"
    zfs destroy "$SNAPSHOT_NAME"
  fi

  # Create new snapshot
  echo "Creating snapshot: $SNAPSHOT_NAME"
  zfs snapshot "$SNAPSHOT_NAME"

  # Send and compress snapshot
  SNAP_GZ="${LOCAL_BACKUP}/${VM_NAME}.zfs.gz"
  echo "Sending and compressing snapshot to $SNAP_GZ"
  zfs send "$SNAPSHOT_NAME" | gzip > "$SNAP_GZ"
done

# 5. Dump VM configurations
echo "Saving VM metadata..."
midclt call vm.query > "$LOCAL_BACKUP/vm_configs.json"

# 6. Backup network and user config
echo "Backing up network and user configurations..."
midclt call network.configuration.config > "$LOCAL_BACKUP/network_config.json"
midclt call user.query > "$LOCAL_BACKUP/users.json"

# Report success
curl https://hc-ping.com/46763be9-620b-4ad0-a8a9-42f34af443d0

echo "===== Backup completed: $(date) ====="

#!/bin/bash
# setup-truenas-mounts.sh
# Sets up CIFS mounts for TrueNAS on Ubuntu

set -euo pipefail

# --- Configuration ---
TRUENAS_IP="192.168.8.3"
TRUENAS_HOSTNAME="truenas"
MOUNT_ROOT="/mnt"
SHARES=(apps backups cloud-images local-archive media users)
SMBCREDS_FILE="$HOME/.smbcreds"

# --- Install CIFS utilities ---
echo "[+] Installing CIFS utilities..."
sudo apt-get update -y
sudo apt-get install -y cifs-utils

# --- Create .smbcreds file ---
echo "[+] Creating .smbcreds file at $SMBCREDS_FILE..."
cat <<EOF > "$SMBCREDS_FILE"
username=your_username
password=your_password
domain=your_domain
EOF

chmod 600 "$SMBCREDS_FILE"
echo "  -> Remember to edit your credentials later: nano $SMBCREDS_FILE"

# --- Add TrueNAS host entry ---
echo "[+] Adding $TRUENAS_HOSTNAME to /etc/hosts..."
if ! grep -q "$TRUENAS_HOSTNAME" /etc/hosts; then
    echo "$TRUENAS_IP    $TRUENAS_HOSTNAME" | sudo tee -a /etc/hosts
else
    echo "  -> Entry for $TRUENAS_HOSTNAME already exists in /etc/hosts."
fi

# --- Create mount directories ---
echo "[+] Creating mount directories under $MOUNT_ROOT..."
for share in "${SHARES[@]}"; do
    sudo mkdir -p "$MOUNT_ROOT/$share"
done

# --- Remove old TrueNAS entries from /etc/fstab ---
echo "[+] Cleaning up old //truenas entries in /etc/fstab..."
sudo sed -i.bak '/\/\/truenas\//d' /etc/fstab

# --- Add clean TrueNAS entries to /etc/fstab ---
echo "[+] Adding new TrueNAS mount entries..."
for share in "${SHARES[@]}"; do
    echo "//$TRUENAS_HOSTNAME/$share $MOUNT_ROOT/$share cifs credentials=$SMBCREDS_FILE,iocharset=utf8,uid=1000,gid=1000,noperm,exec 0 0" | sudo tee -a /etc/fstab
done

# --- Mount all shares ---
echo "[+] Mounting all shares..."
sudo mount -a

echo "[✓] Setup complete. Edit your .smbcreds and verify mounts with: df -h"

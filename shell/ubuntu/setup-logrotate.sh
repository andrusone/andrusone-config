#!/bin/bash
#
# setup-logrotate-prune.sh
#
# Purpose:
#   Prune all logs older than 30 days in /var/log using logrotate
#
# Audience:
#   Sysadmins using Btrfs subvolumes with isolated /var/log
#
# Value Created:
#   - Prevents log bloat in the @log subvolume
#   - Centralizes pruning via logrotate
#   - Works even for custom apps writing logs under /var/log
#
# Preconditions:
#   - /var/log is mounted from Btrfs subvolume @log
#   - Ubuntu 24.04 with logrotate installed
#
# Usage:
#   sudo bash setup-logrotate-prune.sh

set -euo pipefail

echo "[+] Installing logrotate if missing..."
sudo apt-get update -qq
sudo apt-get install -y logrotate

CUSTOM_LOG="/etc/logrotate.d/all-var-log"

echo "[+] Creating catch-all logrotate rule at $CUSTOM_LOG..."

sudo tee "$CUSTOM_LOG" > /dev/null <<'EOF'
/var/log/**/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
    maxage 30
    dateext
    su root root
}
/var/log/**/log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
    maxage 30
    dateext
    su root root
}
EOF

echo -e "\e[32m[✓] Logrotate pruning is now active for all logs in /var/log"
echo -e "    Logs older than 30 days will be removed on next rotate.\e[0m"

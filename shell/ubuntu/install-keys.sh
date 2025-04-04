#!/bin/bash

# SSH key setup + Git identity configuration

set -e  # Exit on error

# --- Prompt for remote path and credentials ---
echo "Enter the full UNC path to your key share."
echo "Example: //192.168.8.3/users/Dave/Keys"
read -r -p "Remote key share path: " REMOTE_SHARE

read -r -p "Enter your Windows username: " USERNAME
read -r -s -p "Enter your Windows password: " PASSWORD
echo ""

# Prompt for SSH private key filename (default: andrusone.dev)
read -r -p "Name of your SSH private key file (default: andrusone.dev): " KEY_NAME
KEY_NAME=${KEY_NAME:-andrusone.dev}

# Local destination
MOUNT_POINT="/mnt/keys"
DEST_DIR="$HOME/.ssh"

# --- Ensure cifs-utils is installed ---
sudo apt update && sudo apt install -y cifs-utils

# --- Mount the Windows share ---
sudo mkdir -p "$MOUNT_POINT"
sudo mount -t cifs "$REMOTE_SHARE" "$MOUNT_POINT" -o username="$USERNAME",password="$PASSWORD",rw

# --- Copy key files ---
mkdir -p "$DEST_DIR"
chmod 700 "$DEST_DIR"
cp "$MOUNT_POINT/$KEY_NAME" "$DEST_DIR/"
[ -f "$MOUNT_POINT/$KEY_NAME.pub" ] && cp "$MOUNT_POINT/$KEY_NAME.pub" "$DEST_DIR/"
chmod 600 "$DEST_DIR/$KEY_NAME"
[ -f "$DEST_DIR/$KEY_NAME.pub" ] && chmod 644 "$DEST_DIR/$KEY_NAME.pub"

# --- Unmount share ---
sudo umount "$MOUNT_POINT"
sudo rmdir "$MOUNT_POINT"

# --- Start SSH agent and add key ---
eval "$(ssh-agent -s)"
ssh-add "$DEST_DIR/$KEY_NAME"

# --- Persist SSH agent config ---
BASHRC="$HOME/.bashrc"
START_LINE="eval \"\$(ssh-agent -s)\""
ADD_KEY_LINE="ssh-add $DEST_DIR/$KEY_NAME 2>/dev/null"

if ! grep -q "$START_LINE" "$BASHRC"; then
  {
    echo ""
    echo "# Start ssh-agent and load key"
    echo "$START_LINE"
    echo "$ADD_KEY_LINE"
  } >> "$BASHRC"
  echo "✅ Added ssh-agent startup and key load to $BASHRC"
fi

# --- GitHub SSH test ---
echo "🔧 Testing GitHub SSH connection..."
ssh -T git@github.com || echo "⚠️ SSH connection to GitHub failed (key may not be added on GitHub)"

# --- Git identity configuration ---
if ! git config --global user.name &>/dev/null; then
  read -r -p "Enter your Git user name: " GIT_NAME
  git config --global user.name "$GIT_NAME"
  echo "✅ Git user.name set to: $GIT_NAME"
fi

if ! git config --global user.email &>/dev/null; then
  read -r -p "Enter your Git email address: " GIT_EMAIL
  git config --global user.email "$GIT_EMAIL"
  echo "✅ Git user.email set to: $GIT_EMAIL"
fi

echo "✅ SSH key setup and Git identity configuration complete."

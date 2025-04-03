#!/usr/bin/env bash

# helper/setup_ssh_github.sh
# Generates an SSH key and sets up Git to use it with GitHub

set -euo pipefail

# Accept key name, email, Git name, and Git email as arguments or prompt the user
KEY_NAME=${1:-}
EMAIL=${2:-}
GIT_NAME=${3:-}
GIT_EMAIL=${4:-}

if [ -z "$KEY_NAME" ]; then
  read -rp "Enter a name for your SSH key (e.g., andrusone.dev): " KEY_NAME
fi

if [ -z "$EMAIL" ]; then
  read -rp "Enter your GitHub email address (used for the SSH key comment): " EMAIL
fi

if [ -z "$GIT_NAME" ]; then
  read -rp "Enter your Git user.name (e.g., Dave Andrus): " GIT_NAME
fi

if [ -z "$GIT_EMAIL" ]; then
  read -rp "Enter your Git user.email (must match GitHub email): " GIT_EMAIL
fi

KEY_PATH="$HOME/.ssh/$KEY_NAME"

log() {
  echo "[setup_ssh_github] $1"
}

# 1. Generate SSH key if it doesn't exist
if [ ! -f "$KEY_PATH" ]; then
  log "Generating new SSH key at $KEY_PATH..."
  ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_PATH" -N ""
else
  log "SSH key already exists at $KEY_PATH"
fi

# 2. Configure SSH to use this key with GitHub
SSH_CONFIG="$HOME/.ssh/config"
if ! grep -q "$KEY_NAME" "$SSH_CONFIG" 2>/dev/null; then
  log "Adding SSH config for GitHub..."
  {
    echo ""
    echo "Host github.com"
    echo "  HostName github.com"
    echo "  User git"
    echo "  IdentityFile $KEY_PATH"
    echo "  IdentitiesOnly yes"
  } >> "$SSH_CONFIG"
else
  log "SSH config already includes $KEY_NAME for github.com"
fi

# 3. Start ssh-agent and add key
log "Starting ssh-agent and adding key..."
eval "$(ssh-agent -s)"
ssh-add "$KEY_PATH"

# 4. Configure Git identity globally
log "Setting global Git user.name and user.email..."
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

log "Configuring Git to use SSH instead of HTTPS for GitHub..."
git config --global url.\"git@github.com:\".insteadOf \"https://github.com/\"


# 5. Display public key with instructions
log "Here is your public key. Add it to GitHub:"
echo "------------------------------------------------------------"
cat "$KEY_PATH.pub"
echo "------------------------------------------------------------"
echo "Visit: https://github.com/settings/keys and paste it as a new SSH key."
echo "Once added, test it with: ssh -T git@github.com"

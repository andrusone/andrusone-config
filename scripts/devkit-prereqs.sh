#!/usr/bin/env bash

# helper/install_and_test_prereqs.sh
# Installs and verifies all project prerequisites on Ubuntu using Poetry

set -euo pipefail

log() {
  echo "[install_and_test] $1"
}

check() {
  if ! command -v "$1" &>/dev/null; then
    echo "[MISSING] $1 not found in PATH"
    return 1
  else
    echo "[OK] $1 found"
  fi
}

failures=0

log "Updating package list..."
sudo apt update

log "Installing system packages (git, ssh, python3, curl)..."
sudo apt install -y git openssh-client python3 python3-pip curl

log "Installing Poetry..."
if ! command -v poetry &>/dev/null; then
  curl -sSL https://install.python-poetry.org | python3 -
  export PATH="$HOME/.local/bin:$PATH"
else
  log "Poetry is already installed"
fi

log "Configuring Poetry to create virtualenvs inside project..."
poetry config virtualenvs.in-project true

if [ -f "pyproject.toml" ]; then
  log "Installing project dependencies via Poetry..."
  poetry install
else
  log "Skipping poetry install (no pyproject.toml found)"
fi

log "Installing shfmt (shell formatter)..."
SHFMT_BIN="$HOME/.local/bin/shfmt"
mkdir -p "$HOME/.local/bin"
if ! command -v shfmt &> /dev/null; then
  curl -sSLo "$SHFMT_BIN" https://github.com/mvdan/sh/releases/latest/download/shfmt_linux_amd64
  chmod +x "$SHFMT_BIN"
  log "shfmt installed to $SHFMT_BIN"
else
  log "shfmt is already installed"
fi

# Ensure ~/.local/bin is in PATH for this session
export PATH="$HOME/.local/bin:$PATH"

log "Checking installation of all tools..."
check git || failures=$((failures+1))
check ssh || failures=$((failures+1))
check python3 || failures=$((failures+1))
check poetry || failures=$((failures+1))
check shfmt || failures=$((failures+1))

if [[ $failures -eq 0 ]]; then
  echo "\nAll prerequisite tools are installed and verified."
  echo "To enter your Poetry-managed virtual environment, run: poetry shell"
  exit 0
else
  echo "\nSome prerequisites are missing or failed to install."
  exit 1
fi

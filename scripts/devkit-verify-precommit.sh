#!/usr/bin/env bash

# scripts/devkit-verify-precommit.sh
# Verifies that pre-commit hooks are installed and working

set -euo pipefail

log() {
  echo "[devkit-verify-precommit] $1"
}

log "Installing and updating pre-commit hooks..."
pre-commit install
pre-commit autoupdate

failures=0

# Check that pre-commit is installed
if ! command -v pre-commit &>/dev/null; then
  log "pre-commit is not installed or not in PATH"
  exit 1
fi

# Check that .pre-commit-config.yaml exists
if [ ! -f .pre-commit-config.yaml ]; then
  log ".pre-commit-config.yaml not found in project root"
  exit 1
fi

# Check if hooks are installed
if ! grep -q "pre-commit" .git/hooks/pre-commit 2>/dev/null; then
  log "pre-commit hooks are not installed. Installing them..."
  pre-commit install
else
  log "pre-commit hooks are already installed"
fi

# Run pre-commit on all files
log "Running pre-commit hooks against all files..."
if ! pre-commit run --all-files; then
  log "Some pre-commit hooks failed"
  failures=$((failures + 1))
else
  log "All pre-commit hooks passed"
fi

if [ "$failures" -eq 0 ]; then
  log "pre-commit setup verified"
  exit 0
else
  log "pre-commit verification failed"
  exit 1
fi

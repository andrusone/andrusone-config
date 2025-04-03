#!/usr/bin/env bash

# scripts/devkit-verify-env.sh
# Verifies that the devkit environment is active and tools are available

set -uo pipefail

log() {
  echo "[devkit-verify-env] $1"
}

failures=0

# Check if the environment is active
if [ -z "${VIRTUAL_ENV:-}" ]; then
  log "VIRTUAL_ENV is not set. The virtual environment is not active."
  failures=$((failures + 1))
else
  log "VIRTUAL_ENV is active: $VIRTUAL_ENV"

  # Check if we're using the poetry-managed virtualenv
  if [[ "$VIRTUAL_ENV" != *".venv"* ]]; then
    log "Warning: VIRTUAL_ENV does not appear to be the Poetry-managed environment."
  fi
fi

# Check if direnv exported variables
if [ -n "${DIRENV_DIR:-}" ]; then
  log "direnv is active in this directory."
else
  log "direnv does not appear to be active."
  failures=$((failures + 1))
fi

# Check required tools
for tool in python black ruff pre-commit sqlfluff; do
  if ! command -v "$tool" &>/dev/null; then
    log "$tool not found in PATH"
    failures=$((failures + 1))
  else
    log "$tool is available"
  fi
done

# Summary
if [ "$failures" -eq 0 ]; then
  log "All checks passed. Environment is properly configured."
  exit 0
else
  log "Some checks failed. Please review the output above."
  exit 1
fi

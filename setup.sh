#!/usr/bin/env bash

# scripts/devkit-verify-or-install-env.sh
# Sets up and verifies the devkit environment

set -euo pipefail

log() {
  echo "[devkit-verify-env] $1"
}

failures=0

# --- Detect shell and RC file ---
detect_shell_rc() {
  local shell_name
  shell_name=$(basename "$SHELL")
  case "$shell_name" in
    bash) echo "$HOME/.bashrc" ;;
    zsh) echo "$HOME/.zshrc" ;;
    fish) echo "$HOME/.config/fish/config.fish" ;;
    *) echo "$HOME/.profile" ;;  # fallback
  esac
}

SHELL_RC=$(detect_shell_rc)
log "Detected shell config file: $SHELL_RC"

# --- Install Python 3 ---
if ! command -v python3 &>/dev/null; then
  log "Python 3 not found. Installing..."
  sudo apt update && sudo apt install -y python3 python3-pip
fi

# --- Install direnv ---
if ! command -v direnv &>/dev/null; then
  log "direnv not found. Installing..."
  sudo apt install -y direnv
fi

# --- Add direnv hook ---
if ! grep -q 'direnv hook' "$SHELL_RC"; then
  log "Adding direnv hook to $SHELL_RC"
  echo 'eval "$(direnv hook bash)"' >> "$SHELL_RC"
  eval "$(direnv hook bash)"
fi

# --- Create and allow .envrc ---
if [ ! -f ".envrc" ]; then
  log "Creating .envrc with 'layout poetry'"
  echo "layout poetry" > .envrc
fi

log "Running 'direnv allow'"
direnv allow || {
  log "⚠️ direnv allow failed"
  failures=$((failures + 1))
}

# --- Install Poetry ---
if ! command -v poetry &>/dev/null; then
  log "Poetry not found. Installing..."
  curl -sSL https://install.python-poetry.org | python3 -
  export PATH="$HOME/.local/bin:$PATH"
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
  source "$SHELL_RC"
fi

# --- Patch pyproject.toml to disable package mode ---
if [ -f "pyproject.toml" ]; then
  if ! grep -q "package-mode" pyproject.toml; then
    log "Patching pyproject.toml to add 'package-mode = false'"
    sed -i '/^\[tool.poetry\]/a package-mode = false' pyproject.toml
  fi
else
  log "pyproject.toml not found. Skipping Poetry setup."
  failures=$((failures + 1))
fi

# --- Verify VIRTUAL_ENV ---
if [ -z "${VIRTUAL_ENV:-}" ]; then
  log "VIRTUAL_ENV is not set. The Poetry environment may not be active."
  failures=$((failures + 1))
else
  log "VIRTUAL_ENV is active: $VIRTUAL_ENV"
fi

# --- Install required tools ---
if [ -f "pyproject.toml" ]; then
  REQUIRED_TOOLS=(black ruff pre-commit sqlfluff)
  for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! poetry run which "$tool" &>/dev/null; then
      log "$tool not found. Installing via Poetry..."
      poetry add --group dev "$tool"
    else
      log "$tool is available in Poetry env"
    fi
  done

  log "Running poetry install..."
  poetry install --no-root

  log "Running pre-commit install..."
  poetry run pre-commit install || log "⚠️ pre-commit install failed"
fi

# --- Final summary ---
if [ "$failures" -eq 0 ]; then
  log "✅ Devkit environment is ready."
  exit 0
else
  log "⚠️ Some issues occurred during setup. See log above."
  exit 1
fi

#!/usr/bin/env bash

# scripts/devkit-poetry-setup.sh
# Creates a pyproject.toml and sets up Poetry environment with dev dependencies and direnv integration

set -euo pipefail

log() {
  echo "[devkit-poetry-setup] $1"
}

# Confirm script is run from project root
if [ ! -d ".git" ] || [ ! -d "scripts" ]; then
  read -rp "This doesn't look like the project root. Continue anyway? [y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log "Please navigate to your project root and run this script again."
    exit 1
  fi
fi

# 1. Create pyproject.toml with Poetry if it doesn't exist
if [ ! -f "pyproject.toml" ]; then
  log "Creating pyproject.toml with Poetry..."
  poetry init --name project-template --description "Project devkit template" \
    --author "Your Name <you@example.com>" --license MIT --python "^3.12" --no-interaction
else
  log "pyproject.toml already exists. Skipping init."
fi

# 2. Add dev dependencies
log "Adding dev dependencies to pyproject.toml..."
poetry add --group dev pre-commit black ruff sqlfluff

# 3. Install dependencies and create virtual environment
log "Installing dependencies and setting up virtual environment..."
poetry install --no-root

# 4. Configure direnv
if ! command -v direnv &>/dev/null; then
  log "direnv is not installed. Installing via apt..."
  sudo apt update && sudo apt install -y direnv
fi

log "Creating .envrc file for direnv activation..."
echo 'source "$(poetry env info --path)/bin/activate"' > .envrc

log "Allowing direnv in this directory..."
direnv allow

# 5. Enable direnv in shell if not already enabled
for rcfile in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [ -f "$rcfile" ] && ! grep -Fq 'eval "$(direnv hook' "$rcfile"; then
    case "$(basename "$rcfile")" in
  	.bashrc) shell_name="bash" ;;
  	.zshrc) shell_name="zsh" ;;
  	*) shell_name="" ;;
    esac

    if [[ "$shell_name" == "bash" || "$shell_name" == "zsh" ]]; then
      echo "" >> "$rcfile"
      echo "# Enable direnv shell integration" >> "$rcfile"
      echo "eval \"\$(direnv hook $shell_name)\"" >> "$rcfile"
      log "Added direnv integration to $rcfile"
    else
      log "Skipping unknown shell integration for $rcfile"
    fi
  fi
done

log "Poetry setup complete. The environment will auto-activate when you enter this directory (via direnv)."
log "If this is your first time, make sure to run: direnv allow"

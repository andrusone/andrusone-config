#!/usr/bin/env bash

# scripts/devkit-init.sh
# One-time initializer for a new project based on this template

set -euo pipefail

log() {
  echo "[devkit-init] $1"
}

# Prompt for project metadata
read -rp "Project name: " project_name
read -rp "Project description: " project_description
read -rp "Author name: " author_name
read -rp "Author email: " author_email

# Validate pyproject.toml exists
if [ ! -f pyproject.toml ]; then
  log "Error: pyproject.toml not found in current directory. Are you in the project root?"
  exit 1
fi

# Replace placeholders in pyproject.toml
log "Customizing pyproject.toml..."
sed -i "s/^name = \".*\"/name = \"$project_name\"/" pyproject.toml
sed -i "s/^description = \".*\"/description = \"$project_description\"/" pyproject.toml
sed -i "s/^authors = .*/authors = [\"$author_name <$author_email>\"]/" pyproject.toml

# Update README.md if it exists
if [ -f README.md ]; then
  log "Updating README.md..."
  sed -i "1s/.*/# $project_name/" README.md
fi

# Offer to reinitialize Git repo
read -rp "Reinitialize Git repository here? (y/n) " confirm_git
if [[ "$confirm_git" =~ ^[Yy]$ ]]; then
  rm -rf .git
  git init
  git add .
  git commit -m "Initial commit for $project_name"
  log "Git repository initialized."
fi

log "Project initialization complete."

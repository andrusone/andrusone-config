#!/usr/bin/env bash

# scripts/devkit-scaffold-samples.sh
# Creates language subdirectories and sample files for testing pre-commit hooks

set -euo pipefail

log() {
  echo "[devkit-scaffold-samples] $1"
}

# Define directory structure
LANGUAGE_DIRS=(
  "python"
  "shell/ubuntu"
  "shell/rhel"
  "shell/centos"
  "powershell"
  "sql/ansi"
  "sql/tsql"
  "sql/plsql"
  "sql/snowflake"
  "sql/source"
)

log "Creating directory structure..."
for dir in "${LANGUAGE_DIRS[@]}"; do
  mkdir -p "$dir"
  log "Created: $dir"
done

log "Creating sample files..."

# Python
cat > python/sample.py <<EOF
print("Hello, Python")
EOF

# Shell
for os in ubuntu rhel centos; do
  cat > shell/$os/sample.sh <<EOF
#!/bin/bash

echo "Hello from $os shell"
EOF
  chmod +x shell/$os/sample.sh
done

# PowerShell
cat > powershell/sample.ps1 <<EOF
Write-Output "Hello from PowerShell"
EOF

# SQL samples
cat > sql/ansi/sample.sql <<EOF
SELECT
    id,
    name
FROM users;
EOF

cat > sql/tsql/sample.sql <<EOF
SELECT TOP 10
    id,
    name
FROM customers;
EOF

cat > sql/snowflake/sample.sql <<EOF
SELECT CURRENT_DATE();
EOF

cat > sql/source/sample.sql <<EOF
-- raw data source --
EOF

log "Running pre-commit checks on scaffolded files..."
if pre-commit run --all-files; then
  log "All sample files passed pre-commit checks."
else
  log "Some pre-commit hooks failed. Review the above output."
fi

log "Scaffolding complete. You can now run pre-commit hooks against these files."
log "Try: pre-commit run --all-files"

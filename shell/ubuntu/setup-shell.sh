#!/bin/bash

# ------------------------------------------------------------------------------
# setup-shell.sh — One-Command Developer Shell Environment Bootstrapper
#
# PURPOSE:
#   Automates the setup of a reliable, modern, and visually consistent Zsh-based
#   developer shell on Ubuntu. Installs CLI tools, configures Oh My Zsh with
#   curated plugins, sets Nord-based color theming with vivid, and enables SSH
#   agent persistence with keychain.
#
# VALUE CREATED:
#   - Saves 30–60 minutes per machine setup
#   - Enables faster, more reliable CLI workflows
#   - Provides consistency across dev, homelab, and cloud environments
#   - Ensures SSH identity and shell theme persist on reboot/login
#
# AUDIENCE:
#   Engineers, homelab users, and developers provisioning Ubuntu environments
#
# REQUIREMENTS:
#   - Ubuntu 20.04 or later
#   - Internet connection
#   - Valid SSH private key at $HOME/.ssh/andrusone.dev
# ------------------------------------------------------------------------------

set -euo pipefail

KEY_PATH="$HOME/.ssh/andrusone.dev"

echo "[+] Installing packages..."
sudo apt update && sudo apt install -y \
  zsh curl git fzf autojump python3-pip \
  micro locales keychain

echo "[+] Setting UTF-8 locale..."
sudo locale-gen en_US.UTF-8

echo "[+] Installing Oh My Zsh..."
export RUNZSH=no
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

echo "[+] Setting Zsh as default shell..."
chsh -s "$(which zsh)"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# --- Plugins ---
[[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] || \
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

[[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] || \
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

[[ -d "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" ]] || \
  git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"

# --- Update .zshrc ---
sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting z autojump fasd colored-man-pages history-substring-search alias-finder docker kubectl aws python node virtualenv pip fzf)/' "$HOME/.zshrc"

if ! grep -q '### custom shell setup' "$HOME/.zshrc"; then
  {
    echo ''
    echo '### custom shell setup'
    echo "export PATH=\"\$HOME/.cargo/bin:\$PATH\""
    echo ''
    echo '# Use vivid for Tabby-compatible Nord LS_COLORS'
    echo 'if command -v vivid >/dev/null 2>&1; then'
    echo "  export LS_COLORS=\"\$(vivid generate nord-tabby-compatible)\""
    echo 'fi'
    echo ''
    echo '# Load SSH key using keychain'
    echo "eval \"\$(keychain --eval --quiet $KEY_PATH)\""
  } >> "$HOME/.zshrc"
fi

# --- Rust + Vivid ---
if ! command -v rustup >/dev/null 2>&1; then
  echo "[+] Installing rustup..."
  sudo apt remove -y rustc || true
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  # Load Rust env if it exists
  # shellcheck disable=SC1091
  [ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
fi

echo "[+] Installing vivid (Nord color theme generator)..."
cargo install vivid

# --- Install custom vivid theme ---
echo "[+] Installing custom Nord theme for vivid..."
mkdir -p "$HOME/.config/vivid/themes"
cp "$HOME/andrusone-config/assets/nord-tabby-compatible.theme" "$HOME/.config/vivid/themes/nord-tabby-compatible.theme"

# --- Micro editor with Nord theme ---
mkdir -p "$HOME/.config/micro/colors"
curl -fsSL -o "$HOME/.config/micro/colors/nord.micro" https://raw.githubusercontent.com/zyedidia/micro-colorschemes/master/colorschemes/nord.micro
echo '{ "colorscheme": "nord" }' > "$HOME/.config/micro/settings.json"

# --- SSH config for GitHub ---
SSH_CONFIG="$HOME/.ssh/config"
if ! grep -q "Host github.com" "$SSH_CONFIG" 2>/dev/null; then
  echo "[+] Adding GitHub to SSH config..."
  {
    echo ""
    echo "Host github.com"
    echo "  HostName github.com"
    echo "  User git"
    echo "  IdentityFile $KEY_PATH"
    echo "  IdentitiesOnly yes"
  } >> "$SSH_CONFIG"
fi

# --- Final message ---
echo -e "\n\033[1;32m[✓] Shell setup complete!\033[0m"
echo -e "\033[1;36mRestart your terminal or run \033[1;33m'exec zsh'\033[1;36m to start using it.\033[0m"

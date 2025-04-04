#!/bin/bash

# -----------------------------------------------------------------------------
# setup-shell.sh — One-Command Developer Shell Environment Bootstrapper
#
# Executive Summary:
# This script automates the setup of a modern Zsh-based developer shell 
# environment on Ubuntu. It installs common CLI tools, configures Oh My Zsh 
# with a curated set of productivity plugins, and sets up vivid for consistent, 
# colorized directory listings. It also configures SSH key management using 
# keychain and ensures the system locale is set to UTF-8. Designed to save time 
# and create a reliable, personalized shell environment across machines.
# -----------------------------------------------------------------------------

set -e

KEY_PATH="$HOME/.ssh/andrusone.dev"

echo "Installing packages..."
sudo apt update && sudo apt install -y \
  zsh curl git fzf autojump python3-pip \
  micro locales keychain

# Set locale
sudo locale-gen en_US.UTF-8

echo "Installing Oh My Zsh..."
export RUNZSH=no
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

echo "Setting Zsh as default shell..."
chsh -s "$(which zsh)"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Clone plugins if missing
[[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] || \
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

[[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] || \
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

[[ -d "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" ]] || \
  git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"

# Set plugins in .zshrc
sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting z autojump fasd colored-man-pages safe-paste history-substring-search alias-finder docker kubectl aws python node virtualenv pip fzf)/' "$HOME/.zshrc"

# Add PATH, vivid, and keychain SSH agent block
if ! grep -q '### custom shell setup' "$HOME/.zshrc"; then
  {
    echo ''
    echo '### custom shell setup'
    echo "export PATH=\"\$HOME/.cargo/bin:\$PATH\""
    echo ''
    echo '# Use vivid for Solarized LS_COLORS'
    echo 'if command -v vivid >/dev/null 2>&1; then'
    echo "  export LS_COLORS=\"\$(vivid generate solarized-dark)\""
    echo 'fi'
    echo ''
    echo '# Load SSH key using keychain'
    echo "eval \"\$(keychain --eval --quiet $KEY_PATH)\""
  } >> "$HOME/.zshrc"
fi

# Install rustup for vivid
if ! command -v rustup >/dev/null 2>&1; then
  echo "Installing rustup..."
  sudo apt remove -y rustc || true
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  # shellcheck source=/dev/null
  source "$HOME/.cargo/env"
fi

# Install vivid via cargo
echo "Installing vivid..."
cargo install vivid

# Setup micro with Solarized
mkdir -p "$HOME/.config/micro/colors"
curl -o "$HOME/.config/micro/colors/solarized-dark.micro" https://raw.githubusercontent.com/zyedidia/micro-colorschemes/master/colorschemes/solarized-dark.micro
echo '{ "colorscheme": "solarized-dark" }' > "$HOME/.config/micro/settings.json"

# Ensure SSH config has GitHub host config
SSH_CONFIG="$HOME/.ssh/config"
if ! grep -q "Host github.com" "$SSH_CONFIG" 2>/dev/null; then
  echo "Adding GitHub to SSH config..."
  {
    echo ""
    echo "Host github.com"
    echo "  HostName github.com"
    echo "  User git"
    echo "  IdentityFile $KEY_PATH"
    echo "  IdentitiesOnly yes"
  } >> "$SSH_CONFIG"
fi

echo "Done. Restart your terminal or run 'exec zsh' to start using the new environment."

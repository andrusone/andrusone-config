#!/bin/bash

# Update and install base packages
sudo apt update && sudo apt install -y \
  zsh curl git fzf autojump python3-pip \
  micro locales

# Set locale for colored man pages
sudo locale-gen en_US.UTF-8

# Install Oh My Zsh (skip auto-run)
export RUNZSH=no
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Set Zsh as the default shell for current user
chsh -s "$(which zsh)"

# Define Oh My Zsh custom plugin directory
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Install external plugins (skip if already present)
[[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] || \
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

[[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] || \
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

[[ -d "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" ]] || \
  git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"

# Update plugin list in .zshrc
sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting z autojump fasd colored-man-pages safe-paste history-substring-search alias-finder docker kubectl aws python node virtualenv pip fzf)/' "$HOME/.zshrc"

# Add PATH and vivid LS_COLORS block safely
{
  echo ''
  echo "# Add cargo to PATH"
  echo "export PATH=\"\$HOME/.cargo/bin:\$PATH\""
  echo ''
  echo "# Apply Solarized LS_COLORS if vivid is available"
  echo "if command -v vivid >/dev/null 2>&1; then"
  echo "  export LS_COLORS=\"\$(vivid generate solarized-dark)\""
  echo "fi"
} >> "$HOME/.zshrc"

# Install rustup (to get modern rustc for vivid)
if ! command -v rustup >/dev/null 2>&1; then
  sudo apt remove -y rustc || true
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  # shellcheck source=/dev/null
  source "$HOME/.cargo/env"
fi

# Install vivid using modern Rust
cargo install vivid

# Set up micro with Solarized Dark theme
mkdir -p "$HOME/.config/micro/colors"
curl -o "$HOME/.config/micro/colors/solarized-dark.micro" https://raw.githubusercontent.com/zyedidia/micro-colorschemes/master/colorschemes/solarized-dark.micro
echo '{ "colorscheme": "solarized-dark" }' > "$HOME/.config/micro/settings.json"

echo -e "\n✅ Zsh shell environment setup complete. Run 'exec zsh' or open a new terminal session."

#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"

echo "==> Dotfiles installer"

# Install Homebrew if not present
if ! command -v brew &>/dev/null; then
  echo "==> Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Install stow if not present
if ! command -v stow &>/dev/null; then
  echo "==> Installing GNU Stow..."
  brew install stow
fi

# Clone dotfiles if not already cloned
if [ ! -d "$DOTFILES_DIR" ]; then
  echo "==> Cloning dotfiles..."
  git clone git@github.com:shaiu/dotfiles.git "$DOTFILES_DIR"
fi

cd "$DOTFILES_DIR"

# Install Oh My Zsh if not present
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "==> Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install zsh-defer plugin if not present
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-defer" ]; then
  echo "==> Installing zsh-defer..."
  git clone https://github.com/romkatv/zsh-defer.git "$HOME/.oh-my-zsh/custom/plugins/zsh-defer"
fi

# Install zsh-completions plugin if not present
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-completions" ]; then
  echo "==> Installing zsh-completions..."
  git clone https://github.com/zsh-users/zsh-completions.git "$HOME/.oh-my-zsh/custom/plugins/zsh-completions"
fi

# Install fzf-git.sh if not present
if [ ! -d "$HOME/fzf-git.sh" ]; then
  echo "==> Installing fzf-git.sh..."
  git clone https://github.com/junegunn/fzf-git.sh.git "$HOME/fzf-git.sh"
fi

# Install tmux plugin manager if not present
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "==> Installing tmux plugin manager..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# Stow all packages (--adopt moves existing files into the repo)
PACKAGES=(zsh git tmux nvim vim wezterm herdr aerospace karabiner p10k ssh)
echo "==> Stowing packages: ${PACKAGES[*]}"
for pkg in "${PACKAGES[@]}"; do
  echo "    Stowing $pkg..."
  stow -v --target="$HOME" "$pkg" 2>&1 | grep -v "^$" || true
done

# Install Homebrew packages
if [ -f "$DOTFILES_DIR/Brewfile" ]; then
  echo "==> Installing Homebrew packages from Brewfile..."
  brew bundle --file="$DOTFILES_DIR/Brewfile" 2>&1 | tail -5
fi

echo ""
echo "==> Done! Please:"
echo "    1. Create ~/.zshrc.local with your machine-specific secrets"
echo "    2. Create ~/.gitconfig.work with your work email (if applicable)"
echo "    3. Open a new terminal to verify everything works"

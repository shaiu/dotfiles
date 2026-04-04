# dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Quick Start

```bash
# Clone and install
git clone git@github.com:shaiu/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

## Packages

| Package | What it manages |
|---------|----------------|
| `zsh` | Shell config, aliases, functions |
| `git` | Git config with delta pager |
| `tmux` | Tmux config with TPM plugins |
| `nvim` | Neovim config (Lua-based, lazy.nvim) |
| `vim` | Vim config with vim-plug |
| `wezterm` | WezTerm terminal emulator |
| `aerospace` | AeroSpace tiling window manager |
| `karabiner` | Karabiner-Elements keyboard remapping |
| `p10k` | Powerlevel10k prompt theme |
| `ssh` | SSH config (no keys) |

## Selective Install

Stow only the packages you want:

```bash
cd ~/dotfiles
stow zsh tmux nvim  # only these three
```

## Machine-Specific Config

Secrets and work-specific settings go in local files (gitignored):

- `~/.zshrc.local` - Shell secrets, work exports, machine-specific aliases
- `~/.gitconfig.work` - Work email (auto-included for repos under `~/git/`)

## Brew Packages

```bash
brew bundle --file=~/dotfiles/Brewfile
```

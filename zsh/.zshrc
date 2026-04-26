# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# zsh-defer for lazy loading slow commands
source ~/.oh-my-zsh/custom/plugins/zsh-defer/zsh-defer.plugin.zsh

# Cache brew --prefix (avoid subprocess calls)
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Which plugins would you like to load?
plugins=(
	git
	zsh-completions
	kubectl
	kubectx
)

HISTTIMEFORMAT="%F %T "

FPATH="/opt/homebrew/share/zsh/site-functions:${FPATH}"
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src
source $ZSH/oh-my-zsh.sh

# Report current working directory to terminal via OSC 7 (for wezterm tab titles)
autoload -Uz add-zsh-hook
_osc7_cwd() {
  if [[ -n "$TMUX" ]]; then
    # Wrap in DCS passthrough for tmux
    printf '\ePtmux;\e\e]7;file://%s%s\e\e\\\e\\' "${HOST}" "${PWD}"
  else
    printf '\e]7;file://%s%s\e\\' "${HOST}" "${PWD}"
  fi
}
add-zsh-hook chpwd _osc7_cwd
zsh-defer _osc7_cwd  # report on shell startup too

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# Load aliases (using glob instead of find)
for f in ~/.config/zsh/alias.d/*.alias(N); do
  source "$f"
done

# Load functions (using glob instead of find)
for f in ~/.config/zsh/functions/*(N.); do
  source "$f"
done

# Load env (using glob instead of find)
for f in ~/.config/zsh/env/**/*(N.); do
  source "$f"
done

# Coursier
export COURSIER_HOME=/usr/local/coursier
export COURSIER_BIN_DIR=$COURSIER_HOME/bin
export PATH=$COURSIER_HOME/bin:$PATH

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

autoload bashcompinit
bashcompinit
# Defer argcomplete initialization (slow)
zsh-defer eval "$(register-python-argcomplete pipx)"

export GIT_HOME=~/git

# NVM setup
export NVM_DIR="$HOME/.nvm"
zsh-defer -c '[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"'
zsh-defer -c '[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"'

# history setup
HISTFILE=$HOME/.zhistory
SAVEHIST=1000
HISTSIZE=999
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify

# completion using arrow keys (based on history)
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# ---- FZF -----

# Set up fzf key bindings and fuzzy completion (deferred)
zsh-defer eval "$(fzf --zsh)"

# -- Use fd instead of fzf --

export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Use fd (https://github.com/sharkdp/fd) for listing path candidates.
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

source ~/fzf-git.sh/fzf-git.sh

# --- setup fzf theme ---
export FZF_DEFAULT_OPTS='--color=fg:-1,fg+:#edd5be,bg:-1,bg+:-1
  --color=hl:#ca5a83,hl+:#ca5a83,info:#695444,marker:#ceb250
  --color=prompt:#695444,spinner:#bfac99,pointer:#bfac99,header:#edd5be
  --color=border:#5b4839,label:#bfac99,query:#edd5be,disabled:#695444
  --border="rounded" --border-label="" --preview-window="border-rounded" --prompt="> "
  --marker=">" --pointer="▪︎" --separator="─" --scrollbar="│"
  --info="right"'


show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# Advanced customization of fzf options via _fzf_comprun function
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
    export|unset) fzf --preview "eval 'echo ${}'"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
  esac
}
# ----- Bat (better cat) -----

export BAT_THEME=tokyonight_night

# ---- Eza (better ls) -----

alias ls="eza --color=always --long --git --no-filesize --icons=always --time-style=long-iso --no-user"

# thefuck alias (deferred - saves ~200-400ms)
zsh-defer eval "$(thefuck --alias)"
zsh-defer eval "$(thefuck --alias fk)"

# ---- Zoxide (better cd) ----
zsh-defer eval "$(zoxide init zsh)"
zsh-defer alias cd="z"

alias python="python3"
alias python3="python3"

export GOPATH=~/go
export PATH=$PATH:$GOPATH/bin

export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export PUPPETEER_EXECUTABLE_PATH="/opt/homebrew/bin/chromium"

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Created by `pipx`
export PATH="$PATH:$HOME/.local/bin"

# Source machine-local secrets and work-specific config (not in dotfiles repo)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

export CLAUDE_CODE_NO_FLICKER=1

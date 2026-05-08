#!/bin/bash

# ============================================================
# Common Shell Configuration
# Shared between bash and zsh
# ============================================================

# ============================================================
# Initialization(set up env)
# ============================================================
export DOT_FILES="${DOT_FILES:-$HOME/Documents/dotfiles}"
if [ -f "$DOT_FILES/utils/add_path" ]; then
    source "$DOT_FILES/utils/add_path"
else
    echo "add_path() not found at $DOT_FILES/utils/add_path; skipping shared shell setup." >&2
    return 0 2>/dev/null || exit 0
fi

add_path "$DOT_FILES/utils"
add_path "/usr/local/bin"
add_path "$HOME/.local/bin"

# macOS-specific
if [[ "$(uname -s)" == "Darwin" ]]; then
    # Prioritize Homebrew paths (added last to be first in PATH)
    add_path "/opt/homebrew/sbin"
    add_path "/opt/homebrew/bin"

    # Disable homebrew sending analytics data
    export HOMEBREW_NO_ANALYTICS=1
fi

# fixing color code output in man command
export MANROFFOPT="-c"

# disable virtualenv prompt
export VIRTUAL_ENV_DISABLE_PROMPT=1

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# ============================================================
# Welcome Message
# ============================================================
# print welcome msg
if [ "${DOTFILES_DISABLE_WELCOME:-0}" != "1" ] \
    && [ "${TERM:-}" != "dumb" ] \
    && command -v shell_welcome &> /dev/null; then
  echo ""
  msg="$(shell_welcome 2>/dev/null)"
  if [ -n "$msg" ]; then
    if [ -z "${SSH_CONNECTION:-}" ] \
        && [ "${DOTFILES_DISABLE_ANIMATED_WELCOME:-0}" != "1" ] \
        && command -v lolcat &> /dev/null; then
      echo -e "$msg\n" | lolcat --animate --duration=1 --speed=120 --freq=0.05 --truecolor
    else
      echo -e "$msg\n"
    fi
  fi
fi

# ============================================================
# FZF Configuration
# ============================================================
# Setup fzf (installed with git)
add_path "$HOME/.local/share/fzf/bin"

# Shell-specific fzf initialization
if command -v fzf &> /dev/null; then
  if [ -n "$ZSH_VERSION" ]; then
    source <(fzf --zsh)
  elif [ -n "$BASH_VERSION" ]; then
    eval "$(fzf --bash)"
  fi
fi

if command -v fd &> /dev/null; then
  export FZF_DEFAULT_COMMAND='fd --unrestricted'
  export FZF_CTRL_T_COMMAND='fd --unrestricted'
  export FZF_ALT_C_COMMAND='fd --type d'
else
  export FZF_DEFAULT_COMMAND='find . -path "*/.git" -prune -o -print'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='find . -path "*/.git" -prune -o -type d -print'
fi

if command -v bat &> /dev/null; then
  _DOTFILES_FZF_FILE_PREVIEW='bat -n --color=always {}'
else
  _DOTFILES_FZF_FILE_PREVIEW='sed -n "1,200p" {}'
fi

if command -v tree &> /dev/null; then
  _DOTFILES_FZF_DIR_PREVIEW='tree -C {} | head -200'
else
  _DOTFILES_FZF_DIR_PREVIEW='find {} -maxdepth 2 -print | sed -n "1,200p"'
fi

export FZF_DEFAULT_OPTS="
  --height=60% --layout=reverse --info=inline --border --margin=1 --padding=1"

# apply tmux mode when accessible
export FZF_TMUX_OPTS='-p 80%,60%'

# Use ~~ as the trigger sequence instead of the default **
export FZF_COMPLETION_TRIGGER='~~'
export FZF_COMPLETION_OPTS='--border --info=inline'

export FZF_CTRL_T_OPTS="
  --walker-skip .git
  --preview '$_DOTFILES_FZF_FILE_PREVIEW'
  --bind 'ctrl-/:toggle-preview'"

# CTRL-R filters command history
export FZF_CTRL_R_OPTS="
  --preview 'echo {}' --preview-window up:3:hidden:wrap
  --bind 'ctrl-/:toggle-preview'"

export FZF_ALT_C_OPTS="
  --walker-skip .git
  --preview '$_DOTFILES_FZF_DIR_PREVIEW'
  --bind 'ctrl-/:toggle-preview'"

_fzf_compgen_path() {
  if command -v fd &> /dev/null; then
    fd --unrestricted --follow --exclude ".git" . "$1"
  else
    find "${1:-.}" -path "*/.git" -prune -o -print
  fi
}

_fzf_compgen_dir() {
  if command -v fd &> /dev/null; then
    fd --type d --unrestricted --follow --exclude ".git" . "$1"
  else
    find "${1:-.}" -path "*/.git" -prune -o -type d -print
  fi
}

# Advanced customization of fzf options via _fzf_comprun function
# - The first argument to the function is the name of the command.
# - You should make sure to pass the rest of the arguments to fzf.
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview "$_DOTFILES_FZF_DIR_PREVIEW" "$@" ;;
    export|unset) fzf --preview "eval 'echo \$'{}"         "$@" ;;
    ssh)          fzf --preview 'command -v dig >/dev/null 2>&1 && dig {} || printf "%s\n" {}' "$@" ;;
    *)            fzf --preview "$_DOTFILES_FZF_FILE_PREVIEW" "$@" ;;
  esac
}

# ============================================================
# Aliases
# ============================================================
# correcting mistake-typing
alias ..="cd .."
alias ll="ls -lath --color=auto" # long listing + all files + time order + human-readable sizes
alias lll="ls -lah --color=auto" # long listing + all files + human-readable sizes
alias la="ll"
alias lsa="ll"
alias ls="ls --color=auto"
alias sl="ls"
alias l="ls"
alias dc="cd"
alias cl="clear"

# secure-typing
alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"

# trash-cli
alias trash="trash-put"
alias tlist="trash-list"
alias trestore="trash-restore"
alias tempty="trash-empty"
alias trm="trash-rm"

# short-command
alias tls="tmux ls"
alias tks="tmux kill-session -t"

# conda
alias condaa="conda activate"
alias condad="conda deactivate"

# configuration
alias bashConfig="nvim $HOME/.bashrc"
alias zshConfig="nvim $HOME/.zshrc"
alias vimConfig="nvim $HOME/.vimrc"
alias nvimConfig="nvim $HOME/.config/nvim/init.lua"
alias tmuxConfig="nvim $HOME/.tmux.conf"
alias ohmyzshConfig="nvim $HOME/.oh-my-zsh"

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# git-short-command
alias gs="git status"
alias gc="git commit"
alias gl="git log --decorate=auto --graph --oneline"
alias gll="git log --decorate=auto --graph"
alias gla="git log --decorate=auto --graph --all --oneline"
alias glaa="git log --decorate=auto --graph --all"
alias gsl="git stash list"
alias gsp="git stash pop"
alias gsa="git stash apply"

# tmuxp: load session
alias mux="tmuxp load"

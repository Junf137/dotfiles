#!/bin/bash

# ============================================================
# Common Shell Configuration
# Shared between bash and zsh
# ============================================================

# ============================================================
# Initialization(set up env)
# ============================================================
export DOT_FILES="$HOME/Documents/dotfiles"
[ -f "$DOT_FILES/utils/add_path" ] && source "$DOT_FILES/utils/add_path" || echo "add_path() not found."

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
echo ""
# assemble output of shell_welcome and cowsay_fortune
msg="$(shell_welcome)\n"

if command -v lolcat &> /dev/null; then
  echo -e "$msg" | lolcat --animate --duration=1 --speed=120 --freq=0.05 --truecolor
else
  echo -e "$msg"
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

export FZF_DEFAULT_COMMAND='fd --unrestricted'
export FZF_DEFAULT_OPTS="
  --height=60% --layout=reverse --info=inline --border --margin=1 --padding=1"

# apply tmux mode when accessible
export FZF_TMUX_OPTS='-p 80%,60%'

# Use ~~ as the trigger sequence instead of the default **
export FZF_COMPLETION_TRIGGER='~~'
export FZF_COMPLETION_OPTS='--border --info=inline'

# CTRL-T runs $FZF_CTRL_T_COMMAND to get a list of files and directories
export FZF_CTRL_T_COMMAND="fd --unrestricted"
export FZF_CTRL_T_OPTS="
  --walker-skip .git
  --preview 'bat -n --color=always {}'
  --bind 'ctrl-/:toggle-preview'"

# CTRL-R filters command history
export FZF_CTRL_R_OPTS="
  --preview 'echo {}' --preview-window up:3:hidden:wrap
  --bind 'ctrl-/:toggle-preview'"

# ALT-C runs $FZF_ALT_C_COMMAND to get a list of directories
export FZF_ALT_C_COMMAND="fd --type d"
export FZF_ALT_C_OPTS="
  --walker-skip .git
  --preview 'tree -C {}'
  --bind 'ctrl-/:toggle-preview'"

_fzf_compgen_path() {
  fd --unrestricted --follow --exclude ".git" . "$1"
}

_fzf_compgen_dir() {
  fd --type d --unrestricted --follow --exclude ".git" . "$1"
}

# Advanced customization of fzf options via _fzf_comprun function
# - The first argument to the function is the name of the command.
# - You should make sure to pass the rest of the arguments to fzf.
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'tree -C {} | head -200'   "$@" ;;
    export|unset) fzf --preview "eval 'echo \$'{}"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    *)            fzf --preview 'bat -n --color=always {}' "$@" ;;
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

# Activate venv in computer canada cluster
alias venv_mm_selfsup="source $DOT_FILES/utils/venv_mm_selfsup"

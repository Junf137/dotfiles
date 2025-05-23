# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac


# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    # PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
    PS1="\[\033[01;31m\]\u\[\033[00m\]@\[\033[01;32m\]\h:\[\033[01;34m\]\w\[\033[00m\]\n$ "
    # PS1="\[\033[01;31m\]\u\[\033[00m\]@\[\033[01;32m\]\h\[\033[00m\][\[\033[01;33m\]\t\[\033[00m\]]:\[\033[01;34m\]\W\[\033[00m\] $ "

else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi



# ============================================================
# Initialization(set up env)
# ============================================================
export DOT_FILES="$HOME/Documents/dotfiles"
export PATH="$DOT_FILES/utils:$PATH"

# rust path setup
export RUSTUP_HOME="$HOME/.local/share/rustup"
export CARGO_HOME="$HOME/.local/share/cargo"

# fixing color code output in man command
export MANROFFOPT="-c"

# If not running interactively, don't do anything ???
case $- in
    *i*) ;;
      *) return;;
esac

# print welcome msg
echo ""
# assemble output of shell_welcome and cowsay_fortune
msg="$(shell_welcome)\n$(cowsay_fortune)"

if command -v lolcat &> /dev/null; then
  echo -e "$msg" | lolcat --animate --duration=1 --speed=120 --freq=0.05 --truecolor
else
  echo -e "$msg"
fi



# ============================================================
# custom bash-script
# ============================================================
# Setup fzf (installed with git)
# ---------
if [[ ! "$PATH" == *$HOME/.local/share/fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}$HOME/.local/share/fzf/bin"
fi

# if fzf command exist
if command -v fzf &> /dev/null; then
  eval "$(fzf --bash)"
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

# correcting mistake-typing
alias ..="cd .."
alias ll="ls -lath --color=auto"
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

# ============================================================
# keymapping
# ============================================================
# hjkl move
# bindkey '\eh' backward-char
# bindkey '\el' forward-char
# bindkey '\ej' down-line-or-history
# bindkey '\ek' up-line-or-history
# bindkey '\eH' backward-word
# bindkey '\eL' forward-word
# bindkey '\eJ' beginning-of-line
# bindkey '\eK' end-of-line
#
# bindkey -s '\ev' 'vim\n'
# bindkey -s '\eu' 'cd ..\n'
# bindkey -s '\ei' 'll \n'
# bindkey -s '\eI' 'ls \n'
#
# # up, down, left, right
# bindkey '\e[1;3D' backward-word
# bindkey '\e[1;3C' forward-word
# bindkey '\e[1;3A' beginning-of-line
# bindkey '\e[1;3B' end-of-line
#
# bindkey '\ef' autosuggest-accept

# If you come from bash you might have to change your $PATH.
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.local/share/oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="ys_customized"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="yyyy-mm-dd"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
    z
    fzf
    git
    sudo
    zsh-bat
    you-should-use
    zsh-autosuggestions
    zsh-syntax-highlighting
)
# zsh-syntax-highlighting needs to be the last one parsed

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='mvim'
fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"



# ============================================================
# Initialization(set up env)
# ============================================================
export DOT_FILES="$HOME/Documents/dotfiles"
export PATH="$DOT_FILES/utils:$PATH"

# rust path setup
export RUSTUP_HOME="$HOME/.local/share/rustup"
export CARGO_HOME="$HOME/.local/share/cargo"

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
# custom zsh-script
# ============================================================
# Setup fzf
if [[ ! "$PATH" == *$HOME/.local/share/fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}$HOME/.local/share/fzf/bin"
fi

eval "$(fzf --zsh)"

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
# Use showkey -a to show keybindings

# hjkl move
bindkey '\eh' backward-word
bindkey '\el' forward-word
bindkey '\ej' beginning-of-line
bindkey '\ek' end-of-line
bindkey '\eH' backward-char
bindkey '\eL' forward-char
bindkey '\eJ' down-line-or-history
bindkey '\eK' up-line-or-history

# up, down, left, right
bindkey '\e[1;3D' backward-word
bindkey '\e[1;3C' forward-word
bindkey '\e[1;3A' beginning-of-line
bindkey '\e[1;3B' end-of-line

# Alt + Backspace kill one word
bindkey '^U' backward-kill-word
# Alt + Shift + Backspace kill one line
bindkey '^[^?' backward-kill-line

# conflect with wezterm finding shortcut
# bindkey '\ef' autosuggest-accept

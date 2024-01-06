# If you come from bash you might have to change your $PATH.
export PATH=/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.local/share/oh-my-zsh

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
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
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"



# ============================================================
# Initialization(set up env)
# ============================================================
export PATH="$HOME/.local/bin:$PATH"
export TRASH="$HOME/.local/share/Trash"
export DOT_FILES="$HOME/Documents/dotfiles"

# rust path setup
export RUSTUP_HOME="$HOME/.local/share/rustup"
export CARGO_HOME="$HOME/.local/share/cargo"

# If not running interactively, don't do anything ???
case $- in
    *i*) ;;
      *) return;;
esac

# print welcome msg
cat "$DOT_FILES/msg/msg_welcome"



# ============================================================
# custom zsh-script
# ============================================================
source $DOT_FILES/utils/update_auto.sh


# correting mistake-typing
alias ..="cd .."
alias ll="ls -lath --color=auto"
alias la="ll"
alias lsa="ll"
alias ls="ls --color=auto"
alias sl="ls"
alias l="ls"
alias dc="cd"


# secur-typing
alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"

# trash-cli
alias tcd="cd $TRASH"
alias tlist="trash-list"
alias trestore="trash-restore"
alias trm="trash-rm"
alias tempty="trash-empty"

# short-command
alias tls="tmux ls"
alias tks="tmux kill-session -t"

# conda
alias condaa="conda activate"
alias condad="conda deactivate"

# vim-configuration
alias bashConfig="vim $HOME/.bashrc"
alias zshConfig="vim $HOME/.zshrc"
alias vimConfig="vim $HOME/.vimrc"
alias tmuxConfig="vim $HOME/.tmux.conf"
alias ohmyzshConfig="vim $HOME/.oh-my-zsh"

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# git-short-command
alias gs="git status"
alias gc="git commit"
alias gl="git log --decorate --graph --oneline"
alias gll="git log --decorate --graph"
alias gla="git log --decorate --graph --all --oneline"
alias glaa="git log --decorate --graph --all"


# ============================================================
# keymapping
# ============================================================
# hjkl move
bindkey '\eh' backward-char
bindkey '\el' forward-char
bindkey '\ej' down-line-or-history
bindkey '\ek' up-line-or-history
bindkey '\eH' backward-word
bindkey '\eL' forward-word
bindkey '\eJ' beginning-of-line
bindkey '\eK' end-of-line

bindkey -s '\ev' 'vim\n'
bindkey -s '\eu' 'cd ..\n'
bindkey -s '\ei' 'll \n'
bindkey -s '\eI' 'ls \n'

# up, down, left, right
bindkey '\e[1;3D' backward-word
bindkey '\e[1;3C' forward-word
bindkey '\e[1;3A' beginning-of-line
bindkey '\e[1;3B' end-of-line

bindkey '\ef' autosuggest-accept

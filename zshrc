# Path to your Oh My Zsh installation.
export ZSH="$HOME/.local/share/oh-my-zsh"

ZSH_THEME="ys_customized"
HYPHEN_INSENSITIVE="true"
zstyle ':omz:update' mode reminder
COMPLETION_WAITING_DOTS="true"
HIST_STAMPS="yyyy-mm-dd"

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

# Add brew plugin on macOS
[[ "$OSTYPE" == darwin* ]] && plugins+=(brew)

source $ZSH/oh-my-zsh.sh

# Preferred editor: nvim > vim > vi
if command -v nvim &>/dev/null; then
  export EDITOR='nvim'
elif command -v vim &>/dev/null; then
  export EDITOR='vim'
else
  export EDITOR='vi'
fi

# ============================================================
# Source common shell configuration
# ============================================================
export DOT_FILES="${${(%):-%N}:A:h}"
[ -f "$DOT_FILES/shell_common.sh" ] && source "$DOT_FILES/shell_common.sh"

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

# Terminal deletion keys from WezTerm. Keep Ctrl+Backspace distinct from tmux C-h navigation.
bindkey '^?' backward-delete-char
bindkey '^W' backward-kill-word
bindkey '^U' backward-kill-line
bindkey '\e[3;3~' kill-line
bindkey '\e[3;5~' kill-word
bindkey '^[^?' backward-kill-word

# conflict with wezterm finding shortcut
# bindkey '\ef' autosuggest-accept

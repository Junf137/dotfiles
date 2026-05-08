#!/usr/bin/env bash

# Central symlink manifest for bootstrap.sh and cleanup_backups.sh.
#
# Callers must set DOT_FILES before sourcing this file. ZSH and ZSH_CUSTOM may be
# set by callers; defaults are provided here for the standard local install.

_link_manifest_add() {
    LINK_SOURCES+=("$1")
    LINK_DESTS+=("$2")
    LINK_REQUIRED+=("${3:-required}")
    LINK_LABELS+=("${4:-$2}")
}

load_link_manifest() {
    if [ -z "${DOT_FILES:-}" ]; then
        echo "DOT_FILES must be set before loading link manifest" >&2
        return 1
    fi

    ZSH="${ZSH:-$HOME/.local/share/oh-my-zsh}"
    ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"

    LINK_SOURCES=()
    LINK_DESTS=()
    LINK_REQUIRED=()
    LINK_LABELS=()

    _link_manifest_add "$DOT_FILES/bashrc" "$HOME/.bashrc" required "bashrc"
    _link_manifest_add "$DOT_FILES/zshrc" "$HOME/.zshrc" required "zshrc"
    _link_manifest_add "$DOT_FILES/vimrc" "$HOME/.vimrc" required "vimrc"
    _link_manifest_add "$DOT_FILES/condarc" "$HOME/.condarc" required "condarc"
    _link_manifest_add "$DOT_FILES/tmux.conf" "$HOME/.tmux.conf" required "tmux"
    _link_manifest_add "$DOT_FILES/gitconfig" "$HOME/.gitconfig" required "gitconfig"
    _link_manifest_add "$DOT_FILES/tmuxp" "$HOME/.tmuxp" required "tmuxp"
    _link_manifest_add "$DOT_FILES/tmux/tmux-nerd-font-window-name.yml" "$HOME/.config/tmux/tmux-nerd-font-window-name.yml" required "tmux window name plugin"

    _link_manifest_add "$DOT_FILES/omz_themes/ys_customized.zsh-theme" "$ZSH_CUSTOM/themes/ys_customized.zsh-theme" required "oh-my-zsh ys theme"

    _link_manifest_add "$DOT_FILES/nvim/nvim-kickstart" "$HOME/.config/nvim" required "nvim"
    _link_manifest_add "$DOT_FILES/wezterm/wezterm-config" "$HOME/.config/wezterm" required "wezterm"
    _link_manifest_add "$DOT_FILES/alacritty/alacritty-default" "$HOME/.config/alacritty" required "alacritty"
    _link_manifest_add "$DOT_FILES/yazi" "$HOME/.config/yazi" required "yazi"

    _link_manifest_add "$DOT_FILES/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md" required "Claude global instructions"
    _link_manifest_add "$DOT_FILES/claude/settings.json" "$HOME/.claude/settings.json" required "Claude settings"
    _link_manifest_add "$DOT_FILES/agent-skills/claude" "$HOME/.claude/skills" required "Claude skills"
    _link_manifest_add "$DOT_FILES/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh" required "Claude statusline"

    _link_manifest_add "$DOT_FILES/codex/AGENTS.md" "$HOME/.codex/AGENTS.md" required "Codex global instructions"
    _link_manifest_add "$DOT_FILES/codex/config.toml" "$HOME/.codex/config.toml" required "Codex config"
    _link_manifest_add "$DOT_FILES/agent-skills/codex" "$HOME/.agents/skills" required "Codex skills"

    _link_manifest_add "$DOT_FILES/nvim/markdownlint.jsonc" "$HOME/.markdownlint.jsonc" required "markdownlint"

    # External, user-managed image directory. It is useful when present but should
    # not block bootstrap checks on a fresh machine.
    _link_manifest_add "$HOME/Pictures/Background" "$HOME/.config/wezterm/backdrops" optional "wezterm backdrops"
}

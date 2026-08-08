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

# Requirement tier for an entry that only means anything on one kernel: it is
# `required` there and `skip` everywhere else. Callers treat `skip` as "not
# applicable on this platform" -- not linked, not warned about, and reported as
# a skip rather than an OK, so a Linux-only rule cannot read as installed on a
# Mac. Keeps one manifest for both machines instead of branching the repo.
_link_manifest_tier_for() {
    if [ "$(uname -s)" = "$1" ]; then
        printf 'required'
    else
        printf 'skip'
    fi
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
    _link_manifest_add "$DOT_FILES/codex/hooks.json" "$HOME/.codex/hooks.json" required "Codex hooks"
    _link_manifest_add "$DOT_FILES/agent-skills/codex" "$HOME/.agents/skills" required "Codex skills"

    _link_manifest_add "$DOT_FILES/nvim/markdownlint.jsonc" "$HOME/.markdownlint.jsonc" required "markdownlint"

    # Handoff pruning is the same policy through two different schedulers:
    # systemd-tmpfiles on Linux, a launchd agent on macOS. Neither exists on the
    # other platform, so each is gated to its own.
    _link_manifest_add "$DOT_FILES/tmpfiles/handoffs.conf" "$HOME/.config/user-tmpfiles.d/handoffs.conf" \
        "$(_link_manifest_tier_for Linux)" "handoff cleanup rules (systemd-tmpfiles)"
    _link_manifest_add "$DOT_FILES/launchd/com.junf.prune-handoffs.plist" "$HOME/Library/LaunchAgents/com.junf.prune-handoffs.plist" \
        "$(_link_manifest_tier_for Darwin)" "handoff cleanup agent (launchd)"

    # External, user-managed image directory. It is useful when present but should
    # not block bootstrap checks on a fresh machine.
    _link_manifest_add "$HOME/Pictures/Background" "$HOME/.config/wezterm/backdrops" optional "wezterm backdrops"
}

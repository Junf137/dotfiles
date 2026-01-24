#!/bin/bash

# __author__ == Junfeng Lei
# --------------------------------
# Description:
#   Remove redundant backup symlinks created by bootstrap.sh
#   Only removes .bak files that are symlinks pointing to the same target
#   as the current file (safe to remove).
#
# Usage:
#   ./cleanup_backups.sh           # Dry-run (shows what would be deleted)
#   ./cleanup_backups.sh -f        # Force mode (actually deletes files)
#   ./cleanup_backups.sh --force   # Force mode (actually deletes files)
# --------------------------------

FORCE_MODE=false

# Parse command line arguments
for arg in "$@"; do
    case "$arg" in
        -f|--force) FORCE_MODE=true ;;
        -h|--help)
            echo "Usage: $0 [-f|--force]"
            echo "  -f, --force  Actually remove files (default is dry-run)"
            echo "  -h, --help   Show this help message"
            exit 0
            ;;
    esac
done

# ---* Global env *---
export DOT_FILES="$HOME/Documents/dotfiles"
export ZSH="$HOME/.local/share/oh-my-zsh"
export ZSH_CUSTOM="$ZSH/custom"

# Same files array as bootstrap.sh
files=(
    # 1. links to home directory
    "$DOT_FILES/bashrc:$HOME/.bashrc"
    "$DOT_FILES/zshrc:$HOME/.zshrc"
    "$DOT_FILES/vimrc:$HOME/.vimrc"
    "$DOT_FILES/condarc:$HOME/.condarc"
    "$DOT_FILES/tmux.conf:$HOME/.tmux.conf"
    "$DOT_FILES/gitconfig:$HOME/.gitconfig"
    "$DOT_FILES/tmuxp:$HOME/.tmuxp"

    # 2. links to oh-my-zsh themes
    "$DOT_FILES/omz_themes/ys_customized.zsh-theme:$ZSH_CUSTOM/themes/ys_customized.zsh-theme"

    # 3. links to .config directory
    "$DOT_FILES/nvim/nvim-kickstart:$HOME/.config/nvim"
    "$DOT_FILES/wezterm/wezterm-config:$HOME/.config/wezterm"
    "$DOT_FILES/alacritty/alacritty-default:$HOME/.config/alacritty"

    # 4. links to Claude Code config
    "$DOT_FILES/claude/CLAUDE.md:$HOME/.claude/CLAUDE.md"
    "$DOT_FILES/claude/settings.json:$HOME/.claude/settings.json"

    # 5. links for wezterm backdrops (external images)
    "/home/junf/Pictures/Background:$HOME/.config/wezterm/backdrops"

    # Append more files here...
)

removed_count=0

cleanup_backup() {
    dst_name="$1"

    for backup in "$dst_name".*.bak; do
        # Skip if no matches (glob returns literal pattern)
        [ -e "$backup" ] || continue

        # Only process symlinks
        [ -L "$backup" ] || continue

        # Current file must also be a symlink
        [ -L "$dst_name" ] || continue

        backup_target=$(readlink "$backup")
        current_target=$(readlink "$dst_name")

        if [ "$backup_target" = "$current_target" ]; then
            if $FORCE_MODE; then
                rm "$backup"
                echo "Removed: $backup"
            else
                echo "[dry-run] Would remove: $backup"
            fi
            removed_count=$((removed_count + 1))
        fi
    done
}

# Print mode
if $FORCE_MODE; then
    echo "Mode: FORCE - Removing redundant backups"
else
    echo "Mode: DRY-RUN - Showing what would be removed"
    echo "(use -f or --force to actually remove files)"
fi
echo "-------------------------------------------"

# Process each destination
for file in "${files[@]}"; do
    dest="${file#*:}"
    cleanup_backup "$dest"
done

echo "-------------------------------------------"
if $FORCE_MODE; then
    echo "Removed $removed_count redundant backup(s)"
else
    echo "Found $removed_count redundant backup(s) to remove"
fi

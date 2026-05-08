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
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

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
export DOT_FILES="${DOT_FILES:-$SCRIPT_DIR}"
export ZSH="${ZSH:-$HOME/.local/share/oh-my-zsh}"
export ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"

MANIFEST_FILE="$DOT_FILES/lib/link_manifest.sh"
if [ ! -f "$MANIFEST_FILE" ]; then
    echo "Link manifest not found: $MANIFEST_FILE" >&2
    exit 1
fi
# shellcheck source=lib/link_manifest.sh
source "$MANIFEST_FILE"
load_link_manifest || exit 1

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
for dest in "${LINK_DESTS[@]}"; do
    cleanup_backup "$dest"
done

echo "-------------------------------------------"
if $FORCE_MODE; then
    echo "Removed $removed_count redundant backup(s)"
else
    echo "Found $removed_count redundant backup(s) to remove"
fi

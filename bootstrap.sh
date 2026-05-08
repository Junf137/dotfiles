#!/bin/bash

# __author__ == Junfeng Lei
# --------------------------------
# Description:
#   Linking dot files to home directory
# usage:
#   1) ./bootstrap.sh             # Create symbolic links
#   2) ./bootstrap.sh --check     # Validate sources and audit destinations
#   3) ./bootstrap.sh --dry-run   # Show create actions without mutating
#   4) ./bootstrap.sh --restore   # Remove managed symlinks and restore backups
# --------------------------------

# ---* Global Variable *---
TIME_STAMP="$(date +'%Y_%m_%d_%H_%M_%S')"
error_cnt=0
RESTORE_MODE=false
DRY_RUN=false
CHECK_MODE=false

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

usage() {
    cat <<'USAGE'
Usage: ./bootstrap.sh [--check] [--dry-run] [--restore]

Modes:
  --check      Validate manifest sources and audit current destinations
  --dry-run    Show planned create/restore actions without changing files
  --restore    Remove only managed symlinks and restore newest backups
  -h, --help   Show this help message
USAGE
}

# Process command line arguments
for arg in "$@"; do
    case "$arg" in
        --restore)
            RESTORE_MODE=true
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        --check)
            CHECK_MODE=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if $CHECK_MODE && $RESTORE_MODE; then
    echo "--check and --restore cannot be used together." >&2
    exit 2
fi

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

LOG_FILE_NAME="bootstrap_$TIME_STAMP.log"
if $RESTORE_MODE; then
    LOG_FILE_NAME="bootstrap_restore_$TIME_STAMP.log"
elif $DRY_RUN; then
    LOG_FILE_NAME="bootstrap_dry_run_$TIME_STAMP.log"
fi

# ---* Functions *---
error_print() {
    if [ $# != 0 ]; then
        printf '\033[31m[Error]\033[0m: %s\n' "$*"
    fi

    error_cnt=$((error_cnt + 1))
}

log_print() {
    if [ $# != 0 ]; then
        printf '%b\n' "$*"
    fi
}

warn_print() {
    if [ $# != 0 ]; then
        printf '\033[33m[Warn]\033[0m: %s\n' "$*"
    fi
}

source_exists() {
    [ -e "$1" ] || [ -L "$1" ]
}

warn_for_missing_source_context() {
    case "$1" in
        "$DOT_FILES"/agent-skills/*)
            warn_print "Run 'git submodule update --init --recursive' from $DOT_FILES."
            ;;
    esac
}

validate_sources() {
    local i src required label

    for i in "${!LINK_SOURCES[@]}"; do
        src="${LINK_SOURCES[$i]}"
        required="${LINK_REQUIRED[$i]}"
        label="${LINK_LABELS[$i]}"

        if source_exists "$src"; then
            log_print "OK source: $label ($src)"
        elif [ "$required" = "optional" ]; then
            warn_print "Optional source missing, will skip: $label ($src)"
        else
            error_print "Required source missing: $label ($src)"
            warn_for_missing_source_context "$src"
        fi
    done
}

audit_destinations() {
    local i src dest target

    for i in "${!LINK_SOURCES[@]}"; do
        src="${LINK_SOURCES[$i]}"
        dest="${LINK_DESTS[$i]}"

        if [ -L "$dest" ]; then
            target="$(readlink "$dest")"
            if [ "$target" = "$src" ]; then
                log_print "OK link: $dest -> $src"
            else
                warn_print "Destination symlink points elsewhere: $dest -> $target"
            fi
        elif [ -e "$dest" ]; then
            warn_print "Destination exists and is not a managed symlink: $dest"
        else
            warn_print "Destination is not linked yet: $dest"
        fi
    done
}

newest_backup_for() {
    local dst_name="$1"
    local backup newest=""

    for backup in "$dst_name".*.bak; do
        [ -e "$backup" ] || continue
        if [ -z "$newest" ] || [[ "$backup" > "$newest" ]]; then
            newest="$backup"
        fi
    done

    printf '%s\n' "$newest"
}

create_soft_link() {
    if [ "$#" -ne 3 ]; then
        error_print "Usage: create_soft_link ori_name dst_name required"
        return 1
    fi

    local ori_name="$1"
    local dst_name="$2"
    local required="$3"
    local dst_dir target

    log_print ""
    log_print "\033[32m---* $dst_name \033[0m"

    if ! source_exists "$ori_name"; then
        if [ "$required" = "optional" ]; then
            warn_print "Optional source missing, skipping: $ori_name"
            return 0
        fi
        error_print "File '$ori_name' does not exist."
        warn_for_missing_source_context "$ori_name"
        return 1
    fi

    if [ -L "$dst_name" ]; then
        target="$(readlink "$dst_name")"
        if [ "$target" = "$ori_name" ]; then
            log_print "OK: already linked: \033[36m$dst_name -> $ori_name\033[0m"
            return 0
        fi
    fi

    if [ -e "$dst_name" ] || [ -L "$dst_name" ]; then
        warn_print "File '$dst_name' already exists."

        if $DRY_RUN; then
            log_print "[dry-run] Would rename: $dst_name -> $dst_name.$TIME_STAMP.bak"
        else
            if mv "$dst_name" "$dst_name.$TIME_STAMP.bak"; then
                log_print "File renamed: $dst_name -> $dst_name.$TIME_STAMP.bak"
            else
                error_print "Failed to rename file: $dst_name -> $dst_name.$TIME_STAMP.bak"
                return 1
            fi
        fi
    fi

    dst_dir="$(dirname "$dst_name")"
    if [ ! -d "$dst_dir" ]; then
        warn_print "Directory '$dst_dir' does not exist."

        if $DRY_RUN; then
            log_print "[dry-run] Would create directory: $dst_dir"
        else
            if mkdir -p "$dst_dir"; then
                log_print "Directory created: $dst_dir"
            else
                error_print "Failed to create directory: $dst_dir"
                return 1
            fi
        fi
    fi

    if $DRY_RUN; then
        log_print "[dry-run] Would create symbolic link: \033[36m$dst_name -> $ori_name\033[0m"
    elif ln -s "$ori_name" "$dst_name"; then
        log_print "Symbolic link created: \033[36m$dst_name -> $ori_name\033[0m"
    else
        error_print "Failed to create symbolic link: $dst_name -> $ori_name"
        return 1
    fi
}

remove_soft_link() {
    if [ "$#" -ne 2 ]; then
        error_print "Usage: remove_soft_link ori_name dst_name"
        return 1
    fi

    local ori_name="$1"
    local dst_name="$2"
    local link_target most_recent_backup

    log_print ""
    log_print "\033[32m---* $dst_name \033[0m"

    if [ ! -L "$dst_name" ]; then
        warn_print "File '$dst_name' is not a symbolic link or does not exist."
        return 0
    fi

    link_target="$(readlink "$dst_name")"
    if [ "$link_target" != "$ori_name" ]; then
        warn_print "Leaving unmanaged symlink untouched: $dst_name -> $link_target"
        return 0
    fi

    most_recent_backup="$(newest_backup_for "$dst_name")"

    if $DRY_RUN; then
        log_print "[dry-run] Would remove symbolic link: \033[36m$dst_name -> $link_target\033[0m"
        if [ -n "$most_recent_backup" ]; then
            log_print "[dry-run] Would restore newest backup: $most_recent_backup -> $dst_name"
        else
            log_print "[dry-run] No backup found for $dst_name"
        fi
        return 0
    fi

    if rm "$dst_name"; then
        log_print "Symbolic link removed: \033[36m$dst_name -> $link_target\033[0m"
    else
        error_print "Failed to remove symbolic link: $dst_name"
        return 1
    fi

    if [ -n "$most_recent_backup" ]; then
        if mv "$most_recent_backup" "$dst_name"; then
            log_print "Backup restored: $most_recent_backup -> $dst_name"
        else
            error_print "Failed to restore backup: $most_recent_backup -> $dst_name"
            return 1
        fi
    else
        log_print "No backup found for $dst_name"
    fi
}

run_yazi_install() {
    log_print ""
    log_print "\033[32m---* yazi packages \033[0m"

    if [ "${DOTFILES_SKIP_YAZI:-0}" = "1" ]; then
        warn_print "DOTFILES_SKIP_YAZI=1, skipping yazi package install."
        return 0
    fi

    if $DRY_RUN; then
        log_print "[dry-run] Would run 'ya pkg install' when ya and package.toml are available."
        return 0
    fi

    if command -v ya >/dev/null 2>&1; then
        if [ -f "$HOME/.config/yazi/package.toml" ]; then
            ya pkg install
        else
            warn_print "$HOME/.config/yazi/package.toml not found, skipping ya pkg install."
        fi
    else
        warn_print "'ya' not found in PATH, skipping yazi package install."
    fi
}

setup_logging() {
    local log_dir

    if $CHECK_MODE; then
        return 0
    fi

    log_dir="${DOTFILES_LOG_DIR:-$DOT_FILES/logs}"
    mkdir -p "$log_dir" || {
        echo "Failed to create log directory: $log_dir" >&2
        exit 1
    }

    exec > >(tee -a "$log_dir/$LOG_FILE_NAME") 2>&1
}

print_header() {
    if [ -f "$DOT_FILES/msg/msg_enjoy_your_day" ] && ! $CHECK_MODE; then
        cat "$DOT_FILES/msg/msg_enjoy_your_day"
    fi

    log_print "------------------------------"
    log_print "time: $TIME_STAMP"
    log_print "DOT_FILES: $DOT_FILES"
    if $CHECK_MODE; then
        log_print "Mode: CHECK - Validating sources and auditing destinations"
    elif $RESTORE_MODE; then
        if $DRY_RUN; then
            log_print "Mode: RESTORE DRY-RUN - Showing managed symlink removal"
        else
            log_print "Mode: RESTORE - Removing managed symbolic links"
        fi
    elif $DRY_RUN; then
        log_print "Mode: CREATE DRY-RUN - Showing symbolic link actions"
    else
        log_print "Mode: CREATE - Creating symbolic links"
    fi

    log_print "------------------------------"
    log_print "[Process Start]"
}

# ---* Process Start *---
setup_logging
print_header

if $CHECK_MODE; then
    validate_sources
    audit_destinations
else
    if ! $RESTORE_MODE; then
        validate_sources
        if [ "$error_cnt" -ne 0 ]; then
            log_print ""
            error_print "Source preflight failed; no destinations were modified."
            log_print "[Process End]"
            exit 1
        fi
    fi

    for i in "${!LINK_SOURCES[@]}"; do
        src="${LINK_SOURCES[$i]}"
        dest="${LINK_DESTS[$i]}"
        required="${LINK_REQUIRED[$i]}"

        if $RESTORE_MODE; then
            remove_soft_link "$src" "$dest"
        else
            create_soft_link "$src" "$dest" "$required"
        fi
    done

    # ---* Materialize yazi packages from yazi/package.toml *---
    # yazi/flavors/ and yazi/plugins/ are gitignored; `ya pkg install` populates them.
    if ! $RESTORE_MODE; then
        run_yazi_install
    fi
fi

log_print ""
log_print "[Process End]"

if [ "$error_cnt" -ne 0 ]; then
    exit 1
fi

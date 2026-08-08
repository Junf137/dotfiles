#!/bin/bash

# Non-destructive repository checks for this dotfiles checkout.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
failures=0

print_section() {
    printf '\n==> %s\n' "$1"
}

mark_failure() {
    failures=$((failures + 1))
}

run_required() {
    local label="$1"
    shift

    print_section "$label"
    if "$@"; then
        printf 'OK: %s\n' "$label"
    else
        printf 'FAIL: %s\n' "$label" >&2
        mark_failure
    fi
}

run_optional() {
    local command_name="$1"
    local label="$2"
    shift 2

    if ! command -v "$command_name" >/dev/null 2>&1; then
        print_section "$label"
        printf 'SKIP: %s not installed\n' "$command_name"
        return 0
    fi

    run_required "$label" "$@"
}

check_bash_syntax() {
    local status=0
    local file
    local files=(
        bootstrap.sh
        cleanup_backups.sh
        shell_common.sh
        bashrc
        lib/link_manifest.sh
        lib/shell_paths.sh
        scripts/check-dotfiles.sh
        agent-sessions/check.sh
        utils/add_path
        utils/kill_ps
        utils/file_count
        utils/rfv
        utils/cowsay_fortune
        utils/shell_welcome
        utils/color_pwd
        utils/view-image
        utils/tmux-refit-windows
        agent-sessions/bin/claude-sessions
        claude/statusline-command.sh
    )

    cd "$REPO_ROOT" || return 1
    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            printf 'Missing bash file: %s\n' "$file" >&2
            status=1
            continue
        fi
        bash -n "$file" || status=1
    done

    return "$status"
}

check_zsh_syntax() {
    local status=0
    local file
    local files=(
        zshrc
        shell_common.sh
        lib/shell_paths.sh
        omz_themes/ys_customized.zsh-theme
    )

    cd "$REPO_ROOT" || return 1
    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            printf 'Missing zsh file: %s\n' "$file" >&2
            status=1
            continue
        fi
        zsh -n "$file" || status=1
    done

    return "$status"
}

check_json() {
    local status=0
    local file
    local files=(
        claude/settings.json
        codex/hooks.json
    )

    cd "$REPO_ROOT" || return 1
    for file in "${files[@]}"; do
        jq empty "$file" || status=1
    done

    return "$status"
}

check_hook_wiring() {
    local status=0
    local file
    local event
    local target
    local files=(
        claude/settings.json
        codex/hooks.json
    )

    cd "$REPO_ROOT" || return 1
    for file in "${files[@]}"; do
        for event in SessionStart SessionEnd; do
            if [ "$(jq -r --arg e "$event" '(.hooks[$e] // []) | length' "$file")" -eq 0 ]; then
                printf 'Missing %s hook: %s\n' "$event" "$file" >&2
                status=1
            fi
        done

        # A hook whose target has been renamed or moved fails silently in both
        # agents, so resolve each command back to a real executable. statusLine
        # is resolved by the same loop: it is one key over from the hooks, fails
        # exactly as silently -- Claude just renders nothing -- and was in fact
        # the one command in this file still naming a /home/junf path that no
        # check caught. Its value carries an interpreter prefix (`bash <path>`),
        # so the first path-shaped word is taken rather than word 0, which would
        # resolve to `bash` and pass no matter what came after it.
        while read -r target; do
            [ -n "$target" ] || continue
            target="${target//\$HOME/$HOME}"
            if [ -x "$target" ]; then
                printf 'OK hook target: %s -> %s\n' "$file" "$target"
            else
                printf 'Hook target not executable: %s -> %s\n' "$file" "$target" >&2
                status=1
            fi
        done < <(jq -r '[(.hooks[]?[]?.hooks[]?.command // empty), (.statusLine.command // empty)] | .[]' "$file" |
            awk '{ for (i = 1; i <= NF; i++) { gsub(/"/, "", $i); if ($i ~ /^(\/|\$HOME\/)/) { print $i; next } } print $1 }')
    done

    return "$status"
}

check_tmux_restore_hook() {
    local status=0 value target live

    cd "$REPO_ROOT" || return 1

    # tmux-resurrect eval's its hooks and discards both the exit status and the
    # stderr (helpers.sh:143), so a hook naming a renamed script is a silent
    # no-op that nothing reports until the geometry is wrong after a reboot --
    # which is months of restores away. The save hook's equivalent check lives in
    # agent-sessions/check.sh, next to the script it names; this one is here
    # because utils/tmux-refit-windows belongs to no feature directory.
    value="$(sed -n "s/^[[:space:]]*set -g @resurrect-hook-post-restore-all[[:space:]]*'\(.*\)'[[:space:]]*$/\1/p" tmux.conf)"
    if [ -z "$value" ]; then
        printf 'Missing @resurrect-hook-post-restore-all in tmux.conf\n' >&2
        return 1
    fi

    target="${value%% *}"
    target="${target//\$HOME/$HOME}"
    if [ ! -x "$target" ]; then
        printf 'tmux restore hook target not executable: %s\n' "$target" >&2
        status=1
    elif [ "$target" != "$REPO_ROOT/utils/tmux-refit-windows" ]; then
        # A warning, not a failure: the hook value has to be a literal path, so a
        # worktree legitimately checks a tree the live server does not point at.
        printf 'WARN tmux restore hook points at another checkout: %s\n' "$target"
    else
        printf 'OK tmux restore hook target: %s\n' "$target"
    fi

    # The live value is the one that actually runs, so a conf edited but never
    # sourced is caught here rather than at the next reboot.
    if [ -n "${TMUX:-}" ]; then
        live="$(tmux show-option -gqv @resurrect-hook-post-restore-all 2>/dev/null)"
        if [ "$live" != "$value" ]; then
            printf 'live tmux restore hook differs from tmux.conf\n  live: %s\n  conf: %s\n' \
                "$live" "$value" >&2
            printf 'run: tmux source-file ~/.tmux.conf\n' >&2
            status=1
        else
            printf 'OK tmux restore hook is live on the running server\n'
        fi
    fi

    # The hook only ever runs at restore, so this is the only routine exercise it
    # gets. --dry-run reads the live server and writes nothing.
    if [ -x "$target" ] && [ -n "${TMUX:-}" ] && ! "$target" --dry-run >/dev/null 2>&1; then
        printf 'tmux restore hook fails against the running server: %s --dry-run\n' "$target" >&2
        status=1
    fi

    return "$status"
}

check_toml() {
    cd "$REPO_ROOT" || return 1
    taplo check
}

check_shfmt() {
    cd "$REPO_ROOT" || return 1
    shfmt -d \
        bootstrap.sh \
        cleanup_backups.sh \
        shell_common.sh \
        bashrc \
        lib/link_manifest.sh \
        lib/shell_paths.sh \
        scripts/check-dotfiles.sh \
        agent-sessions/check.sh \
        utils/add_path \
        utils/kill_ps \
        utils/file_count \
        utils/rfv \
        utils/cowsay_fortune \
        utils/shell_welcome \
        utils/color_pwd \
        utils/view-image \
        agent-sessions/bin/claude-sessions \
        claude/statusline-command.sh
}

check_shellcheck() {
    cd "$REPO_ROOT" || return 1
    shellcheck \
        bootstrap.sh \
        cleanup_backups.sh \
        shell_common.sh \
        bashrc \
        lib/link_manifest.sh \
        lib/shell_paths.sh \
        scripts/check-dotfiles.sh \
        agent-sessions/check.sh \
        utils/add_path \
        utils/kill_ps \
        utils/file_count \
        utils/rfv \
        utils/cowsay_fortune \
        utils/shell_welcome \
        utils/color_pwd \
        utils/view-image \
        agent-sessions/bin/claude-sessions \
        claude/statusline-command.sh
}

check_manifest_sources() {
    local status=0
    local i src required label

    cd "$REPO_ROOT" || return 1
    export DOT_FILES="$REPO_ROOT"
    export ZSH="${ZSH:-$HOME/.local/share/oh-my-zsh}"
    export ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"

    # shellcheck source=../lib/link_manifest.sh
    source "$REPO_ROOT/lib/link_manifest.sh"
    load_link_manifest || return 1

    for i in "${!LINK_SOURCES[@]}"; do
        src="${LINK_SOURCES[$i]}"
        required="${LINK_REQUIRED[$i]}"
        label="${LINK_LABELS[$i]}"
        if [ "$required" = "skip" ]; then
            printf 'SKIP source (not applicable on %s): %s (%s)\n' "$(uname -s)" "$label" "$src"
        elif [ -e "$src" ] || [ -L "$src" ]; then
            printf 'OK source: %s (%s)\n' "$label" "$src"
        elif [ "$required" = "optional" ]; then
            printf 'WARN optional source missing: %s (%s)\n' "$label" "$src"
        else
            printf 'Missing required source: %s (%s)\n' "$label" "$src" >&2
            status=1
        fi
    done

    return "$status"
}

check_welcome_corpus() {
    local file="$REPO_ROOT/msg/msg_shell_welcome"
    local nums starts ends indexes

    nums="$(sed -n '/msg nums: /s/.* //p' "$file")"
    starts="$(grep -c '^---start---$' "$file")"
    ends="$(grep -c '^---end---$' "$file")"
    indexes="$(grep -c '^msg index: ' "$file")"

    if ! [[ "$nums" =~ ^[0-9]+$ ]]; then
        printf 'Invalid msg nums metadata: %s\n' "$nums" >&2
        return 1
    fi
    if [ "$starts" -ne "$ends" ]; then
        printf 'Mismatched corpus block markers: start=%s end=%s\n' "$starts" "$ends" >&2
        return 1
    fi
    if [ "$indexes" -ne "$nums" ]; then
        printf 'Mismatched message count: metadata=%s indexed=%s\n' "$nums" "$indexes" >&2
        return 1
    fi

    awk -v nums="$nums" '
        /^msg index: / {
            idx = $3
            if (idx !~ /^[0-9]+$/ || idx < 0 || idx >= nums) {
                printf "Invalid msg index: %s\n", idx > "/dev/stderr"
                bad = 1
            }
            seen[idx]++
            current = idx
            has_range = 0
            has_width = 0
        }
        /^line range: / {
            split($3, range, ",")
            if (range[1] !~ /^[0-9]+$/ || range[2] !~ /^[0-9]+$/ || range[1] > range[2]) {
                printf "Invalid line range for msg %s: %s\n", current, $3 > "/dev/stderr"
                bad = 1
            }
            has_range = 1
        }
        /^max line width: / {
            if ($4 !~ /^[0-9]+$/) {
                printf "Invalid max line width for msg %s: %s\n", current, $4 > "/dev/stderr"
                bad = 1
            }
            has_width = 1
        }
        /^---end---$/ {
            if (current != "") {
                if (!has_range) {
                    printf "Missing line range for msg %s\n", current > "/dev/stderr"
                    bad = 1
                }
                if (!has_width) {
                    printf "Missing max line width for msg %s\n", current > "/dev/stderr"
                    bad = 1
                }
            }
            current = ""
        }
        END {
            for (i = 0; i < nums; i++) {
                if (!(i in seen)) {
                    printf "Missing msg index: %d\n", i > "/dev/stderr"
                    bad = 1
                }
            }
            exit bad
        }
    ' "$file"
}

check_agent_config_presence() {
    local status=0
    local file
    local files=(
        claude/CLAUDE.md
        claude/settings.json
        claude/statusline-command.sh
        codex/AGENTS.md
        codex/config.toml
        codex/hooks.json
    )

    cd "$REPO_ROOT" || return 1
    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            printf 'Missing agent config file: %s\n' "$file" >&2
            status=1
        else
            printf 'OK agent config file: %s\n' "$file"
        fi
    done

    return "$status"
}

run_required "bash syntax" check_bash_syntax
run_optional zsh "zsh syntax" check_zsh_syntax
run_required "agent sessions" "$REPO_ROOT/agent-sessions/check.sh"
run_optional jq "json syntax" check_json
run_optional jq "agent hook wiring" check_hook_wiring
run_required "tmux restore hook wiring" check_tmux_restore_hook
run_optional taplo "toml syntax" check_toml
run_optional shfmt "shell formatting" check_shfmt
run_optional shellcheck "shellcheck" check_shellcheck
run_required "symlink manifest sources" check_manifest_sources
run_required "welcome corpus metadata" check_welcome_corpus
run_required "agent config presence" check_agent_config_presence

printf '\n'
if [ "$failures" -eq 0 ]; then
    printf 'All required checks passed.\n'
    exit 0
fi

printf '%s required check(s) failed.\n' "$failures" >&2
exit 1

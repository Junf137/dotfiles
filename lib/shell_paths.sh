#!/usr/bin/env bash

dotfiles_resolve_script_dir() {
    local source_path="$1"
    local source_dir target

    while [ -L "$source_path" ]; do
        source_dir="$(cd -P -- "$(dirname -- "$source_path")" >/dev/null 2>&1 && pwd)" || return 1
        target="$(readlink "$source_path")" || return 1
        case "$target" in
            /*) source_path="$target" ;;
            *) source_path="$source_dir/$target" ;;
        esac
    done

    cd -P -- "$(dirname -- "$source_path")" >/dev/null 2>&1 && pwd
}

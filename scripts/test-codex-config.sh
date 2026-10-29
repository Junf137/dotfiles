#!/bin/bash
# Exercise bootstrap's system-config lifecycle without root or real home writes.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-codex-test.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT

# Check the actual manifest before using an isolated, one-entry fixture.
(
    export DOT_FILES="$REPO_ROOT"
    unset DOTFILES_CODEX_SYSTEM_CONFIG
    # shellcheck source=../lib/link_manifest.sh
    source "$REPO_ROOT/lib/link_manifest.sh"
    load_link_manifest
    found=false
    for i in "${!LINK_SOURCES[@]}"; do
        [ "${LINK_DESTS[$i]}" != "$HOME/.codex/config.toml" ]
        if [ "${LINK_SOURCES[$i]}" = "$REPO_ROOT/codex/config.toml" ]; then
            [ "${LINK_DESTS[$i]}" = /etc/codex/config.toml ]
            found=true
        fi
    done
    "$found"
)

mkdir -p "$test_dir/repo/lib" "$test_dir/repo/codex" "$test_dir/bin"
cp "$REPO_ROOT/bootstrap.sh" "$test_dir/repo/bootstrap.sh"
printf 'model = "shared-model"\n' > "$test_dir/repo/codex/config.toml"

cat > "$test_dir/repo/lib/link_manifest.sh" <<'MANIFEST'
load_link_manifest() {
    LINK_SOURCES=("$DOT_FILES/codex/config.toml")
    LINK_DESTS=("$DOTFILES_CODEX_SYSTEM_CONFIG")
    LINK_REQUIRED=(required)
    LINK_LABELS=("Codex shared defaults")
}
MANIFEST
cat > "$test_dir/bin/sudo" <<'SUDO'
#!/bin/bash
printf '%s\n' "$1" >> "$DOTFILES_TEST_SUDO_LOG"
exec "$@"
SUDO
chmod +x "$test_dir/bin/sudo"

export DOT_FILES="$test_dir/repo"
export DOTFILES_CODEX_SYSTEM_CONFIG="$test_dir/system/config.toml"
export DOTFILES_TEST_SUDO_LOG="$test_dir/sudo.log"
export DOTFILES_SKIP_YAZI=1 DOTFILES_SKIP_CLEANUP=1
export PATH="$test_dir/bin:$PATH"

run_bootstrap() {
    if ! bash "$test_dir/repo/bootstrap.sh" "$@" > "$test_dir/output.log" 2>&1; then
        cat "$test_dir/output.log" >&2
        return 1
    fi
}

run_bootstrap --dry-run
[ ! -e "$DOTFILES_CODEX_SYSTEM_CONFIG" ]
[ ! -e "$DOTFILES_TEST_SUDO_LOG" ]
run_bootstrap
[ "$(readlink "$DOTFILES_CODEX_SYSTEM_CONFIG")" = "$DOT_FILES/codex/config.toml" ]
[ "$(wc -l < "$DOTFILES_TEST_SUDO_LOG" | tr -d ' ')" = 2 ]
cp "$DOTFILES_TEST_SUDO_LOG" "$test_dir/expected-sudo.log"
run_bootstrap
run_bootstrap --check
cmp "$DOTFILES_TEST_SUDO_LOG" "$test_dir/expected-sudo.log"
[ "$(find "$test_dir/system" -name '*.bak' | wc -l | tr -d ' ')" = 0 ]

printf 'model = "updated-shared-model"\n' > "$DOT_FILES/codex/config.toml"
cmp "$DOTFILES_CODEX_SYSTEM_CONFIG" "$DOT_FILES/codex/config.toml"
run_bootstrap --restore --dry-run
[ -L "$DOTFILES_CODEX_SYSTEM_CONFIG" ]
cmp "$DOTFILES_TEST_SUDO_LOG" "$test_dir/expected-sudo.log"
run_bootstrap --restore
[ ! -L "$DOTFILES_CODEX_SYSTEM_CONFIG" ]

# A pre-existing system file is backed up once and restored intact.
printf 'model = "previous-system-model"\n' > "$DOTFILES_CODEX_SYSTEM_CONFIG"
cp "$DOTFILES_CODEX_SYSTEM_CONFIG" "$test_dir/previous-system.toml"
run_bootstrap
[ "$(find "$test_dir/system" -name '*.bak' | wc -l | tr -d ' ')" = 1 ]
run_bootstrap
[ "$(find "$test_dir/system" -name '*.bak' | wc -l | tr -d ' ')" = 1 ]
run_bootstrap --restore
cmp "$DOTFILES_CODEX_SYSTEM_CONFIG" "$test_dir/previous-system.toml"
[ "$(find "$test_dir/system" -name '*.bak' | wc -l | tr -d ' ')" = 0 ]
printf 'Codex bootstrap lifecycle passed; temporary files removed on exit.\n'

#!/bin/bash

# __author__ == Junfeng Lei

# Checks for the agent-session tooling. Run standalone, or by
# scripts/check-dotfiles.sh as a single dispatch.
#
# Every failure this catches is one that is otherwise completely silent at
# runtime: tmux-resurrect discards its hook's exit status and its stderr, Codex
# ignores a missing hooks file without a word, and the resume-marker patterns
# match another program's terminal output and rot when it changes wording.
#
# It derives its own root rather than inheriting one, so it keeps working if this
# directory is ever extracted to a repo of its own.

SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SELF_DIR/.." && pwd -P)"
failures=0

print_section() {
    printf '\n==> %s\n' "$1"
}

run_required() {
    local label="$1"
    shift

    print_section "$label"
    if "$@"; then
        printf 'OK: %s\n' "$label"
    else
        printf 'FAIL: %s\n' "$label" >&2
        failures=$((failures + 1))
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

check_python_syntax() {
    cd "$REPO_ROOT" || return 1

    # ast.parse rather than py_compile: no __pycache__ left in the repo.
    #
    # Plus a name-binding pass, because syntax is not what breaks these files.
    # A save whose hook raises NameError is a completely silent no-op --
    # tmux-resurrect discards the exit status and the stderr, and the failure
    # happens before there is anywhere to log -- and that is exactly what a
    # dropped `import` produces. It happened here once: a partially edited
    # working tree ran `2026-08-02 03:31:44 failed: NameError: name 'hashlib'
    # is not defined` against the live server. Nothing but the tests would have
    # caught it, and only because one of 1900 lines happens to call the one
    # function that uses hashlib; five of the imports are exercised by nothing.
    python3 - \
        agent-sessions/bin/agent-panes \
        agent-sessions/bin/agent-pane-register \
        agent-sessions/bin/agent-panes-resurrect \
        agent-sessions/bin/agent-resume \
        agent-sessions/bin/agent-scrollback-ids \
        agent-sessions/lib/agent_ids.py \
        agent-sessions/lib/claude_names.py \
        agent-sessions/tests/test-agent-tools.py <<'PY'
import ast
import builtins
import sys

# Deliberately flat and scope-insensitive: a name bound anywhere in the file
# counts as bound everywhere in it. That gives up on shadowing and
# use-before-assignment in exchange for never crying wolf, and it still catches
# the one thing that matters -- a name the file uses and never binds at all.
BOUND_BY = (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)
# MatchAs/MatchStar arrived in 3.10, and the floor here is 3.9 (README:
# Requirements). On 3.9 the tuple is empty, which costs nothing: a file
# containing a match statement would already have failed ast.parse above.
MATCH_BINDERS = tuple(getattr(ast, name) for name in ("MatchAs", "MatchStar") if hasattr(ast, name))
ALLOWED = set(dir(builtins)) | {
    "__file__", "__name__", "__doc__", "__spec__",
    "__package__", "__loader__", "__builtins__",
}

status = 0
for path in sys.argv[1:]:
    try:
        with open(path) as handle:
            tree = ast.parse(handle.read(), filename=path)
    except (OSError, SyntaxError) as err:
        print(f"{path}: {err}", file=sys.stderr)
        status = 1
        continue

    bound = set(ALLOWED)
    for node in ast.walk(tree):
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            for alias in node.names:
                bound.add((alias.asname or alias.name).split(".")[0])
        elif isinstance(node, BOUND_BY):
            bound.add(node.name)
        elif isinstance(node, ast.Name) and isinstance(node.ctx, (ast.Store, ast.Del)):
            bound.add(node.id)
        elif isinstance(node, ast.arg):
            bound.add(node.arg)
        elif isinstance(node, ast.ExceptHandler) and node.name:
            bound.add(node.name)
        elif isinstance(node, (ast.Global, ast.Nonlocal)):
            bound.update(node.names)
        elif isinstance(node, MATCH_BINDERS) and node.name:
            bound.add(node.name)

    for node in ast.walk(tree):
        if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Load) and node.id not in bound:
            print(f"{path}:{node.lineno}: undefined name '{node.id}'", file=sys.stderr)
            status = 1
sys.exit(status)
PY
}

check_executable_bits() {
    local status=0
    local file
    local files=(
        agent-sessions/bin/agent-panes
        agent-sessions/bin/agent-pane-register
        agent-sessions/bin/agent-panes-resurrect
        agent-sessions/bin/agent-resume
        agent-sessions/bin/agent-scrollback-ids
        agent-sessions/bin/claude-sessions
        agent-sessions/tests/test-agent-tools.py
        agent-sessions/check.sh
    )

    cd "$REPO_ROOT" || return 1
    for file in "${files[@]}"; do
        if [ ! -x "$file" ]; then
            printf 'Not executable: %s\n' "$file" >&2
            status=1
        else
            printf 'OK executable: %s\n' "$file"
        fi
    done

    return "$status"
}

check_shared_module() {
    # The resume-marker patterns live in lib/agent_ids.py so there is one copy
    # for the tests to cover. agent-panes-resurrect imports it behind a guard --
    # it runs as a save hook, and an ImportError raised before silence() has
    # anywhere to write would kill the hook without a single logged word. That
    # guard is correct and it is also why this check has to exist: with it in
    # place, a missing or broken module degrades to "no harvest", silently.
    cd "$REPO_ROOT" || return 1

    python3 - agent-sessions/bin/agent-panes-resurrect agent-sessions/bin/agent-scrollback-ids <<'PY'
import os
import sys

status = 0

# Deliberately NOT imported here first. The tools resolve lib/ from their own
# __file__ and agent-panes-resurrect swallows an ImportError on purpose, so a
# pre-import would land agent_ids in sys.modules and make that guard succeed
# every time -- this check would then pass on a tree where the module is missing,
# which is the single thing it exists to catch.
for path in sys.argv[1:]:
    with open(path) as handle:
        source = handle.read().split("if __name__ ==")[0]
    namespace = {"__file__": os.path.abspath(path)}
    try:
        exec(compile(source, path, "exec"), namespace)
    except Exception as err:
        print(f"{path}: module body raised {type(err).__name__}: {err}", file=sys.stderr)
        status = 1
        continue
    # The guard turns a broken import into a silent loss of the whole harvest,
    # so the only place it can be noticed is here.
    if namespace.get("IMPORT_ERROR"):
        print(f"{path}: falling back, harvest disabled: {namespace['IMPORT_ERROR']}", file=sys.stderr)
        status = 1
    elif not callable(namespace.get("extract")):
        print(f"{path}: extract() not re-exported", file=sys.stderr)
        status = 1
    elif not namespace["extract"]("run codex resume 019f85e8-b749-7101-9771-beee8b588342"):
        # Not just importable: actually matching. The fallback extract() returns
        # [] for everything, and so would a module whose patterns had rotted.
        print(f"{path}: extract() matches nothing", file=sys.stderr)
        status = 1
    elif not callable(namespace.get("name_index")):
        # The title index is shared the same way and for the same reason: it
        # reads Claude's own on-disk records, so there is one copy and the tests
        # cover it. Behind the same guard, so it fails the same way -- silently.
        print(f"{path}: name_index() not re-exported", file=sys.stderr)
        status = 1
    else:
        print(f"OK {path} shares the resume-marker patterns and the title index")

sys.exit(status)
PY
}

check_borrowed_names() {
    # agent-resume borrows the block parsing from agent-panes-resurrect and the
    # ancestor walk from agent-pane-register rather than keeping a second copy --
    # marker_line() and parse_stanzas() carry the rules deciding which stanzas a
    # pane may claim, and a copy would drift exactly where drift is silent.
    #
    # The cost is that every borrowed name is an attribute lookup resolved at
    # call time. Renaming one inside the lender leaves agent-resume importing
    # cleanly, passing the name-binding pass, and then raising AttributeError on
    # the one path that starts a session. This resolves each of them for real.
    #
    # procinfo is in the list for the same reason even though it is imported
    # rather than borrowed: agent-resume is the one tool no check can run, so an
    # attribute lookup is all there is to resolve. The walk is one level deep, so
    # a name must be reached as `MODULE.name` -- writing it as
    # `REGISTER.procinfo.name` would put it back out of sight.
    cd "$REPO_ROOT" || return 1

    python3 - agent-sessions/bin/agent-resume <<'PY'
import ast
import os
import sys

path = sys.argv[1]
with open(path) as handle:
    source = handle.read()

namespace = {"__file__": os.path.abspath(path)}
try:
    exec(compile(source.split("if __name__ ==")[0], path, "exec"), namespace)  # noqa: S102
except Exception as err:
    print(f"{path}: module body raised {type(err).__name__}: {err}", file=sys.stderr)
    sys.exit(1)

status = 0
wanted = {}
for node in ast.walk(ast.parse(source, filename=path)):
    if isinstance(node, ast.Attribute) and isinstance(node.value, ast.Name):
        if node.value.id in ("RESURRECT", "REGISTER", "procinfo"):
            wanted.setdefault((node.value.id, node.attr), node.lineno)

for (module, attr), lineno in sorted(wanted.items(), key=lambda item: item[1]):
    if not hasattr(namespace[module], attr):
        print(f"{path}:{lineno}: {module} has no {attr!r}", file=sys.stderr)
        status = 1

if not status:
    print(f"OK {len(wanted)} borrowed name(s) resolve")
sys.exit(status)
PY
}

check_tmux_hook_wiring() {
    local value target mode

    cd "$REPO_ROOT" || return 1

    # tmux-resurrect discards its hook's exit status and its stderr, so a hook
    # pointing at a renamed script is a silent no-op with no runtime feedback at
    # all -- exactly the failure this check exists to make loud.
    value="$(sed -n "s/^[[:space:]]*set -g @resurrect-hook-post-save-all[[:space:]]*'\(.*\)'[[:space:]]*$/\1/p" tmux.conf)"
    if [ -z "$value" ]; then
        printf 'Missing @resurrect-hook-post-save-all in tmux.conf\n' >&2
        return 1
    fi

    target="${value%% *}"
    target="${target//\$HOME/$HOME}"
    if [ ! -x "$target" ]; then
        printf 'tmux hook target not executable: %s\n' "$target" >&2
        return 1
    fi

    # Compared against this checkout, but only as a warning. The hook value has
    # to be a literal path -- tmux cannot derive one -- so a worktree, or a clone
    # anywhere other than the hardcoded location, legitimately runs checks
    # against a tree the live server does not point at. Failing there would make
    # `./scripts/check-dotfiles.sh` unusable from every worktree this repo's own
    # tooling creates. The executable test above is the one that must be hard:
    # it is what catches a rename or a fresh clone at a new path.
    if [ "$target" != "$REPO_ROOT/agent-sessions/bin/agent-panes-resurrect" ]; then
        printf 'WARN tmux hook points at another checkout: %s\n' "$target"
        printf '     this tree is %s; the live server runs the path above\n' "$REPO_ROOT"
    else
        printf 'OK tmux hook target: %s\n' "$target"
    fi

    # Compared exactly, not by substring: the script rejects any mode word it
    # does not know, and a near-miss like "saved" would otherwise pass here and
    # then do nothing at runtime, silently.
    read -r _ mode _ <<<"$value"
    if [ "$mode" != "save" ]; then
        printf 'tmux hook mode should be "save", got "%s": %s\n' "$mode" "$value" >&2
        return 1
    fi
    printf 'OK tmux hook mode: save\n'

    # The option is a single-valued slot in another project's namespace: last
    # writer wins, and nothing warns. Inside tmux the live value is the one that
    # actually runs, so a conf edited but never sourced -- or a plugin that set
    # the same option after us -- is caught here rather than at the next reboot.
    if [ -n "${TMUX:-}" ]; then
        local live
        live="$(tmux show-option -gqv @resurrect-hook-post-save-all 2>/dev/null)"
        if [ "$live" != "$value" ]; then
            printf 'live tmux hook differs from tmux.conf\n  live: %s\n  conf: %s\n' \
                "$live" "$value" >&2
            printf 'run: tmux source-file ~/.tmux.conf\n' >&2
            return 1
        fi
        printf 'OK tmux hook is live on the running server\n'
    fi
}

check_resurrect_plugin_contract() {
    # Everything this feature leans on inside tmux-resurrect is undocumented and
    # was verified against cff343cf. TPM updates the plugin with an unreviewed
    # `git pull` on `prefix + U`, and the plugin discards both its hook's exit
    # status and its stderr -- so if any of these move, the feature becomes a
    # completely silent no-op. This is the only thing that would say otherwise.
    #
    # tmux.conf sets TMUX_PLUGIN_MANAGER_PATH with a literal `~`, which tmux
    # exports unexpanded; without this the path never resolves and the whole
    # check quietly SKIPs -- the same silent no-op it exists to catch.
    local plugin="${TMUX_PLUGIN_MANAGER_PATH:-$HOME/.tmux/plugins}"
    plugin="${plugin/#\~/$HOME}"
    plugin="${plugin%/}/tmux-resurrect"
    local status=0

    # Not a silent pass: outside tmux, TMUX_PLUGIN_MANAGER_PATH is not exported
    # at all, so this would resolve to the default and -- if that were also
    # absent -- report OK while asserting nothing whatsoever.
    if [ ! -d "$plugin" ]; then
        printf 'SKIP tmux-resurrect not installed at %s (nothing asserted)\n' "$plugin"
        return 0
    fi

    # hook_prefix + the name we hang off, together forming @resurrect-hook-post-save-all.
    grep -q 'hook_prefix="@resurrect-hook-"' "$plugin/scripts/variables.sh" ||
        { printf 'tmux-resurrect: hook_prefix changed (scripts/variables.sh)\n' >&2; status=1; }
    grep -q 'execute_hook "post-save-all"' "$plugin/scripts/save.sh" ||
        { printf 'tmux-resurrect: post-save-all hook no longer fired (scripts/save.sh)\n' >&2; status=1; }

    # The archive we rewrite, and the `./pane_contents/` member directory we
    # rebuild it around -- both from the plugin's own tar invocation.
    grep -q 'pane_contents.tar.gz' "$plugin/scripts/helpers.sh" ||
        { printf 'tmux-resurrect: archive name changed (scripts/helpers.sh)\n' >&2; status=1; }
    grep -q 'tar cf - -C .* \./pane_contents/' "$plugin/scripts/helpers.sh" ||
        { printf 'tmux-resurrect: pane_contents member layout changed (scripts/helpers.sh)\n' >&2; status=1; }

    # The content-file naming we key blocks by, and the restore command whose
    # `cat` is what prints the block at all.
    grep -q 'pane-\${pane_id}' "$plugin/scripts/helpers.sh" ||
        { printf 'tmux-resurrect: pane content file naming changed (scripts/helpers.sh)\n' >&2; status=1; }
    grep -q "cat '.*'; exec" "$plugin/scripts/restore.sh" ||
        { printf 'tmux-resurrect: restore no longer replays contents via cat (scripts/restore.sh)\n' >&2; status=1; }

    [ "$status" -eq 0 ] && printf 'OK tmux-resurrect internals unchanged (6 checked)\n'
    return "$status"
}

check_tool_tests() {
    cd "$REPO_ROOT" || return 1
    ./agent-sessions/tests/test-agent-tools.py
}

check_tool_smoke() {
    # Everything above this line inspects the tools without starting them:
    # ast.parse, a name-binding pass, an -x test. None of that notices a tool
    # that dies at import -- which is exactly how the /proc reads went
    # unnoticed on macOS while the checks reported OK. So actually run the one
    # that reads processes, and parse what it prints.
    #
    # agent-panes is the right probe: every process fact the family depends on
    # is exercised by producing its table, and every other Python tool that
    # reads processes imports the same module, so one run covers the import for
    # all of them. (claude-sessions is bash and agent-scrollback-ids does not
    # read processes, so neither is covered here.) agent-resume must never be
    # smoke-tested this way -- with a single candidate it clears the pane and
    # execs the agent.
    local out
    cd "$REPO_ROOT" || return 1

    if ! out="$(./agent-sessions/bin/agent-panes --json 2>&1)"; then
        # No tmux server is a legitimate exit 1, not a broken tool.
        if printf '%s' "$out" | grep -q 'No tmux panes found'; then
            printf 'SKIP: no tmux server running\n'
            return 0
        fi
        printf '%s\n' "$out" >&2
        return 1
    fi

    local rows
    rows="$(printf '%s' "$out" |
        python3 -c 'import json, sys; rows = json.load(sys.stdin); print(len(rows) if isinstance(rows, list) else "")')"
    if [ -z "$rows" ]; then
        printf 'agent-panes --json did not produce a JSON list\n' >&2
        return 1
    fi
    printf 'OK agent-panes runs and emits JSON (%s row(s))\n' "$rows"
}

run_optional python3 "agent-sessions python syntax" check_python_syntax
run_optional python3 "agent-sessions shared patterns" check_shared_module
run_optional python3 "agent-resume borrowed names" check_borrowed_names
run_required "agent-sessions executable bits" check_executable_bits
run_required "tmux resurrect hook wiring" check_tmux_hook_wiring
run_required "tmux resurrect plugin contract" check_resurrect_plugin_contract
run_optional python3 "agent resume-marker patterns" check_tool_tests
run_optional python3 "agent-sessions tools run" check_tool_smoke

if [ "$failures" -gt 0 ]; then
    printf '\n%d agent-sessions check(s) failed.\n' "$failures" >&2
    exit 1
fi

printf '\nAll agent-sessions checks passed.\n'

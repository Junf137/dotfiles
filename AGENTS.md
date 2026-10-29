# Dotfiles repository guide

Junfeng Lei's public dotfiles for Arch Linux and macOS, symlinked into place by
`bootstrap.sh`. This is the guide for every coding agent: `CLAUDE.md` only imports it,
and `README.md` covers setup for humans.

The live checkout is `~/Documents/dotfiles`, on each machine's `local` branch, and
`zshrc`/`bashrc` export it as `$DOT_FILES`. Every link points into it, every hook runs
from it and the hook paths hard-code its location, so a change made in a worktree takes
effect only once it reaches `local` in the live checkout.

## Layout

- `agent-sessions/`: Claude/Codex session-to-tmux-pane tooling; `bin/` is on `PATH`
- `agent-skills/`: submodule; `claude/` links to `~/.claude/skills`, `codex/` to
  `~/.agents/skills`
- `alacritty/`, `tmux/`, `tmuxp/`, `omz_themes/`: Alacritty config, tmux window-name
  overrides, tmuxp layout, Oh My Zsh theme
- `claude/`: global Claude Code files, each linked into `~/.claude/`; `settings.json`
  also wires the agent-sessions hooks and the status line
- `codex/`: global Codex files; `AGENTS.md` and `hooks.json` link into `~/.codex/`,
  `config.toml` to `/etc/codex/config.toml`
- `lib/link_manifest.sh`: every managed link, for `bootstrap.sh` and `cleanup_backups.sh`
- `msg/`: bootstrap banner and shell welcome messages
- `nvim/`: kickstart.nvim submodule (`nvim-kickstart/`) and `markdownlint.jsonc`
- `scripts/`: `check-dotfiles.sh` (all repo checks) and `test-codex-config.sh`
- `tmpfiles/` (Linux), `launchd/` (macOS): prune `~/hf` handoffs; see `tmpfiles/README.md`
- `utils/`: helpers on `PATH`; `tmux-refit-windows` is the resurrect restore hook, and
  yazi calls `clip` and `view-image`
- `wezterm/`: wezterm-config submodule
- `yazi/`: Yazi config; bootstrap runs `ya pkg install` for its gitignored plugins and
  flavors
- `bashrc`, `zshrc`, `shell_common.sh`: both rc files source `shell_common.sh` (PATH,
  fzf, aliases)
- `vimrc`, `tmux.conf`, `gitconfig`, `condarc`: linked into `$HOME` with a leading dot
- `bootstrap.sh`, `cleanup_backups.sh`: create or restore links; prune redundant backups
- `Brewfile`, `macos-defaults.sh`: macOS packages and preferences, applied by hand
- `AGENTS.md`, `CLAUDE.md`, `README.md`: this guide, its import for Claude Code, the
  human README

## Rules

- **Git.** Shared changes are `type(scope): summary` commits for `main`, prepared in a
  separate worktree based on the latest `origin/main`. Never switch the live checkout's
  branch: that changes the running setup. `local` holds a machine's
  `local(scope): summary` commits directly on top of `main`; never push it, merge it
  into `main`, or merge `main` into it. Never rewrite published history, and preserve
  uncommitted work first: a parent-repo `git stash` does not cover submodules. Full
  rules, including promoting a `local` commit and rebasing `local` after a merge:
  *Branch and commit conventions* in `README.md`.
- **Both OSes.** Every change must work on Arch Linux and on macOS. Gate platform code on
  `uname -s`, and a one-platform link with `_link_manifest_tier_for`. macOS has bash 3.2
  at `/bin/bash`, BSD `sed`, `find` and `mktemp`, and python3 3.9 in non-interactive
  shells.
- **Links.** `lib/link_manifest.sh` is the only list of links. `codex/config.toml` links
  to `/etc/codex/config.toml`, the one link bootstrap makes with `sudo`.
  `~/.codex/config.toml` is Codex's private machine state (project trust, hook
  approvals): never link it into the repo.
- **Submodules.** Change `agent-skills/`, `nvim/nvim-kickstart/` and
  `wezterm/wezterm-config/` in their own repositories, then commit the new pointer here.
- **agent-sessions.** Read `agent-sessions/README.md` in full before touching
  `agent-sessions/` or its wiring. It records constraints that must not be re-derived.
- **Hook paths.** The hook commands in `tmux.conf`, `claude/settings.json` and
  `codex/hooks.json` are absolute paths: move or rename a target and every entry naming
  it in one commit. Any edit to `codex/hooks.json` revokes Codex's hook trust until it
  is approved again in the Codex TUI on each machine.
- **tmux.** Read the `tmux.conf` comments before touching `@continuum-boot` (set per
  platform on purpose) or the resurrect hooks (they must stay silent).
  `utils/tmux-refit-windows` never resizes a window; its header explains why.
- **Python.** An exception to the global conda rule: the repo's Python, all under
  `agent-sessions/`, is stdlib-only and runs on the plain `python3` on `PATH`. Keep it
  compatible with 3.9 (macOS's `/usr/bin/python3`), and run its checks directly, not
  through `conda run`, so they test the interpreter the hooks use.
- **Shell scripts.** Match the existing ones: `#!/bin/bash`, `# __author__ == Junfeng Lei`,
  `# ---* Section *---` separators, red `[Error]` and yellow `[Warn]` as in
  `bootstrap.sh`. Anything destructive defaults to a dry run, with `-f`/`--force` to act.

## Verify

- `./scripts/check-dotfiles.sh` checks the tree it belongs to, so it works from a
  worktree. Run it after every change and after upgrading Claude Code or Codex. In a
  worktree it warns that the live hooks point at another checkout, which is expected; a
  fresh worktree needs `git submodule update --init --recursive` first.
- `bootstrap.sh` and `cleanup_backups.sh` act on `$DOT_FILES`, the live checkout, even
  when run from a worktree. Run `./bootstrap.sh --check` and `--dry-run` in the live
  checkout once a change has reached it. Never point `DOT_FILES` at a worktree: that
  relinks `$HOME` into it.

## Adding a dotfile

1. Add the file at the repo root or in a fitting subdirectory.
2. Add one `_link_manifest_add` line for it to `lib/link_manifest.sh`.
3. Run `./scripts/check-dotfiles.sh`.
4. Once it is merged and in the live checkout, run `./bootstrap.sh --check`, then
   `./bootstrap.sh --dry-run`, then `./bootstrap.sh` there.

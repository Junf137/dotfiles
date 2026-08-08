# Dotfiles Repository - CLAUDE.md

This document describes the structure, conventions, and workflows of this dotfiles repository for AI assistants working within it.

## Repository Overview

Personal dotfiles for **Junfeng Lei** (`junf137@outlook.com`). Manages shell, editor, terminal emulator, tmux, and tool configurations via symlink-based installation.

- **Owner**: Junfeng Lei (GitHub: Junf137)
- **Default dotfiles location**: `$HOME/Documents/dotfiles` (referenced as `$DOT_FILES`)
- **Installation method**: `bootstrap.sh` creates symlinks from repo files to their target locations

## Repository Structure

```
dotfiles/
├── agent-sessions/         # Claude/Codex session <-> tmux pane tooling (see its README.md)
│   ├── bin/                # agent-panes, agent-pane-register, agent-panes-resurrect, agent-resume, ...
│   ├── lib/                # agent_ids.py (resume-marker patterns), claude_names.py (title -> uuid),
│   │                       #   procinfo.py (process facts: /proc on Linux, libproc+sysctl on macOS)
│   └── tests/              # test-agent-tools.py
├── alacritty/              # Alacritty terminal emulator configs
│   └── alacritty-default/  # Symlinked to ~/.config/alacritty
├── agent-skills/           # Git submodule: Junf137/agent-skills
│   ├── claude/             # Symlinked to ~/.claude/skills
│   └── codex/              # Symlinked to ~/.agents/skills
├── claude/                 # Global Claude Code configuration (symlinked to ~/.claude/)
│   ├── CLAUDE.md           # Global Claude policies (symlinked to ~/.claude/CLAUDE.md)
│   ├── settings.json       # Permissions config (symlinked to ~/.claude/settings.json)
│   └── statusline-command.sh  # Custom statusLine script (symlinked to ~/.claude/statusline-command.sh)
├── codex/                  # Global OpenAI Codex configuration (symlinked to ~/.codex/)
│   ├── AGENTS.md           # Global Codex agent instructions (symlinked to ~/.codex/AGENTS.md)
│   ├── config.toml         # Codex config (symlinked to ~/.codex/config.toml)
│   └── hooks.json          # Codex session hooks (symlinked to ~/.codex/hooks.json)
├── msg/                    # ASCII art welcome messages
│   ├── msg_enjoy_your_day  # Bootstrap banner
│   └── msg_shell_welcome   # Shell startup messages
├── nvim/
│   └── nvim-kickstart/     # Git submodule: Junf137/kickstart.nvim
├── omz_themes/
│   └── ys_customized.zsh-theme  # Custom Oh My ZSH theme
├── launchd/                # macOS LaunchAgents (handoff pruning; the tmpfiles counterpart)
├── tmpfiles/               # systemd-tmpfiles rules (Linux)
│   ├── handoffs.conf       # Prunes ~/hf handoff docs after 10 days (symlinked to ~/.config/user-tmpfiles.d/)
│   └── README.md           # Trigger chain, age semantics, on/off, and removal steps
├── tmux/
│   └── tmux-nerd-font-window-name.yml  # Overrides for joshmedeski/tmux-nerd-font-window-name (symlinked to ~/.config/tmux/)
├── tmuxp/
│   └── regular.yaml        # tmuxp session layout
├── utils/                  # Custom shell utility scripts
│   ├── add_path            # PATH management function
│   ├── clip                # SSH/tmux-aware clipboard copy (OSC 52 fallback)
│   ├── color_pwd           # Colored PWD display
│   ├── cowsay_fortune      # Random ASCII art + fortune
│   ├── file_count          # Count files per subdirectory
│   ├── kill_ps             # FZF-based interactive process killer
│   ├── rfv                 # Ripgrep + FZF + Vim search integration
│   └── shell_welcome       # Random welcome message display
├── wezterm/
│   └── wezterm-config/     # Git submodule: Junf137/wezterm-config
├── yazi/                   # Yazi file manager configs
│   └── keymap.toml         # Yazi keybindings
├── bashrc                  # Bash configuration
├── bootstrap.sh            # Main installer (creates/restores symlinks)
├── CLAUDE.md               # This file (repo-specific AI assistant guide)
├── cleanup_backups.sh      # Remove redundant .bak symlinks
├── condarc                 # Conda config (auto_activate_base: false)
├── gitconfig               # Git user/editor/color config
├── README.md               # User-facing documentation
├── shell_common.sh         # Shared shell config (sourced by both bashrc and zshrc)
├── tmux.conf               # Tmux configuration (Catppuccin theme)
├── vimrc                   # Vim configuration with plugins
└── zshrc                   # ZSH configuration (primary shell)
```

## Symlink Mappings

`bootstrap.sh` creates these symlinks (source -> destination):

| Source (in repo)                        | Destination                          |
|-----------------------------------------|--------------------------------------|
| `bashrc`                                | `~/.bashrc`                          |
| `zshrc`                                 | `~/.zshrc`                           |
| `vimrc`                                 | `~/.vimrc`                           |
| `condarc`                               | `~/.condarc`                         |
| `tmux.conf`                             | `~/.tmux.conf`                       |
| `gitconfig`                             | `~/.gitconfig`                       |
| `tmuxp/`                                | `~/.tmuxp`                           |
| `tmux/tmux-nerd-font-window-name.yml`   | `~/.config/tmux/tmux-nerd-font-window-name.yml` |
| `omz_themes/ys_customized.zsh-theme`    | `$ZSH_CUSTOM/themes/...`            |
| `nvim/nvim-kickstart`                   | `~/.config/nvim`                     |
| `wezterm/wezterm-config`                | `~/.config/wezterm`                  |
| `alacritty/alacritty-default`           | `~/.config/alacritty`                |
| `yazi/`                                 | `~/.config/yazi`                     |
| `agent-skills/claude`                   | `~/.claude/skills`                   |
| `agent-skills/codex`                    | `~/.agents/skills`                   |
| `claude/CLAUDE.md`                      | `~/.claude/CLAUDE.md`               |
| `claude/settings.json`                  | `~/.claude/settings.json`           |
| `claude/statusline-command.sh`          | `~/.claude/statusline-command.sh`   |
| `codex/AGENTS.md`                       | `~/.codex/AGENTS.md`                |
| `codex/config.toml`                     | `~/.codex/config.toml`              |
| `codex/hooks.json`                      | `~/.codex/hooks.json`               |
| `tmpfiles/handoffs.conf`                | `~/.config/user-tmpfiles.d/handoffs.conf` (Linux only) |
| `launchd/com.junf.prune-handoffs.plist` | `~/Library/LaunchAgents/com.junf.prune-handoffs.plist` (macOS only) |
| `~/Pictures/Background`                 | `~/.config/wezterm/backdrops`        |

## Git Submodules

Three configs are managed as separate repos:
- `agent-skills` -> `git@github.com:Junf137/agent-skills.git`
- `nvim/nvim-kickstart` -> `git@github.com:Junf137/kickstart.nvim.git`
- `wezterm/wezterm-config` -> `git@github.com:Junf137/wezterm-config.git`

After cloning, initialize with: `git submodule update --init --recursive`

## Key Tools & Their Configurations

### Shell (ZSH primary, Bash fallback)
- **Framework**: Oh My ZSH with custom `ys_customized` theme
- **Plugins**: z, fzf, git, sudo, zsh-bat, you-should-use, zsh-autosuggestions, zsh-syntax-highlighting
- **Shared config**: `shell_common.sh` is sourced by both `bashrc` and `zshrc` for aliases, FZF settings, PATH, and welcome messages

### Terminal Emulators
- **Alacritty**: FiraCode Nerd Font Mono, Catppuccin Macchiato theme, borderless window
- **WezTerm**: Separate config submodule with backdrop images

### Editors
- **Vim**: NERDTree, vim-airline, vim-startify, vim-tmux-navigator
- **Neovim**: kickstart.nvim submodule (separate config)

### Tmux
- **Prefix**: `Alt+A` (not default Ctrl+B)
- **Theme**: Catppuccin Mocha (`@catppuccin_flavor`)
- **Key features**: Vi mode, mouse support, 100K history, TPM plugin manager
- **Session management**: tmuxp with layout in `tmuxp/regular.yaml`
- **Save/restore**: tmux-resurrect (`@resurrect-capture-pane-contents on`) plus
  tmux-continuum (`@continuum-restore on`, autosave every 15 min). The
  `@resurrect-hook-post-save-all` hook runs `agent-sessions/bin/agent-panes-resurrect` —
  see `agent-sessions/README.md`
- **Boot start**: `@continuum-boot` is set per-platform through `if-shell`, and must
  stay that way. It is one option over two unrelated mechanisms, and continuum tests
  `is_osx` *before* `is_systemd`, so the systemd branch is unreachable on a Mac. `'on'`
  there does not enable a unit — it writes `~/Library/LaunchAgents/Tmux.Start.plist`,
  which AppleScripts Terminal.app open at every login and full-screens it. So it is
  `'on'` on Linux (where it enables the hand-written `tmux.service`) and `'off'` on
  macOS, where `'off'` additionally deletes that plist if one was ever written
- **Restore geometry**: `@resurrect-hook-post-restore-all` runs
  `utils/tmux-refit-windows`. Resurrect replays each window's saved `window_layout`
  with `select-layout`, which sizes the layout's cells *without* resizing the window,
  so a layout saved under a big client and restored under a smaller one leaves panes
  larger than the window and the shell prompt below the visible bottom. tmux re-lays a
  window out only when its size changes, so nothing heals it afterwards. The script
  refits those windows and **never resizes one** — `resize-window -A`/`-a`/`-x`/`-y`
  all pin `window-size manual` and nothing unpins it, so the window stops following
  the client for good; on a detached session `-A` additionally resolves to
  `default-size` 80x24. History survives that (tmux 3.7b reflows on resize rather
  than truncating — measured), but the pane stays 80 columns until someone notices

### Agent Session Mapping & Resurrect Carry-over
Maps running Claude/Codex sessions to their tmux pane, records **every** session a pane
has held — live, exited, or only remembered by that pane's scrollback — and carries them
across a reboot so the restored pane prints what ran there and how to resume it.
`agent-resume` is the consuming end: run in any pane, it clears the screen and resumes
that pane's session *only* where exactly one maps to it, and offers no way to name one.

**Before touching anything under `agent-sessions/`, read `agent-sessions/README.md` in
full.** It records constraints that must not be re-derived: save ordering, why the hook
must be silent, the `$TMUX` guard, why stripping is load-bearing, the `#`-prefixed
column-0 sentinel, placement by `%N` rather than by location, field sanitisation, the
Codex hook gotchas, and — since the save hook now reads its own block back as input —
harvest-before-strip, the one predicate that decides what is ours, the `bound to
%N@server` stanza binding, why a per-pane cap must rank rather than slice, why the
dry-run preview is printed at column 0 rather than indented, why a moved pane
list refuses the harvest outright, and — for `agent-resume` — why it borrows the block
parsing rather than copying it, why its clear stops at `ESC[2J`, and why nothing
selects a candidate. All of it was established empirically against
tmux-resurrect `cff343cf`, codex-cli 0.146 and Claude Code 2.1.220.

Wiring lives outside that directory in three places — `tmux.conf`
(`@resurrect-hook-post-save-all`), `claude/settings.json` and `codex/hooks.json` — and
all three are absolute paths that must change atomically with the scripts they name.

### FZF Integration
- **Trigger**: `~~` (not default `**`)
- **Default command**: `fd --unrestricted`
- **Preview**: `bat` for files, `tree` for directories
- **Keybindings**: Ctrl-T (files), Ctrl-R (history), Alt-C (directories)

### Design Theme
- **Catppuccin** color scheme throughout, but the flavour is per-tool: Alacritty is
  Macchiato (`alacritty/alacritty-default/alacritty.toml`), Tmux is Mocha
  (`@catppuccin_flavor` in `tmux.conf`), and WezTerm uses a lightly altered Mocha
  (`wezterm/wezterm-config/colors/custom.lua`)
- This is why anything written into a pane for later replay — see
  `agent-sessions/README.md` — sticks to ANSI-16 rather than a hardcoded flavour palette

## Scripts & Commands

### bootstrap.sh
```bash
./bootstrap.sh --check    # Validate manifest sources and audit destinations
./bootstrap.sh --dry-run  # Preview link creation and backup cleanup without deleting backups
./bootstrap.sh            # Create symlinks, then run cleanup_backups.sh dry-run
./bootstrap.sh --restore  # Remove managed symlinks and restore most recent backups
```
- Loads symlink entries from `lib/link_manifest.sh`
- Logs create/restore/dry-run operations to timestamped files under `logs/`
- Automatically creates parent directories if needed
- Skips destinations already linked to the expected source
- Runs `cleanup_backups.sh` in default dry-run mode after create/dry-run flows
- Set `DOTFILES_SKIP_CLEANUP=1` to skip the automatic backup cleanup report

### cleanup_backups.sh
```bash
./cleanup_backups.sh      # Dry-run: show redundant .bak symlinks
./cleanup_backups.sh -f   # Force: actually remove them
```
- Loads the same `lib/link_manifest.sh` entries as `bootstrap.sh`

### Repo Checks
```bash
./scripts/check-dotfiles.sh
```
- Runs non-destructive syntax (bash, zsh, python, JSON, TOML), manifest, welcome corpus,
  agent config, hook wiring, executable-bit, and resume-marker pattern checks
- Uses optional tools (`zsh`, `python3`, `jq`, `taplo`, `shfmt`, `shellcheck`) when available
- The hook wiring check resolves every `command` in `claude/settings.json` and
  `codex/hooks.json` back to a real executable, so renaming a hook target fails here
  instead of silently disabling the hook
- The tmux hook wiring checks do the same for `@resurrect-hook-post-save-all` and
  `@resurrect-hook-post-restore-all` in `tmux.conf`, which need it more: tmux-resurrect
  discards both a hook's exit status and its stderr, so a renamed target is a completely
  silent no-op. Both compare the *live* tmux option against `tmux.conf`, catching a conf
  edited but never sourced; the save one also asserts the six tmux-resurrect internals
  the carry-over depends on, and the restore one runs `tmux-refit-windows --dry-run`,
  which is the only routine exercise a restore-only hook gets
- The agent-session checks live in `agent-sessions/check.sh`, dispatched from here as a
  single entry and runnable standalone. Re-run after upgrading Claude or Codex — see
  `agent-sessions/README.md`. Its Python syntax check also runs a flat name-binding
  pass: a dropped `import` is invisible to `ast.parse` and turns the save hook into a
  silent no-op, which has happened once

### Utility Scripts (in utils/)
| Script            | Purpose                                             |
|-------------------|-----------------------------------------------------|
| `rfv`             | Ripgrep + FZF + Vim: interactive search-and-open    |
| `kill_ps`         | FZF-based interactive process killer                |
| `agent-sessions/bin/*` | Claude/Codex session <-> pane tooling — see `agent-sessions/README.md` |
| `clip`            | Copy stdin to the clipboard; picks tmux/OSC 52/native transport so it works over SSH without hanging |
| `tmux-refit-windows` | Refit windows whose layout is a different size from the window; `@resurrect-hook-post-restore-all` target, `--dry-run` to preview |
| `shell_welcome`   | Display random ASCII art welcome on shell start     |
| `cowsay_fortune`  | Random cowsay/cowthink with fortune quotes          |
| `color_pwd`       | Print colored working directory                     |
| `file_count`      | Count files per subdirectory                        |
| `add_path`        | Prepend directory to PATH (avoids duplicates)       |

## Development Conventions

### Shell Scripts
- Use `#!/bin/bash` shebang
- Author header: `# __author__ == Junfeng Lei`
- Section separators with comment blocks (e.g., `# ---* Section Name *---` or `# ====...`)
- Colored output: red for errors (`\e[31m`), yellow for warnings (`\e[33m`), green for section headers (`\e[32m`), cyan for paths (`\e[36m`)
- Dry-run by default for destructive operations, `-f`/`--force` to execute

### Adding New Dotfiles
1. Add the config file to the repo root or an appropriate subdirectory
2. Add one entry to `lib/link_manifest.sh`
3. Run `./scripts/check-dotfiles.sh` and `./bootstrap.sh --check`
4. Run `./bootstrap.sh --dry-run` before creating the symlink
5. Run `./bootstrap.sh` to create the symlink

### Git Conventions
- **Default branch**: `main`
- **Commit message prefixes**: `feat:`, `update:`, `fix:` (lowercase, imperative)
- Keep `.gitignore` updated: `*.log`, `*.swp`, `.vscode/`, `.cursor/`, `.claude/settings.local.json`, `CLAUDE.local.md`

### Platform Awareness
- macOS-specific blocks are gated with `[[ "$(uname -s)" == "Darwin" ]]`
- Homebrew paths (`/opt/homebrew/bin`, `/opt/homebrew/sbin`) added only on macOS

### Submodules
- Do not modify git submodule contents directly in this repo; changes to agent skills, nvim, or wezterm configs should go through their respective repositories.

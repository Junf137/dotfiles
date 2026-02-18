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
├── alacritty/              # Alacritty terminal emulator configs
│   └── alacritty-default/  # Symlinked to ~/.config/alacritty
├── claude/                 # Global Claude Code configuration (symlinked to ~/.claude/)
│   ├── CLAUDE.md           # Global Claude policies (symlinked to ~/.claude/CLAUDE.md)
│   └── settings.json       # Permissions config (symlinked to ~/.claude/settings.json)
├── msg/                    # ASCII art welcome messages
│   ├── msg_enjoy_your_day  # Bootstrap banner
│   └── msg_shell_welcome   # Shell startup messages
├── nvim/
│   └── nvim-kickstart/     # Git submodule: Junf137/kickstart.nvim
├── omz_themes/
│   └── ys_customized.zsh-theme  # Custom Oh My ZSH theme
├── tmuxp/
│   └── regular.yaml        # tmuxp session layout
├── utils/                  # Custom shell utility scripts
│   ├── add_path            # PATH management function
│   ├── claude-sessions     # List running Claude Code sessions
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
| `omz_themes/ys_customized.zsh-theme`    | `$ZSH_CUSTOM/themes/...`            |
| `nvim/nvim-kickstart`                   | `~/.config/nvim`                     |
| `wezterm/wezterm-config`                | `~/.config/wezterm`                  |
| `alacritty/alacritty-default`           | `~/.config/alacritty`                |
| `yazi/`                                 | `~/.config/yazi`                     |
| `claude/CLAUDE.md`                      | `~/.claude/CLAUDE.md`               |
| `claude/settings.json`                  | `~/.claude/settings.json`           |
| `/home/junf/Pictures/Background`        | `~/.config/wezterm/backdrops`        |

## Git Submodules

Two configs are managed as separate repos:
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
- **Theme**: Catppuccin Macchiato
- **Key features**: Vi mode, mouse support, 100K history, TPM plugin manager
- **Session management**: tmuxp with layout in `tmuxp/regular.yaml`

### FZF Integration
- **Trigger**: `~~` (not default `**`)
- **Default command**: `fd --unrestricted`
- **Preview**: `bat` for files, `tree` for directories
- **Keybindings**: Ctrl-T (files), Ctrl-R (history), Alt-C (directories)

### Design Theme
- **Catppuccin** color scheme throughout (Macchiato variant by default)
- Consistent across Alacritty, Tmux, and terminal configs

## Scripts & Commands

### bootstrap.sh
```bash
./bootstrap.sh            # Create symlinks (backs up existing files with .TIMESTAMP.bak)
./bootstrap.sh --restore  # Remove symlinks and restore most recent backups
```
- Logs operations to timestamped `bootstrap_*.log` files
- Automatically creates parent directories if needed

### cleanup_backups.sh
```bash
./cleanup_backups.sh      # Dry-run: show redundant .bak symlinks
./cleanup_backups.sh -f   # Force: actually remove them
```

### Utility Scripts (in utils/)
| Script            | Purpose                                             |
|-------------------|-----------------------------------------------------|
| `rfv`             | Ripgrep + FZF + Vim: interactive search-and-open    |
| `kill_ps`         | FZF-based interactive process killer                |
| `claude-sessions` | List running Claude Code sessions with details      |
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
2. Add a `"source:destination"` entry to the `files=()` array in both `bootstrap.sh` and `cleanup_backups.sh`
3. Run `./bootstrap.sh` to create the symlink

### Git Conventions
- **Default branch**: `main`
- **Commit message prefixes**: `feat:`, `update:`, `fix:` (lowercase, imperative)
- Keep `.gitignore` updated: `*.log`, `*.swp`, `.vscode/`, `.cursor/`, `.claude/settings.local.json`, `CLAUDE.local.md`

### Platform Awareness
- macOS-specific blocks are gated with `[[ "$(uname -s)" == "Darwin" ]]`
- Homebrew paths (`/opt/homebrew/bin`, `/opt/homebrew/sbin`) added only on macOS

### Submodules
- Do not modify git submodule contents directly in this repo; changes to nvim or wezterm configs should go through their respective repositories.

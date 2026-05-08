# README
Synchronizing my dotfiles

## Description

This repository contains my personal dotfiles for various applications and tools including:
- Bash and ZSH shell configurations
- Vim configurations
- Git configurations
- tmux settings
- Custom oh-my-zsh themes
- tmuxp session configurations
- Claude and Codex agent skills via the private `agent-skills` submodule

## Usage

```bash
# ---* Attention *---
# Don't run this script until you know what it does

# Clone the repository with submodules
git clone --recurse-submodules git@github.com:Junf137/dotfiles.git ${DOT_FILES:-$HOME/Documents/dotfiles}

# If already cloned, initialize or update submodules
cd ${DOT_FILES:-$HOME/Documents/dotfiles} && git submodule update --init --recursive

# Create symbolic links
./bootstrap.sh

# Check sources and current destination state without changing files
./bootstrap.sh --check

# Preview link creation without changing files
./bootstrap.sh --dry-run

# To remove all symbolic links and restore backups
./bootstrap.sh --restore
```

## Features

- Creates symbolic links from dotfiles in the repository to their appropriate locations
- Uses `lib/link_manifest.sh` as the single symlink manifest for install and cleanup
- Automatically backs up existing files before creating links (with timestamp)
- Skips destinations that are already linked to the expected repo source
- Provides `--check` and `--dry-run` modes before mutation
- Provides restoration capabilities to undo all changes
- Detailed logging of mutating and dry-run operations under `logs/`
- Error reporting and handling

## Available Commands

| Command | Description |
|---------|-------------|
| `./scripts/check-dotfiles.sh` | Run non-destructive repo checks |
| `./bootstrap.sh --check` | Validate manifest sources and audit destinations |
| `./bootstrap.sh --dry-run` | Preview symbolic link creation and backup cleanup without deleting backups |
| `./bootstrap.sh` | Create symbolic links, back up existing differing files, and run backup cleanup in dry-run mode |
| `./bootstrap.sh --restore` | Remove managed symbolic links and restore original files |
| `./cleanup_backups.sh` | Preview redundant backup symlink cleanup |
| `./cleanup_backups.sh --force` | Remove redundant backup symlinks |

Set `DOTFILES_SKIP_CLEANUP=1` to skip the automatic backup cleanup report during `./bootstrap.sh`.

## Log Files

Bootstrap create, restore, and dry-run operations are logged to date-stamped files under `logs/` in the format:
- `bootstrap_YYYY_MM_DD_HH_MM_SS.log` for link creation
- `bootstrap_restore_YYYY_MM_DD_HH_MM_SS.log` for link removal
- `bootstrap_dry_run_YYYY_MM_DD_HH_MM_SS.log` for dry-runs

`logs/` is ignored by git.

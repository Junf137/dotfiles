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
- `agent-sessions/` — maps running Claude/Codex sessions to their tmux pane, and carries
  each pane's session id across a reboot so the restored pane prints what ran there and
  how to resume it (nothing is restarted). See `agent-sessions/README.md`

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

## Codex shared defaults and local settings

`codex/config.toml` contains only portable, intentional defaults. Bootstrap links
it to `/etc/codex/config.toml` on both macOS and Linux. Initial installation and
removal of this system link use `sudo`; run bootstrap as your normal user.
An already-correct link needs no administrator access or extra backup.

`~/.codex/config.toml` is a regular, private file outside this repository. Codex
reads the system defaults first, then applies the user config on top. Machine
paths, project trust, hook approvals, plugin installation state, app settings,
and onboarding state stay in the user file. Do not symlink it into the repository.

Edit `codex/config.toml` to change defaults on both computers, then sync this
repository. Changes made through the app may create local overrides; remove a
duplicated user setting when you want the shared default to apply again. Do not
add local paths or generated state to the shared file. Bootstrap restore removes
the managed system link but leaves the user config untouched.

The migration keeps one original config per machine at
`~/.codex/config.before-shared-defaults.toml`. It is a recovery copy, not a loaded
configuration layer. No recurring backup or config-generation job is needed.

Run `./bootstrap.sh --check` to audit links and
`bash scripts/test-codex-config.sh` to test installation, repeat runs, and restore
in a temporary directory without touching the real system config.

## Log Files

Bootstrap create, restore, and dry-run operations are logged to date-stamped files under `logs/` in the format:
- `bootstrap_YYYY_MM_DD_HH_MM_SS.log` for link creation
- `bootstrap_restore_YYYY_MM_DD_HH_MM_SS.log` for link removal
- `bootstrap_dry_run_YYYY_MM_DD_HH_MM_SS.log` for dry-runs

`logs/` is ignored by git.

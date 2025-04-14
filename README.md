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

## Usage

```bash
# ---* Attention *---
# Don't run this script until you know what it does

# Clone the repository
git clone git@github.com:Junf137/dotfiles.git ${DOT_FILES:-$HOME/Documents/dotfiles}

# Create symbolic links
cd ${DOT_FILES:-$HOME/Documents/dotfiles} && ./bootstrap.sh

# To remove all symbolic links and restore backups
./bootstrap.sh --restore
```

## Features

- Creates symbolic links from dotfiles in the repository to their appropriate locations
- Automatically backs up existing files before creating links (with timestamp)
- Provides restoration capabilities to undo all changes
- Detailed logging of all operations
- Error reporting and handling

## Available Commands

| Command | Description |
|---------|-------------|
| `./bootstrap.sh` | Create symbolic links and back up existing files |
| `./bootstrap.sh --restore` | Remove symbolic links and restore original files |

## Log Files

All operations are logged to date-stamped files in the format:
- `bootstrap_YYYY_MM_DD_HH_MM_SS.log` for link creation
- `bootstrap_restore_YYYY_MM_DD_HH_MM_SS.log` for link removal

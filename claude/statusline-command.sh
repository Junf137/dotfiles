#!/usr/bin/env bash
# Claude Code statusLine script
# Mirrors the ys_customized zsh theme: user@host in [dir] on git:BRANCH STATE

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // .model.id')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# User and host
user=$(whoami)
host=$(hostname -s)

# Short path: replace $HOME with ~
short_path=$(echo "$cwd" | sed "s|^$HOME|~|")

# Git info (skip optional locks)
git_branch=""
git_state=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
                 || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    if [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
        git_state="x"   # dirty
    else
        git_state="o"   # clean
    fi
fi

# Context window
ctx_part=""
if [ -n "$remaining" ]; then
    ctx_part=" ctx:$(printf '%.0f' "$remaining")%"
fi

# Rate limits (5-hour)
rate_part=""
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
if [ -n "$five_pct" ]; then
    rate_part=" 5h:$(printf '%.0f' "$five_pct")%"
fi

# Assemble output with ANSI colors
# yellow bold box-drawing, cyan user, green host, bold-yellow dir,
# blue git, dim conda, dim model info
RESET='\033[0m'
BOLD='\033[1m'
YELLOW='\033[33m'
CYAN='\033[36m'
GREEN='\033[32m'
BLUE='\033[34m'
RED='\033[31m'
DIM='\033[2m'

line="${BOLD}${BLUE}${RESET} "
line+="${BOLD}${BLUE}${short_path}${RESET}"

if [ -n "$git_branch" ]; then
    if [ "$git_state" = "x" ]; then
        state_color="${RED}"
    else
        state_color="${GREEN}"
    fi
    line+=" ${GREEN} git:${git_branch}${RESET} ${state_color}${git_state}${RESET}"
fi

line+=" ${DIM}✻${RESET} ${DIM}${model}${RESET}"

if [ -n "$ctx_part" ]; then
    line+=" ${DIM}·${RESET}${ctx_part}"
fi

if [ -n "$rate_part" ]; then
    line+=" ${DIM}·${RESET}${rate_part}"
fi

printf "%b\n" "$line"

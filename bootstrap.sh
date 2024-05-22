#!/bin/bash

# __auther__ == Junfeng Lei
# --------------------------------
# Description:
#   Linking dot files to home directory
# usage:
# 	1) ./bootstrap.sh
# --------------------------------

# ---* Global Variable *---
TIME_STAMP="$(date +'%Y_%m_%d_%H_%M_%S')"
LOG_FILE_NAME="bootstrap_$TIME_STAMP.log"
error_cnt=0

# ---* Global env *---
export DOT_FILES="$HOME/Documents/dotfiles"
export ZSH="$HOME/.local/share/oh-my-zsh"
export ZSH_CUSTOM="$ZSH/custom"


# ---* Functions *---
function error_print() {
    if [ $# != 0 ]; then    # parameters are given
        echo -e "\e[31m[Error]\e[0m: $@"
    fi

    error_cnt=$(($error_cnt+1))
}

function log_print() {
    if [ $# != 0 ]; then    # parameters are given
        echo -e "$@"
    fi
}

function warn_print() {
    if [ $# != 0 ]; then    # parameters are given
        echo -e "\e[33m[Warn]\e[0m: $@"
    fi
}

create_soft_link() {
    # Check if the required number of arguments is provided
    if [ "$#" -ne 2 ]; then
        error_print "Usage: create_soft_link ori_name dst_name"
        return 1
    fi

    ori_name="$1"
    dst_name="$2"

    log_print ""
    log_print "\e[32m---* $dst_name \e[0m"

    # Check if the destination file or link already exists
    if [ -e "$dst_name" ]; then
        warn_print "File '$dst_name' already exists."

        # Rename the existing file. Add a suffix with the current time
        mv "$dst_name" "$dst_name.$TIME_STAMP.bak"
        if [ $? -eq 0 ]; then
            log_print "File renamed: $dst_name -> $dst_name.$TIME_STAMP.bak"
        else
            error_print "Failed to rename file: $dst_name -> $dst_name.$TIME_STAMP.bak"
            return 1
        fi
    fi

    # Check if the original file exists
    if [ ! -e "$ori_name" ]; then
        error_print "File '$ori_name' does not exist."
        return 1
    fi

    # Check if the path to the destination file exists
    dst_dir=$(dirname "$dst_name")
    if [ ! -d "$dst_dir" ]; then
        warn_print "Directory '$dst_dir' does not exist."

        # Create the directory
        mkdir -p "$dst_dir"
        if [ $? -eq 0 ]; then
            log_print "Directory created: $dst_dir"
        else
            error_print "Failed to create directory: $dst_dir"
            return 1
        fi
    fi

    # log_print "ori_name: $ori_name"
    # log_print "dst_name: $dst_name"

    # Create a symbolic link
    ln -s "$ori_name" "$dst_name"
    if [ $? -eq 0 ]; then
        log_print "Symbolic link created: \e[36m$dst_name -> $ori_name\e[0m"
    else
        error_print "Failed to create symbolic link: $dst_name -> $ori_name"
        return 1
    fi
}

# ---* Process Start *---

# Redirect stdin and stdout to the log file and tee
exec > >(tee -a "$LOG_FILE_NAME") 2>&1

# Print welcome msg
cat "./msg/msg_enjoy_your_day"
log_print "------------------------------"
log_print "time: $TIME_STAMP"
log_print "------------------------------"
log_print "[Process Start]"


# Define an array of filenames to link
files=(
    # 1. links to home directory
    "$DOT_FILES/bashrc:$HOME/.bashrc"
    "$DOT_FILES/zshrc:$HOME/.zshrc"
    "$DOT_FILES/vimrc:$HOME/.vimrc"
    "$DOT_FILES/tmux.conf:$HOME/.tmux.conf"
    "$DOT_FILES/gitconfig:$HOME/.gitconfig"

    # 2. links to oh-my-zsh themes
    "$DOT_FILES/omz_themes/ys_customized.zsh-theme:$ZSH_CUSTOM/themes/ys_customized.zsh-theme"

    # 3. links to tmuxp files
    "$DOT_FILES/tmuxp:$HOME/.tmuxp"
    # Add more files here as needed
)


for file in "${files[@]}"; do
    # Get source filename from array element
    src="${file%%:*}"
    # Get destination filename from array element
    dest="${file#*:}"

    create_soft_link "$src" "$dest"
done


log_print ""
log_print "[Process End]"


# ---* Process End *---
if [ $error_cnt == 0 ]; then
    log_print "--------------------------------------------------"
    log_print "time: $TIME_STAMP"
    log_print "Enjoy Your Day! :)"
    log_print "--------------------------------------------------"
else
    log_print "--------------------------------------------------"
    log_print "time: $TIME_STAMP"
    log_print "total error: $error_cnt"
    log_print "Check the error and rerun this script :("
    log_print "--------------------------------------------------"
fi

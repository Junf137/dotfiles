#!/bin/bash

# __auther__ == Junfeng Lei
# --------------------------------
# Description:
#   Linking dot files to home directory
# usage:
# 	1) ./bootstrap.sh
# --------------------------------

# ---* Global Variable *---
# Set log file name
LOG_FILE_NAME="bootstrap_$(date +'%Y_%m_%d_%H_%M_%S').log"
# Keep recording error count
error_cnt=0

# ---* Global env *---
export DOT_FILES="$HOME/Documents/dotfiles"
export ZSH="$HOME/.local/share/oh-my-zsh"
export ZSH_CUSTOM="$ZSH/custom"

export ORI_PATH="$DOT_FILES"
export DST_PATH="$HOME"

# ---* Functions *---
function error_print() {
    if [ $# != 0 ]; then    # parameters are given
        echo -e "[Error]: $1"
    fi

    error_cnt=$(($error_cnt+1))
}

function log_print() {
    if [ $# != 0 ]; then    # parameters are given
        echo -e "[Log]: $1"
    fi
}

function warn_print() {
    if [ $# != 0 ]; then    # parameters are given
        echo -e "[Warn]: $1"
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

    log_print "$dst_name -> $ori_name"

    # Check if the destination file already exists
    if [ -e "$dst_name" ]; then
        warn_print "File '$dst_name' already exists."

        # Ask the user whether to delete the existing file
        read -p "Do you want to delete it and create a symbolic link? (y/n): " choice

        case "$choice" in
            y|Y)
                # Delete the existing file
                if rm "$dst_name"; then
                    log_print "File '$dst_name' deleted."
                else
                    error_print "Failed to delete '$dst_name'."
                    return 1
                fi
                ;;

            n|N)
                # User chose not to delete the file
                error_print "Symbolic link creation aborted."
                return
                ;;

            *)
                # Invalid choice
                error_print "Invalid choice. Symbolic link creation aborted."
                return
                ;;
        esac
    fi

    # Create a symbolic link
    if ln -s "$ori_name" "$dst_name"; then
        log_print "Symbolic link created: $dst_name -> $ori_name"
    else
        error_print "Failed to create symbolic link."
        return 1
    fi
}

# ---* Process Start *---

# Redirect stdin and stdout to the log file and tee
exec > >(tee -a "$LOG_FILE_NAME") 2>&1

# Print welcome msg
cat "./msg/msg_enjoy_your_day"
echo -e "--------------------------------------------------"
echo -e "time: $(date +%F%t%T)"
echo -e "--------------------------------------------------"
echo -e ""
echo -e "[Process Start]"
echo -e "--* This script helps you finish trivial settings *--"
echo -e ""

# Create link in home directory
link_array=(bashrc vimrc tmux.conf gitconfig zshrc)
for ((i=0;i<${#link_array[*]};i++)); do

    ori_name="$ORI_PATH/${link_array[$i]}"
    dst_name="$DST_PATH/.${link_array[$i]}"

    create_soft_link "$ori_name" "$dst_name"
done

# Create link for customized zsh theme
ori_name="$ORI_PATH/ys_customized"
dst_name="$ZSH/themes/ys_customized.zsh-theme"

create_soft_link "$ori_name" "$dst_name"

# ---* Process End *---
echo ""

if [ $error_cnt == 0 ]; then
    log_print ""
    log_print "********************************************************"
    log_print "Almost done, there are few things you need to do:"
    log_print "  1. Change the password in $DOT_FILES/utils/update_auto"
    log_print "  2. Check what else files you need in $DOT_FILES that didn't automatically linked by this script"
    log_print ""
    log_print "--*               Enjoy your day!  :D                *--"
    log_print "********************************************************"
else
    log_print "script executing failed"
    log_print "total error: $error_cnt"
    log_print "Check the error and rerun this script :)"
fi

log_print ""
log_print "--------------------------------------------------"
log_print "[Process End]"

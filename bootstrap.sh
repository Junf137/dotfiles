#!/bin/bash

# __auther__ == eric
# --------------------------------
# Description:
#   links dots files to your home directory
# usage:
# 	1) ./bootstrap.sh
# 	2) sh ./bootstrap.sh
# --------------------------------


# detect whether command foo exist - (1)
# command -v foo >/dev/null 2>&1 || { echo >&2 "I require foo but it's not installed.  Aborting." }

# detect whether command foo exist - (2)
# if command -v git >/dev/null 2>&1; then
#     echo "foo exist"
# else
#     echo "foo doesn't exist"
# fi




# --------------------------------
# Description:
#   Terminate this shell script and print limited information at the same time.
# Usage:
#   error_print 0
#   error_print information
# --------------------------------
function error_print() {
    if [ $# != 0 ]; then    # parameters are given
        echo -e "[Log]: Error_[$1]" >> ./bootstrap.log
        echo -e "[Log]: Error_[$1]"
    fi
    error_cnt=$(($error_cnt+1))
}



# ---* Process Start *---
cat "./msg/msg_enjoy_your_day"  # print welcome msg
echo -e "current time: $(date +%F%t%T)" >> ./bootstrap.log
echo -e "current time: $(date +%F%t%T)"
echo "  -------------------------------------------------------------------  " >> ./bootstrap.log
echo "  -------------------------------------------------------------------  "
echo "[Process Start]
--* This script helps you finish trivial settings *--
"

# export global env path
export DOT_FILES="$HOME/Documents/dotfiles"
export WASTE_BASKET="$HOME/.local/share/Trash"

error_cnt=0

# create link in home directory
link_array=(bashrc vimrc tmux.conf gitconfig zshrc)
for ((i=0;i<${#link_array[*]};i++)); do
    echo -e "--* $HOME/.${link_array[$i]}"

    if [ -L "$HOME/.${link_array[$i]}"  ] || [ -f "$HOME/.${link_array[$i]}"  ]; then
        echo -e "[Warning]: $HOME/.${link_array[$i]} already exist!"
        echo -n "Continue and delete it ? Your data won't be saved [y/n] >> "
        read ifDelete
        echo -e ""

        case $ifDelete in
            [yY])
                echo -e "[Log]: rm $HOME/.${link_array[$i]}" >> ./bootstrap.log
                echo -e "[Log]: rm $HOME/.${link_array[$i]}"
                rm $HOME/.${link_array[$i]}
                if [ $? == 1 ]; then
                    exit_script rm_failed
                fi

                echo -e "[Log]: ln -s $DOT_FILES/${link_array[$i]} $HOME/.${link_array[$i]}" >> ./bootstrap.log
                echo -e "[Log]: ln -s $DOT_FILES/${link_array[$i]} $HOME/.${link_array[$i]}"
                ln -s $DOT_FILES/${link_array[$i]} $HOME/.${link_array[$i]}
                if [ $? == 1 ]; then
                    error_print link_failed
                fi
                ;;
            [nN])
                error_print FILE_EXIST
                ;;
            *)
                echo "[Warning]: Invalid option, enter y or n, plz:)"
                error_print FILE_EXIST
                ;;
        esac

    else
        echo -e "[Log]: ln -s $DOT_FILES/${link_array[$i]} $HOME/.${link_array[$i]}" >> ./bootstrap.log
        echo -e "[Log]: ln -s $DOT_FILES/${link_array[$i]} $HOME/.${link_array[$i]}"
        ln -s $DOT_FILES/${link_array[$i]} $HOME/.${link_array[$i]}
        if [ $? == 1 ]; then
            error_print link_failed
        fi
    fi

    echo ""
done

# todo
echo -e "--* $ZSH/themes/ys_customized.zsh-theme"

if [ -L "$ZSH/themes/ys_customized.zsh-theme"  ] || [ -f "$ZSH/themes/ys_customized.zsh-theme"  ]; then
    echo -e "[Warning]: $ZSH/themes/ys_customized.zsh-theme already exist!"

    echo -e "[Log]: rm $ZSH/themes/ys_customized.zsh-theme" >> ./bootstrap.log
    echo -e "[Log]: rm $ZSH/themes/ys_customized.zsh-theme"
    rm $ZSH/themes/ys_customized.zsh-theme
fi

echo -e "[Log]: ln -s $DOT_FILES/ys_customized  $ZSH/themes/ys_customized.zsh-theme" >> ./bootstrap.log
echo -e "[Log]: ln -s $DOT_FILES/ys_customized  $ZSH/themes/ys_customized.zsh-theme"
ln -s $DOT_FILES/ys_customized  $ZSH/themes/ys_customized.zsh-theme
echo ""





if [ $error_cnt == 0 ]; then
    echo -e ""
    echo -e "********************************************************"
    echo -e "Almost done, there are few things you need to do:"
    echo -e "  1.Please change your password in $DOT_FILES.update"
    echo -e "  2.check what else files you need in $DOT_FILES that didn't automatically linked by this script"
    echo -e ""
    echo -e "--*               Enjoy your day!  :D                *--"
    echo -e "********************************************************"
else
    echo "[Log]: script executing failed" >> ./bootstrap.log
    echo "[Log]: script executing failed"
    echo "[Log]: total error: $error_cnt" >> ./bootstrap.log
    echo "[Log]: total error: $error_cnt"
    echo "[Log]: please check the error and rerun this script again :)" >> ./bootstrap.log
    echo "[Log]: please check the error and rerun this script again :)"
fi

# ---* Process End *---
echo "  -------------------------------------------------------------------  "
echo -e "[Process End]"

#!/bin/bash


cdls() {
    
    local dir="$1"
    local dir="${dir:=$HOME}"
    if [[ "$dir" == "-" ]]; then
        if [[ -d "$CDLS_TEMP_DIR" ]]; then
            cd $CDLS_TEMP_DIR  >/dev/null; ls -aCF --color=always
        else
            echo "bash: cdls: $dir: Directory not found"
        fi
    elif [[ -d "$dir" ]]; then
        export CDLS_TEMP_DIR=$(pwd)
        cd "$dir" >/dev/null; ls -aCF --color=always
    else
        echo "bash: cdls: $dir: Directory not found"
    fi
}

alias cd="cdls"

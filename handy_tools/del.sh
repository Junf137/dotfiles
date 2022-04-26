#!/bin/bash

# del - move named files to a hidden wastbasket 
# Version-1
#

del(){
    if [[ -z "$WASTE_BASKET" ]]; then
        echo -e "[Warning]:\tError_no_WASTE_BASKET"
        echo -e "Please check your environment variables and restart shell"
    else
        if [[ ! -d "$WASTE_BASKET" ]]; then
            mkdir $WASTE_BASKET
        fi
        mv -i $*  $WASTE_BASKET
    fi
    
}

junk_clear() {
    if [[ -z "$WASTE_BASKET" ]]; then
        echo -e "[Warning]:\tError_no_WASTE_BASKET"
        echo -e "Please check your environment variables and restart shell"
    else
        if [[ ! -d "$WASTE_BASKET" ]]; then
            echo -e "no "$WASTE_BASKET", create new dir"
            mkdir $WASTE_BASKET
        else
            echo -e "Continue and clear "$WASTE_BASKET" ? [y/n] "
            read -n ifDelete
            echo -e ""
            case $ifDelete in
                [yY])
                    rm -rf  $WASTE_BASKET/.*
                    echo -e "clear "$WASTE_BASKET" done :)"
                    ;;
                [nN])
                    ;;
                *)
                    echo -e "[Warning]\tError_invalid_option, enter y or n, plz :)"
                    ;;
            esac
        fi
    fi
}

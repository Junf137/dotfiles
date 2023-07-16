#!/bin/bash


update_auto() {
    local passwd=""
    echo $passwd |  sudo -S apt update
    echo $passwd |  sudo -S apt upgrade -y
}

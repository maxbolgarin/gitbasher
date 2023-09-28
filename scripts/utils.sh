#!/usr/bin/env bash

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
PURPLE="\e[35m"
CYAN="\e[36m"
ENDCOLOR="\e[0m"

function prepare_path {
    eval echo "$1"
}

function reverse() {
    # first argument is the array to reverse
    # second is the output array
    declare -n arr="$1" rev="$2"
    for i in "${arr[@]}"
    do
        rev=("$i" "${rev[@]}")
    done
}

function check_code {
    if [ $1 != 0 ]; then
        echo -e "${RED}Error during $3${ENDCOLOR}"
        echo -e "$2"
        exit $1
    fi
}
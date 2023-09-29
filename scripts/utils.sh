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

### Function returns git log diff between provided argument and HEAD
# $1: branch or commit from which to calc diff
function gitlog_diff {
    git --no-pager log --pretty=format:"\t%h - %an, %ar:\t%s\n" $1..HEAD 2>&1
}


push_log=""
history_from=""

### Function sets to variables push_log and history_from actual push log information
# $1: current branch
# $2: main branch
function get_push_log {
    push_log=$(gitlog_diff origin/$1)
    history_from="origin/$1"

    if [[ $push_log == *"unknown revision or path not in the working tree"* ]]; then
        base_commit=$(diff -u <(git rev-list --first-parent $1) <(git rev-list --first-parent $2) | sed -ne 's/^ //p' | head -1)
        if [ -n "$base_commit" ]; then
            push_log=$(gitlog_diff ${base_commit})
            history_from="${base_commit::7}"
        else
            push_log=$(gitlog_diff "origin/$2")
            history_from="origin/$2"
        fi
    fi
}

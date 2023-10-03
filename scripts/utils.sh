#!/usr/bin/env bash

### Consts for colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
PURPLE="\e[35m"
CYAN="\e[36m"
ENDCOLOR="\e[0m"


### Consts for colors to use inside 'sed'
RED_ES="\x1b[31m"
GREEN_ES="\x1b[32m"
YELLOW_ES="\x1b[33m"
BLUE_ES="\x1b[34m"
PURPLE_ES="\x1b[35m"
CYAN_ES="\x1b[36m"
ENDCOLOR_ES="\x1b[0m"


### Function for evaluating path with '~' symbol
# $1: path
function prepare_path {
    eval echo "$1"
}


### Function reverts array
# $1: array to reverse
# $2: output array
function reverse() {
    declare -n arr="$1" rev="$2"
    for i in "${arr[@]}"
    do
        rev=("$i" "${rev[@]}")
    done
}


commit_hash=""
git_add=""

### Function prints the list of commits and user should choose one
# $1: number of last commits to show
function choose_commit {
    commits_info_str=$(git log --pretty="%h | %s | %an | %cr" -n $1 | column -ts'|')
    commits_hash_str=$(git log --pretty="%h" -n $1)
    IFS=$'\n' read -rd '' -a commits_info <<<"$commits_info_str"
    IFS=$'\n' read -rd '' -a commits_hash <<<"$commits_hash_str"

    number_of_commits=${#commits_info[@]}

    for index in "${!commits_info[@]}"
    do
        commit_line=$(sed "s/${commits_hash[index]}/${YELLOW_ES}${commits_hash[index]}${ENDCOLOR_ES}/g" <<< ${commits_info[index]})
        echo -e "$(($index+1)). ${commit_line}"
    done
    echo "0. Exit..."
    # TODO: add navigation

    echo
    printf "Enter commit number: "

    while [ true ]; do
         if [ $number_of_commits -gt 9 ]; then
            read -n 2 choice
        else
            read -n 1 -s choice
        fi

        if [ "$choice" == "0" ] || [ "$choice" == "00" ]; then
            if [ -n "$git_add" ]; then
                git restore --staged $git_add
            fi
            printf $choice
            exit
        fi

        re='^[0-9]+$'
        if ! [[ $choice =~ $re ]]; then
           continue
        fi

        index=$(($choice-1))
        commit_hash=${commits_hash[index]}
        if [ -n "$commit_hash" ]; then
            printf $choice
            break
        fi
    done
    return
}


### Function checks code against 0 and show error
# $1: return code
# $2: command output (error message)
# $3: comand name
function check_code {
    if [ $1 != 0 ]; then
        echo
        echo
        echo -e "${RED}Error during $3${ENDCOLOR}"
        echo -e "$2"
        if [ -n "$git_add" ]; then
            git restore --staged $git_add
        fi
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
# $3: origin name
function get_push_log {
    origin_name="origin"
    if [ -n "$3" ]; then
        origin_name="$3"
    fi 
    push_log=$(gitlog_diff ${origin_name}/$1)
    history_from="${origin_name}/$1"

    if [[ $push_log == *"unknown revision or path not in the working tree"* ]]; then
        base_commit=$(diff -u <(git rev-list --first-parent $1) <(git rev-list --first-parent $2) | sed -ne 's/^ //p' | head -1)
        if [ -n "$base_commit" ]; then
            push_log=$(gitlog_diff ${base_commit})
            history_from="${base_commit::7}"
        else
            push_log=$(gitlog_diff "${origin_name}/$2")
            history_from="${origin_name}/$2"
        fi
    fi
}

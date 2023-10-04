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


### Function checks code against 0 and show error
# $1: return code
# $2: command output (error message)
# $3: command name
function check_code {
    if [ $1 != 0 ]; then
        echo
        echo
        echo -e "${RED}Error during $3!${ENDCOLOR}"
        echo -e "$2"
        if [ -n "$git_add" ]; then
            git restore --staged $git_add
        fi
        exit $1
    fi
}


### This function asks user to enter yes or no, it will exit at no answer
# $1: What to write to console on success
function yes_no_choice {
    while [ true ]; do
        read -n 1 -s choice
        if [ "$choice" == "y" ]; then
            if [ -n "$1" ]; then
                echo -e "${YELLOW}$1${ENDCOLOR}"
                echo
            fi
            return
        fi
        if [ "$choice" == "n" ]; then
            exit
        fi
    done
}


### Function prints the list of commits and user should choose one
# $1: number of last commits to show
# Returns: 
#     commit_hash - hash of selected commit
function choose_commit {
    commits_info_str=$(git log --pretty="%h | %s | %an | %cr" -n $1 | column -ts'|')
    commits_hash_str=$(git log --pretty="%h" -n $1)
    IFS=$'\n' read -rd '' -a commits_info <<<"$commits_info_str"
    IFS=$'\n' read -rd '' -a commits_hash <<<"$commits_hash_str"

    number_of_commits=${#commits_info[@]}

    for index in "${!commits_info[@]}"
    do
        commit_line=$(sed "1,/${commits_hash[index]}/ s/${commits_hash[index]}/${YELLOW_ES}${commits_hash[index]}${ENDCOLOR_ES}/" <<< ${commits_info[index]})
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
            if [ $number_of_commits -le 9 ]; then
                printf $choice
            fi
            exit
        fi

        re='^[0-9]+$'
        if ! [[ $choice =~ $re ]]; then
            if [ $number_of_commits -gt 9 ]; then
                exit
            fi
            continue
        fi

        index=$(($choice-1))
        commit_hash=${commits_hash[index]}
        if [ -n "$commit_hash" ]; then
            if [ $number_of_commits -le 9 ]; then
                printf $choice
            fi
            break
        else
            if [ $number_of_commits -gt 9 ]; then
                exit
            fi
        fi
    done

    echo
    return
}


### Function returns git log diff between provided argument and HEAD
# $1: branch or commit from which to calc diff
function gitlog_diff {
    git --no-pager log --pretty=format:"\t%h - %an, %ar:\t%s\n" $1..HEAD 2>&1
}


### Function sets to variables push_log and history_from actual push log information
# $1: current branch
# $2: main branch
# $3: origin name
# Returns: 
#     push_log - unpushed commits
#     history_from - branch or commit from which history was calculated
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


### Function pulls provided branch, handles errors and makes a merge
# $1: branch name
# $2: origin name
# $3: editor
function pull {
    pull_output=$(git pull $2 $1 --no-rebase 2>&1)
    pull_code=$?

    ### Successful pull
    if [ $pull_code -eq 0 ] ; then
        echo -e "${GREEN}Successful pull!${ENDCOLOR}"
        return
    fi

    ### Cannot pull because there is uncommitted files that changed in origin
    if [[ $pull_output == *"Please commit your changes or stash them before you merge"* ]]; then
        echo -e "${RED}Cannot pull! There is uncommited changes, that will be overwritten by merge${ENDCOLOR}"
        files_to_commit=$(echo "$pull_output" | tail -n +4 | head -n +1)
        echo -e "${YELLOW}Files with changes${ENDCOLOR}"
        echo "$files_to_commit"
        exit $pull_code
    fi

    ### Cannot pull because of some other error
    if [[ $pull_output != *"fix conflicts and then commit the result"* ]]; then
        echo -e "${RED}Cannot pull! Here is the error${ENDCOLOR}"
        echo "$pull_output"
        exit $pull_code
    fi

    ### Cannot pull because there is conflict in committed and pulled files, user should merge changes
    echo -e "${RED}Cannot pull! There are conflicts in staged files${ENDCOLOR}"
    merge $1 $2 $3
}


### Function pulls provided branch, handles errors and makes a merge
# $1: branch name
# $2: origin name
# $3: editor
function merge {

    ### Print files with conflicts
    echo -e "${YELLOW}Files with conflicts${ENDCOLOR}"
    IFS=$'\n' read -rd '' -a files_with_conflicts <<<"$(git --no-pager diff --name-only --diff-filter=U --relative)"
    echo -e "$(sed 's/^/\t/' <<< "$files_with_conflicts")"
    echo


    ### Ask user what he wants to do
    default_message="Merge branch '$2/$1' into '$1'"
    echo -e "${YELLOW}You should fix conflicts manually.${ENDCOLOR} There are some options:"
    echo -e "1. Create merge commit with generated message and continue push"
    printf "\tMessage: ${BLUE}${default_message}${ENDCOLOR}\n"
    echo -e "2. Create merge commit with entered message and continue push"
    echo -e "3. Abort merge (undo pulling)"
    echo -e "Press any another key to exit from this script without merge abort"


    ### Merge process
    while [ true ]; do
        read -n 1 -s choice

        re='^[0-9]+$'
        if ! [[ $choice =~ $re ]]; then
            exit
        fi

        if [ "$choice" == "1" ] || [ "$choice" == "2" ]; then
              echo
              merge_commit $choice $files_with_conflicts $default_message $1 $2 $3
        fi

        if [ "$choice" == "3" ]; then
            echo
            echo -e "${YELLOW}Cancel merge and undo pull${ENDCOLOR}"
            git merge --abort
            exit $?
        fi

        if [ "$choice" == "0" ]; then
            exit
        fi
    done
}


### Function creates merge commit
# $1: 1 for merge with default message, 2 for merge with editor
# $2: files with conflicts that should be added to commit
# $3: default message for merge with $1 -eq 1
# $4: branch name
# $5: origin name
# $6: editor
function merge_commit {

    ### Check if there are files with conflicts
    IFS=$'\n' read -rd '' -a files_with_conflicts_new <<<"$(grep --files-with-matches -r -E "[<=>]{7} HEAD" .)"
    number_of_conflicts=${#files_with_conflicts_new[@]}
    if [ $number_of_conflicts -gt 0 ]; then
        echo -e "${YELLOW}There are still some files with conflicts${ENDCOLOR}"
        for index in "${!files_with_conflicts_new[@]}"
        do
            echo -e $(sed '1 s/.\///' <<< "\t${files_with_conflicts_new[index]}")
        done

        echo
        echo -e "Fix conflicts and press ${YELLOW}$1${ENDCOLOR} for one more time"
        return
    fi


    ### Add files with resolved conflicts to commit
    files_with_conflicts_one_line="$(tr '\n' ' ' <<< "$2")"
    git add $files_with_conflicts_one_line

    ### 1. Commit with default message
    if [ "$1" == "1" ]; then
        result=$(git commit -m "$3" 2>&1)
        check_code $? "$result" "merge commit"

    ### 2. Commit with entered message
    else
        staged_with_tab="$(sed 's/^/###\t/' <<< "$2")"
        commitmsg_file=".commitmsg__"
        touch $commitmsg_file
        echo """
###
### Write a message about merge from '$5/$4' into '$4'. Lines starting with '#' will be ignored. 
### 
### On branch ${branch}
### Changes to be commited:
${staged_with_tab}
""" >> $commitmsg_file
        while [ true ]; do
            $6 $commitmsg_file
            commit_message=$(cat $commitmsg_file | sed '/^#/d')

            if [ -n "$commit_message" ]; then
                break
            fi
            echo
            echo -e "${YELLOW}Merge commit message cannot be empty${ENDCOLOR}"
            echo
            read -n 1 -p "Try for one more time? (y/n) " -s -e choice
            if [ "$choice" != "y" ]; then
                git restore --staged $files_with_conflicts_one_line
                find . -name "$commitmsg_file*" -delete
                exit
            fi    
        done

        find . -name "$commitmsg_file*" -delete
        
        result=$(git commit -m """$commit_message""" 2>&1)
        check_code $? "$result" "merge commit"
    fi

    echo -e "${GREEN}Successful merge!${ENDCOLOR}"
    echo
}

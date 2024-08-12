#!/usr/bin/env bash

### Consts for colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
PURPLE="\e[35m"
CYAN="\e[36m"
GRAY="\e[37m"
ENDCOLOR="\e[0m"
BOLD="\033[1m"
NORMAL="\033[0m"


### Consts for colors to use inside 'sed'
RED_ES="\x1b[31m"
GREEN_ES="\x1b[32m"
YELLOW_ES="\x1b[33m"
BLUE_ES="\x1b[34m"
PURPLE_ES="\x1b[35m"
CYAN_ES="\x1b[36m"
GRAY_ES="\x1b[37m"
ENDCOLOR_ES="\x1b[0m"


### Cannot use bash version less than 4 because of many features that was added to language in that version
if ((BASH_VERSINFO[0] < 4)); then 
    printf "Sorry, you need at least ${YELLOW}bash-4.0${ENDCOLOR} to run this script.\n
If your OS is debian-based, use:
    ${GREEN}apt install --only-upgrade bash${ENDCOLOR}\n
If your OS is mac, use:
    ${GREEN}brew install bash${ENDCOLOR}\n\n" 
    exit 1; 
fi


### Useful consts
current_branch=$(git branch --show-current)
origin_name=$(git remote -v | head -n 1 | sed 's/\t.*//')
main_branch="main"
if [ "$(git branch | grep -w master)" != "" ]; then
    main_branch="master"
fi


### Function tries to get config from local, then from global, then returns default
# $1: config name
# $2: default value
# Returns: config value
function get_config_value {
    value=$(git config --local --get $1)
    if [ -z $value ]; then
        value=$(git config --global --get $1)
        if [ -z $value ]; then
            value=$2
        fi
    fi
    echo -e "$value"
}


### Function sets git config value
# $1: name
# $2: value
# $3: global flag
# Returns: value
function set_config_value {
    if [ -z $3 ]; then
        git config --local $1 $2
    else
        git config --global $1 $2
    fi
    echo "$2"
}


### Function should be used in default case in script mode selection
# $1: script name
# $2: entered mode
function wrong_mode {
    if [ -n "$2" ]; then
        echo -e "Unknown mode ${YELLOW}$2${ENDCOLOR} for ${YELLOW}gitb $1${ENDCOLOR}"
        echo -e "Use ${GREEN}gitb $1 help${ENDCOLOR} to get usage info"
        exit
    fi
}


### Function echoes (true return) url to current user's repo (remote)
# Return: url to repo
function get_repo {
    repo=$(git config --get remote.${origin_name}.url)
    repo="${repo/"com:"/"com/"}"
    repo="${repo/"io:"/"io/"}"
    repo="${repo/"org:"/"org/"}"
    repo="${repo/"net:"/"net/"}"
    repo="${repo/"ru:"/"ru/"}"
    repo="${repo/"git@"/"https://"}"
    repo="${repo/".git"/""}" 
    echo "$repo"
}


### Function echoes (true return) name of current repo
function get_repo_name {
    repo=$(get_repo)
    echo "${repo##*/}"
}


### Function to escape substring in string
# $1: string
# $2: substring to escape
# Returns: provided string with escaped substring
function escape {
    string="$1"
    sub="$2"
    escaped="\\$sub"
    echo "${string//${sub}/${escaped}}"
}


### Function checks code against 0 and show error
# $1: return code
# $2: command output (error message)
# $3: command name
# Using of global:
#     * git_add
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


### Function asks user to enter yes or no, it will exit if user answers 'no'
# $1: what to write in console on success
# $2: flag no echo
function yes_no_choice {
    while [ true ]; do
        read -n 1 -s choice
        if [ "$choice" == "y" ]; then
            if [ -n "$1" ]; then
                echo -e "${YELLOW}$1${ENDCOLOR}"
                if [ -z $2 ]; then
                    echo
                fi
            fi
            return
        fi
        if [ "$choice" == "n" ]; then
            exit
        fi
    done
}


### Function waits a number from user and returns result of choice from a provided list
# $1: list of values
# Returns: 
#     * choice_result
# Using of global:
#     * git_add
function choose {
    values=("$@")
    number_of_values=${#values[@]}

    while [ true ]; do
        if [ $number_of_values -gt 9 ]; then
            read -n 2 choice
        else
            read -n 1 -s choice
        fi

        if [ "$choice" == "0" ] || [ "$choice" == "00" ]; then
            if [ -n "$git_add" ]; then
                git restore --staged $git_add
            fi
            if [ $number_of_values -le 9 ]; then
                printf $choice
            fi
            exit
        fi

        re='^[0-9]+$'
        if ! [[ $choice =~ $re ]]; then
            if [ $number_of_values -gt 9 ]; then
                exit
            fi
            continue
        fi

        index=$(($choice-1))
        choice_result=${values[index]}
        if [ -n "$choice_result" ]; then
            if [ $number_of_values -le 9 ]; then
                printf $choice
            fi
            break
        else
            if [ $number_of_values -gt 9 ]; then
                exit
            fi
        fi
    done
}


### Function prints fiels from git status in a pretty way
function git_status {
    status_output=$(git status --short)
    status_output=$(echo "$status_output" | sed "s/^ D/${RED_ES}\tDeleted: ${ENDCOLOR_ES}/")
    status_output=$(echo "$status_output" | sed "s/^D /${GREEN_ES}Staged\t${RED_ES}Deleted: ${ENDCOLOR_ES}/")

    status_output=$(echo "$status_output" | sed "s/^ M/${YELLOW_ES}\tModified:${ENDCOLOR_ES}/")
    status_output=$(echo "$status_output" | sed "s/^MM/${GRAY_ES}Old\t${YELLOW_ES}Modified:${ENDCOLOR_ES}/")
    status_output=$(echo "$status_output" | sed "s/^AM/${GRAY_ES}Old\t${YELLOW_ES}Modified:${ENDCOLOR_ES}/")
    status_output=$(echo "$status_output" | sed "s/^M /${GREEN_ES}Staged\t${YELLOW_ES}Modified:${ENDCOLOR_ES}/")

    status_output=$(echo "$status_output" | sed "s/^A/${GREEN_ES}Staged\tAdded:   ${ENDCOLOR_ES}/")
    status_output=$(echo "$status_output" | sed "s/^??/${GREEN_ES}\tAdded:   ${ENDCOLOR_ES}/")
    echo -e "$status_output"
}


### Function prints the list of commits
# $1: number of last commits to show
# $2: what to add before commit line
#     * <empty> - nothing
#     * tab
#     * number
# $3: from which place (commit, branch) show commits (empty for default)
# Returns: 
#     commits_info
#     commits_hash
function commit_list {
    IFS=$'\n' 
    read -rd '' -a commits_info <<<"$(git --no-pager log -n $1 --pretty="${YELLOW_ES}%h${ENDCOLOR_ES} | %s | ${GREEN_ES}%cr${ENDCOLOR_ES}" $3 | column -ts'|')"
    read -rd '' -a commits_hash <<<"$(git --no-pager log -n $1 --pretty="%h"$3)"

    for index in "${!commits_info[@]}"
    do
        line=${commits_info[index]}
        if [ $2 == "number" ]; then
            line="$(($index+1)). ${line}"
        elif [ $2 == "tab" ]; then
            line="\t${line}"
        fi
        echo -e "$line"
    done
}


### Function prints the list of refs from reflog
# $1: number of last refs to show
# Returns: 
#     refs_info
#     refs_hash
function ref_list {
    IFS=$'\n' 
    read -rd '' -a refs_info <<<"$(git --no-pager reflog -n $1 --pretty="${YELLOW_ES}%h${ENDCOLOR_ES} | ${BLUE_ES}%gd${ENDCOLOR_ES} | %gs | ${GREEN_ES}%cr${ENDCOLOR_ES}" | column -ts'|')"
    read -rd '' -a refs_hash <<<"$(git --no-pager reflog -n $1 --pretty="%gd")"

    # Remove HEAD@{0}
    refs_info=("${refs_info[@]:1}")
    refs_hash=("${refs_hash[@]:1}")

    for index in "${!refs_info[@]}"
    do
        line="$(($index+1)). ${refs_info[index]}"
        echo -e "$line"
    done
}


### Function prints the list of commits and user should choose one
# $1: number of last commits to show
# Returns: 
#     commit_hash - hash of selected commit
# Using of global:
#     * git_add
function choose_commit {
    commit_list $1 "number"
    echo "0. Exit..."
    # TODO: add navigation

    echo
    printf "Enter commit number: "

    choose "${commits_hash[@]}"
    commit_hash=$choice_result

    echo
}


### Function prints provided stat in a nice format with colors
# $1: stats after pull or commit like 'README.md | 1 +\n1 file changed, 1 insertion(+)'
function print_changes_stat {
    IFS=$'\n' read -rd '' -a stats <<< "$1"
    result_stat=""
    bottom_line=""
    number_of_stats=${#stats[@]}
    for index in "${!stats[@]}"
    do
        s=$(echo ${stats[index]} | sed -e 's/^[[:space:]]*//')
        s=$(sed "s/+/${GREEN_ES}+${ENDCOLOR_ES}/g" <<< ${s})
        s=$(sed "s/-/${RED_ES}-${ENDCOLOR_ES}/g" <<< ${s})
        if [ $(($index+1)) == $number_of_stats ]; then
            #s=$(sed '1 s/,/|/' <<< ${s})
            bottom_line="${s}"
            break
        fi
        result_stat="${result_stat}\n${s}"
    done
    echo -e "$(echo -e "${result_stat}" | column -ts'|')"
    echo -e "$bottom_line"
}


### Function sets to variables push_list and history_from actual push log information
# $1: current branch
# $2: main branch
# $3: origin name
# Returns: 
#     push_list - unpushed commits
#     history_from - branch or commit from which history was calculated
function get_push_list {
    push_list_check=$(git --no-pager log $3/$1..HEAD 2>&1)
    if [[ $push_list_check != *"unknown revision or path not in the working tree"* ]]; then
        push_list=$(commit_list 999 "tab" $3/$1..HEAD)
        history_from="$3/$1"
        return
    fi

    # Case with new repo without any branch
    if [[ $push_list_check == *"unknown revision or path not in the working tree"* ]]; then
        if [[ $1 == $2 ]]; then
            push_list=$(commit_list 999 "tab")
            history_from="$3/$1"
            return
        fi
    fi
    
    base_commit=$(diff -u <(git rev-list --first-parent $1) <(git rev-list --first-parent $2) | sed -ne 's/^ //p' | head -1)
    if [ -n "$base_commit" ]; then
        push_list=$(commit_list 999 "tab" $base_commit..HEAD)
        history_from="${base_commit::7}"
    else
        push_list=$(commit_list 999 "tab" $3/$2..HEAD)
        history_from="$3/$2"
    fi
}


### Function prints list of branches
# $1: possible values:
#     * no value prints all local branches
#     * 'remote' - all remote
#     * 'delete' - all local without main and current
#     * 'merge' - all local without current
# Using of global:
#     * current_branch
#     * main_branch
# Returns:
#     * number_of_branches
#     * branches_first_main
function list_branches {
    args="--sort=-committerdate"
    if [[ "$1" == "remote" ]]; then
        args="--sort=-committerdate -r"
    fi
    branches_str=$(git --no-pager branch $args --format="%(refname:short)")
    branches_with_info_str=$(git --no-pager branch $args --format="%(refname:short) | %(committerdate:relative) | %(objectname:short) - %(contents:subject)" | column -ts'|' )
    commits_hash_str=$(git --no-pager branch $args --format="%(objectname:short)")

    IFS=$'\n' read -rd '' -a branches <<< "$branches_str"
    IFS=$'\n' read -rd '' -a branches_with_info <<< "$branches_with_info_str"
    IFS=$'\n' read -rd '' -a commits_hash <<< "$commits_hash_str"

    number_of_branches=${#branches[@]}
    if [[ "$1" == "remote" ]]; then
        # There is origin/HEAD
        ((number_of_branches=number_of_branches-1))
    fi

    if [[ "$number_of_branches" == 0 ]]; then
        echo
        echo -e "${YELLOW}There is no branches${ENDCOLOR}"
        exit
    fi

    branch_to_check="${branches[0]}"
    if [[ "$1" == "remote" ]]; then
        # Remove 'origin/'
        branch_to_check="${branches[1]}"
        branch_to_check="$(sed "s/${origin_name}\///g" <<< ${branch_to_check})"
    fi

    if [[ "$number_of_branches" == 1 ]] && [[ "${branch_to_check}" == "${current_branch}" ]]; then
        echo
        echo -e "You have only one branch: ${YELLOW}${current_branch}${ENDCOLOR}"
        exit
    fi

    if [[ "$1" == "delete" ]] && [[ "$number_of_branches" == 2 ]] && [[ "${current_branch}" != "${main_branch}" ]]; then
        echo
        echo -e "${YELLOW}There is no branches to delete${ENDCOLOR}"
        exit
    fi

    ### Main should be the first
    branches_first_main=(${main_branch})
    branches_with_info_first_main=("dummy")
    commits_hash_first_main=("dummy")
    if [[ "$1" == "delete" ]]; then
        branches_first_main=()
        branches_with_info_first_main=()
        commits_hash_first_main=()
    fi
    if [[ "$1" == "merge" ]] && [[ "$current_branch" == "$main_branch" ]]; then
        branches_first_main=()
        branches_with_info_first_main=()
        commits_hash_first_main=()
    fi
    for index in "${!branches[@]}"
    do
        branch_to_check="${branches[index]}"
        if [[ "$1" == "delete" ]]; then
            if [[ "$branch_to_check" == "${current_branch}"* ]] || [[ "$branch_to_check" == "${main_branch}"* ]]; then
                continue    
            fi
        fi
        if [[ "$1" == "merge" ]]; then
            if [[ "$branch_to_check" == "${current_branch}"* ]]; then
                continue
            fi
        fi
        if [[ "$1" == "remote" ]]; then
            branch_to_check="$(sed "s/${origin_name}\///g" <<< ${branch_to_check})"
        fi

        if [[ "$branch_to_check" == "${main_branch}"* ]]; then
            branches_with_info_first_main[0]="${branches_with_info[index]}"
            commits_hash_first_main[0]="${commits_hash[index]}"
        elif [[ "$branch_to_check" != "HEAD->"* ]] && [[ "$branch_to_check" != "$origin_name" ]]; then 
            branches_first_main+=(${branches[index]})
            branches_with_info_first_main+=("${branches_with_info[index]}")
            commits_hash_first_main+=("${commits_hash[index]}")
        fi
    done

    for index in "${!branches_with_info_first_main[@]}"
    do
        branch=$(escape "${branches_first_main[index]}" "/")
        if [[ "$1" == "remote" ]] && [[ "$branch" != "origin"* ]]; then
            branch="$origin_name\/$branch"
        fi
        branch_line=$(sed "1,/${branch}/ s/${branch}/${GREEN_ES}${branch}${ENDCOLOR_ES}/" <<< ${branches_with_info_first_main[index]})
        branch_line=$(sed "1,/${commits_hash_first_main[index]}/ s/${commits_hash_first_main[index]}/${BLUE_ES}${commits_hash_first_main[index]}${ENDCOLOR_ES}/" <<< ${branch_line})
        if [ "${branches_first_main[index]}" == "$current_branch" ]; then
            echo "$(($index+1)). * $branch_line"
        else
            echo "$(($index+1)).   $branch_line"
        fi
    done
}


### This function prints the list of branches and user should choose one
# $1: possible values:
#     * no value prints all local branches
#     * 'remote' - choose from all remote
#     * 'delete' - choose from all local without main and current
#     * 'merge' - all local without current
# Using of global:
#     * origin_name
#     * current_branch
#     * main_branch
# Returns:
#     * branch_name
function choose_branch {
    list_branches $1
    printf "0. Exit...\n"

    echo
    printf "Enter branch number: "

    choose "${branches_first_main[@]}"
    branch_name=$choice_result

    if [[ "$1" == "remote" ]]; then
        branch_name=$(sed "s/${origin_name}\///g" <<< ${branch_name})
    fi

    echo
}


### Function handles switch result
# $1: name of the branch to switch
# $2: pass it if you want to disable push log and moved changes
function switch {
    switch_output=$(git switch $1 2>&1)
    switch_code=$?

    ## Switch is OK
    if [ "$switch_code" == 0 ]; then
        if [ "$current_branch" == "$1" ]; then
            echo -e "${GREEN}Already on '$1'${ENDCOLOR}"
        else
            echo -e "${GREEN}Switched to branch '$1'${ENDCOLOR}"
            changes=$(git status -s)
            if [ -n "$changes" ] && [ -z $2 ]; then
                echo
                echo -e "${YELLOW}Moved changes:${ENDCOLOR}"
                git status -s
            fi
        fi

        if [ -z $2 ]; then
            get_push_list $1 ${main_branch} ${origin_name}
            if [ -n "$push_list" ]; then
                echo
                echo -e "Your branch ${YELLOW}$1${ENDCOLOR} is ahead of ${YELLOW}${history_from}${ENDCOLOR} by this commits:"
                echo -e "$push_list"
            fi
        fi
        return
    fi

    ## There are uncommited files with conflicts
    if [[ $switch_output == *"Your local changes to the following files would be overwritten"* ]]; then
        conflicts="$(echo "$switch_output" | tail -r | tail -n +3 | tail -r | tail -n +2)"
        echo -e "${RED}Changes would be overwritten by switch to '$1':${ENDCOLOR}"       
        echo -e "${conflicts//[[:blank:]]/}"
        echo
        echo -e "${YELLOW}Commit these files and try to switch for one more time${ENDCOLOR}"
        exit
    fi

    if [ $switch_code -ne 0 ]; then
        echo -e "${RED}Cannot switch to '$main_branch'! Error message:${ENDCOLOR}"
        echo -e "$switch_output"
        exit $switch_code
    fi
}

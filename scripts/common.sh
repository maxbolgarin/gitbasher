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


### Useful consts
current_branch=$(git branch --show-current)


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
    commits_author_str=$(git log --pretty="%an" -n $1)
    commits_date_str=$(git log --pretty="%cr" -n $1)
    IFS=$'\n' read -rd '' -a commits_info <<<"$commits_info_str"
    IFS=$'\n' read -rd '' -a commits_hash <<<"$commits_hash_str"
    IFS=$'\n' read -rd '' -a commits_author <<<"$commits_author_str"
    IFS=$'\n' read -rd '' -a commits_date <<<"$commits_date_str"

    number_of_commits=${#commits_info[@]}

    for index in "${!commits_info[@]}"
    do
        commit_line=$(sed "1,/${commits_hash[index]}/ s/${commits_hash[index]}/${YELLOW_ES}${commits_hash[index]}${ENDCOLOR_ES}/" <<< ${commits_info[index]})
        commit_line=$(sed "s/\(.*\)${commits_author[index]}/\1${BLUE_ES}${commits_author[index]}${ENDCOLOR_ES}/" <<< "${commit_line}")
        commit_line=$(sed "s/\(.*\)${commits_date[index]}/\1${GREEN_ES}${commits_date[index]}${ENDCOLOR_ES}/" <<< "${commit_line}")
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


### Function prints provided stat in nice format with colors
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
    args="--list --sort=-committerdate"
    if [[ "$1" == "remote" ]]; then
        args="--list --sort=-committerdate -r"
    fi
    all_branches=$(git branch $args | cat 2>&1)
    all_branches_wih_commits=$(git branch -v $args  | cat 2>&1)

    all_branches="${all_branches//\*}"
    all_branches=${all_branches//[[:blank:]]/}

    IFS=$'\n' read -rd '' -a branches <<<"$all_branches"

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

    IFS=$'\n' read -rd '' -a branches_with_commits <<<"$all_branches_wih_commits"

    branches_first_main=(${main_branch})
    branches_with_commits_first_main=("dummy")
    if [[ "$1" == "delete" ]]; then
        branches_first_main=()
        branches_with_commits_first_main=()
    fi
    if [[ "$1" == "merge" ]] && [[ "$current_branch" == "$main_branch" ]]; then
        branches_first_main=()
        branches_with_commits_first_main=()
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
        if [[ "$branch_to_check" != "${main_branch}"* ]]; then
            branches_first_main+=(${branches[index]})
            branches_with_commits_first_main+=("${branches_with_commits[index]}")
        elif [[ "$branch_to_check" != "HEAD->"* ]]; then 
            branches_with_commits_first_main[0]="${branches_with_commits[index]}"
        fi
    done

    for index in "${!branches_with_commits_first_main[@]}"
    do
        echo "$(($index+1)). ${branches_with_commits_first_main[index]}"
    done
}


### This function prints the list of branches and user should choose one
# $1: possible values:
#     * no value prints all local branches
#     * 'remote' - choose from all remote
#     * 'delete' - choose from all local without main and current
# Using of global:
#     * origin_name
# Returns:
#     * branch_name
function choose_branch {
    list_branches $1
    printf "0. Exit...\n"

    echo
    printf "Enter branch number: "

    while [ true ]; do
        if [ $number_of_branches -gt 9 ]; then
            read -n 2 choice
        else
            read -n 1 -s choice
        fi

        if [ "$choice" == "0" ] || [ "$choice" == "00" ]; then
            printf $choice
            exit
        fi

        re='^[0-9]+$'
        if ! [[ $choice =~ $re ]]; then
           continue
        fi

        index=$(($choice-1))
        branch_name="${branches_first_main[index]}"
        if [ -n "$branch_name" ]; then
            printf $choice
            break
        fi
    done

    if [[ "$1" == "remote" ]]; then
        branch_name=$(sed "s/${origin_name}\///g" <<< ${branch_name})
    fi

    echo
}


### Function fetchs provided branch and handles errors
# $1: branch name
# $2: origin name
# $3: editor
# Returns:
#      * fetch_code - if it is not zero - there is no such branch in origin
function fetch {
    fetch_output=$(git fetch $2 $1 2>&1)
    fetch_code=$?

    if [ $fetch_code == 0 ] ; then
        return
    fi

    if [[ ${fetch_output} != *"couldn't find remote ref"* ]]; then
        echo -e "${RED}Cannot fetch '$1'! Here is the error!${ENDCOLOR}"
        echo -e "${fetch_output}"
        exit $fetch_code
    fi
    echo -e "${YELLOW}There is no '$1' in $2${ENDCOLOR}"
}


### Function merges provided branch and handles errors
# $1: branch name from
# $2: origin name
# $3: editor
# $4: operation name (e.g. merge or pull)
# Returns:
#      * merge_output
#      * merge_code - 0 if everything is ok, not zero if there are conflicts
function merge {
    merge_output=$(git merge ${merge_branch} 2>&1)
    merge_code=$?

    if [ $merge_code == 0 ] ; then
        return
    fi

    operation="$4"
    if [ "$operation" == "" ]; then
        operation="merge"
    fi

    ### Cannot merge because there is uncommitted files that changed in origin
    if [[ $merge_output == *"Please commit your changes or stash them before you merge"* ]]; then
        echo -e "${RED}Cannot $operation! There is uncommited changes, that will be overwritten by $operation${ENDCOLOR}"
        files_to_commit=$(echo "$merge_output" | tail -n +2 | tail -r | tail -n +4 | tail -r)
        echo -e "${YELLOW}Files with changes${ENDCOLOR}"
        echo "$files_to_commit"
        echo
        exit $merge_code
    fi

    ### Cannot merge because of some other error
    if [[ $merge_output != *"fix conflicts and then commit the result"* ]]; then
        echo -e "${RED}Cannot $operation! Here is the error${ENDCOLOR}"
        echo "$merge_output"
        exit $merge_code
    fi

    echo -e "${RED}Cannot $operation! There are conflicts in staged files${ENDCOLOR}"
    resolve_conflicts $1 $2 $3
}


### Function pulls provided branch, handles errors and makes a merge
# $1: branch name
# $2: origin name
# $3: editor
function resolve_conflicts {

    ### Print files with conflicts
    echo -e "${YELLOW}Files with conflicts${ENDCOLOR}"
    IFS=$'\n' read -rd '' -a files_with_conflicts <<<"$(git --no-pager diff --name-only --diff-filter=U --relative)"
    echo -e "$(sed 's/^/\t/' <<< "$files_with_conflicts")"
    echo


    ### Ask user what he wants to do
    default_message="Merge branch '$2/$1' into '$1'"
    echo -e "${YELLOW}You should fix conflicts manually.${ENDCOLOR} There are some options:"
    echo -e "1. Create merge commit with generated message"
    printf "\tMessage: ${BLUE}${default_message}${ENDCOLOR}\n"
    echo -e "2. Create merge commit with entered message"
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
            merge_commit $choice $files_with_conflicts "${default_message}" $1 $2 $3
            if [ -z "$merge_commit_code" ] || [ $merge_commit_code == 0 ]; then
                return
            fi
        fi

        if [ "$choice" == "3" ]; then
            echo
            echo -e "${YELLOW}Cancel merge${ENDCOLOR}"
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
# Returns: 
#     merge_commit_code - 0 if everything is ok
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
        merge_commit_code=1
        return
    fi


    ### Add files with resolved conflicts to commit
    files_with_conflicts_one_line="$(tr '\n' ' ' <<< "$2")"
    git add $files_with_conflicts_one_line

    ### 1. Commit with default message
    if [ "$1" == "1" ]; then
        result=$(git commit -m "$3" 2>&1)
        check_code $? "$result" "merge commit"
        commit_message="$3"

    ### 2. Commit with entered message
    else
        staged_with_tab="$(sed 's/^/###\t/' <<< "$2")"
        commitmsg_file=".commitmsg__"
        touch $commitmsg_file
        echo """
###
### Write a message about merge from '$5/$4' into '$4'. Lines starting with '#' will be ignored. 
### 
### On branch $4
### Changes to be commited:
${staged_with_tab}
""" >> $commitmsg_file
        while [ true ]; do
            $6 $commitmsg_file
            commit_message=$(cat $commitmsg_file | sed '/^#/d')

            if [ -n "$commit_message" ]; then
                break
            fi
            echo -e "${YELLOW}Merge commit message cannot be empty${ENDCOLOR}"
            echo
            read -n 1 -p "Try for one more time? (y/n) " -s -e choice
            if [ "$choice" != "y" ]; then
                git restore --staged $files_with_conflicts_one_line
                find . -name "$commitmsg_file*" -delete
                merge_commit_code=2
                exit
            fi    
        done

        find . -name "$commitmsg_file*" -delete
        
        result=$(git commit -m """$commit_message""" 2>&1)
        check_code $? "$result" "merge commit"
    fi

    commit_hash="$(git --no-pager log --pretty="%h" -1)"
    echo -e "${GREEN}Successful merge!${ENDCOLOR}"
    echo -e "${BLUE}[$4 $commit_hash]${ENDCOLOR} $commit_message"
    echo
    merge_commit_code=0
}


### Function pulls provided branch and handles errors
# $1: branch name
# $2: origin name
# $3: editor
function pull {
    ### Fetch, it will exit if critical error and return if branch doesn't exists in origin
    fetch $1 $2

    if [ $fetch_code != 0 ] ; then
        return
    fi

    ### Merge and resulve conflicts
    merge $1 $2 $3 "pull"

    ### Nothing to pull
    if [[ $merge_output == *"Already up to date"* ]]; then
        echo -e "${GREEN}Already up to date${ENDCOLOR}"
        return
    fi

    ### It will exit if critical error or resolve conflicts, so here we can get only in case of success
    echo -e "${GREEN}Successful pull!${ENDCOLOR}"
    echo

    ### Merge without conflicts
    if [ $merge_code == 0 ] ; then
        print_changes_stat "$(echo "$merge_output" | tail -n +3)" 

    ### Merge with conflicts, but they were resolved
    else
        commit_hash="$(git --no-pager log --pretty="%h" -1)"
        print_changes_stat "$(git --no-pager show $commit_hash --stat --format="")" 
    fi
}

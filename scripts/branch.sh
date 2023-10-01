#!/usr/bin/env bash

### Script for working with branches: create, switch, remove
# Use a separate branch for writing new code, then merge it to main
# Read README.md to get more information how to use it
# Use this script only with gitbasher.sh

### Options
# no options: switch to local branch
# r: switch to remote branch
# n: create a new branch
# c: create a new branch from a current one instead of the main branch
# d: delete a local branch
# s: separator between type and name (default '/')
# b: name of main branch (default 'main')
# o: name of remote (default 'origin')
# u: path to utils.sh (mandatory)


while getopts ncrds:b:o:u: flag; do
    case "${flag}" in
        n) new="true";;
        c) current="true";;
        r) remote="true";;
        d) delete="true";;
        s) sep=${OPTARG};;

        b) main_branch=${OPTARG};;
        o) origin_name=${OPTARG};;
        u) utils=${OPTARG};;
    esac
done

if [ -z "$main_branch" ]; then
    main_branch="main"
fi

if [ -z "$origin_name" ]; then
    origin_name="origin"
fi

if [ -z "$sep" ]; then
    sep="/"
fi

source $utils


current_branch=$(git branch --show-current)

### Function prints list of branches
# $1: possible values:
#     * no value prints all local branches
#     * 'remote' - all remote
#     * 'no-main' - all local without main
#     * 'no-merged' - not merged local
function list_branches {
    args="--list --sort=-committerdate"
    if [[ "$1" == "remote" ]]; then
        args="--list --sort=-committerdate -r"
    fi
    all_branches=$(git branch $args | cat 2>&1)
    all_branches_wih_commits=$(git branch -v $args  | cat 2>&1)

    all_branches="${all_branches//\*}"
    all_branches=${all_branches//[[:blank:]]/}

    IFS=$'\n' read -rd '' -a branches_temp <<<"$all_branches"
    reverse branches_temp branches

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

    IFS=$'\n' read -rd '' -a branches_with_commits_temp <<<"$all_branches_wih_commits"
    reverse branches_with_commits_temp branches_with_commits

    branches_first_main=(${main_branch})
    branches_with_commits_first_main=("dummy")
    for index in "${!branches[@]}"
    do
        branch_to_check="$(echo "${branches[index]//\*}" | xargs)"
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

branch_name=""

### This function prints the list of branches and user should choose one
# $1: pass 'remote' if you want to select from remote branches, 'delete' if you want to select for delete
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


### Function handles switch result
# $1: name of the branch to switch
function switch {
    echo

    switch_output=$(git switch $1 2>&1)
    switch_code=$?

    ## Switch is OK
    if [ "$switch_code" == 0 ]; then
        if [ "$current_branch" == "${branch_name}" ]; then
            echo -e "${GREEN}Already on '${branch_name}'${ENDCOLOR}"
        else
            echo -e "${GREEN}Switched to branch '${branch_name}'${ENDCOLOR}"
            changes=$(git status -s)
            if [ -n "$changes" ]; then
                echo
                echo -e "${YELLOW}Moved changes:${ENDCOLOR}"
                git status -s
            fi
        fi

        get_push_log ${branch_name} ${main_branch} ${origin_name}
        if [ -n "$push_log" ]; then
            echo
            echo -e "Your branch ${YELLOW}${branch_name}${ENDCOLOR} is ahead of ${YELLOW}${history_from}${ENDCOLOR} by this commits:"
            echo -e $push_log
        fi
        exit
    fi

    ## There are uncommited files with conflicts
    if [[ $switch_output == *"Your local changes to the following files would be overwritten"* ]]; then
        conflicts="$(echo "$switch_output" | tail -r | tail -n +3 | tail -r | tail -n +2)"
        echo -e "${RED}Changes would be overwritten by switch to '${branch_name}':${ENDCOLOR}"       
        echo -e "${conflicts//[[:blank:]]/}"
        echo
        echo -e "${YELLOW}Commit these files and try to switch for one more time${ENDCOLOR}"
        exit $switch_code
    fi

    exit
}


###
### Script logic below
###

### Print header
if [ -n "${new}" ]; then
    echo -e "${YELLOW}BRANCH MANAGER${ENDCOLOR} NEW"
elif [ -n "${remote}" ]; then
    echo -e "${YELLOW}BRANCH MANAGER${ENDCOLOR} REMOTE"
elif [ -n "${delete}" ]; then
    echo -e "${YELLOW}BRANCH MANAGER${ENDCOLOR} DELETE"
else
    echo -e "${YELLOW}BRANCH MANAGER${ENDCOLOR}"
fi
echo


### Run switch to local logic
if [[ -z "$new" ]] && [[ -z "$remote" ]] && [[ -z "$delete" ]]; then
    echo -e "${YELLOW}Switch from '${current_branch}' to local branch${ENDCOLOR}"

    choose_branch

    switch ${branch_name}

### Run switch to remote logic
elif [[ -z "$new" ]] && [[ -n "$remote" ]] && [[ -z "$delete" ]]; then
    echo -e "${YELLOW}Fetching remote...${ENDCOLOR}"
    echo

    fetch_output=$(git fetch 2>&1)
    fetch_code=$?
    if [ $fetch_code -ne 0 ] ; then
        echo -e "${RED}Cannot fetch remote!${ENDCOLOR}"
        echo -e "${fetch_output}"
        exit $fetch_code
    fi

    echo -e "${YELLOW}Switch from '${current_branch}' to remote branch${ENDCOLOR}"
    
    choose_branch "remote"

    switch ${branch_name}

elif [[ -z "$new" ]] && [[ -n "$delete" ]]; then
    merged_branches_str=$(git branch -v --sort=-committerdate --merged | cat 2>&1)
    #merged_branches_str="${merged_branches_str//\*}"

    IFS=$'\n' read -rd '' -a merged_branches <<<"$merged_branches_str"

    merged_branches_without_main=()
    for index in "${!merged_branches[@]}"
    do
        branch_with_info="$(echo "${merged_branches[index]}" | xargs)"
        if [[ ${branch_with_info} != "${main_branch}"* ]] && [[ ${branch_with_info} != "*"* ]] ; then
            merged_branches_without_main+=("$branch_with_info")
        fi
    done
    number_of_branches=${#merged_branches_without_main[@]}

    if [ $number_of_branches != 0 ]; then
        echo -e "${YELLOW}Do you want to delete merged local branches?${ENDCOLOR}"
        echo -e "These are branches without new changes regarding ${main_branch}"
        for index in "${!merged_branches_without_main[@]}"
        do
            printf "\t${merged_branches_without_main[index]}\n"
        done

        printf "\nAnswer (y/n): "
        
        while [ true ]; do
            read -n 1 -s choice
            if [ "$choice" == "y" ]; then
                printf "y\n\n"
                git branch --merged | egrep -v "(^\*|master|main|develop|${main_branch})" | xargs git branch -d
                break

            elif [ "$choice" == "n" ]; then
                printf "n\n\n"
                break
            fi
        done
    fi

    #choose_branch "delete"

    echo -e "${branch_name}"

    #switch ${branch_name}

   
    exit
fi


### Run create new branch logic
### Step 1. Choose branch type
echo -e "${YELLOW}Step 1.${ENDCOLOR} What type of branch do you want to create?"
echo "1. feat:      new feature or logic changes, 'feat' and 'perf' commits"
echo "2. fix:       small changes, eg. bug fix, including hotfixes"
echo "3. other:     non important changes in code, e.g. 'refactor', 'test'"
echo "4. misc:      non-code changes, e.g. 'ci', 'docs', 'build'"
echo "0. EXIT without changes"

declare -A types=(
    [1]="feat"
    [2]="fix"
    [3]="other"
    [4]="misc"
)

branch_type=""
while [ true ]; do
    read -n 1 -s choice

    if [ "$choice" == "0" ]; then
        exit
    fi

    branch_type="${types[$choice]}"
    if [ -n "$branch_type" ]; then
        break
    fi
done


### Step 2. Enter branch name
echo
echo -e "${YELLOW}Step 2.${ENDCOLOR} Enter the name of the branch, using '-' as a separator between words"
echo "Leave it blank if you want to exit"

read -p "Branch: ${branch_type}${sep}" -e branch_name

if [ -z $branch_name ]; then
    exit
fi

branch_name="${branch_type}${sep}${branch_name##*( )}"


### Step 3. Switch to main, pull it and then create a new branch from main
if [ -z "${current}" ]; then
    switch_output=$(git switch $main_branch 2>&1)
    switch_code=$?

    if [ $switch_code -ne 0 ]; then
        echo -e "${RED}Cannot switch to '$main_branch': $switch_output${ENDCOLOR}"
        exit $switch_code
    fi

    echo
    echo -e "${GREEN}Switched to '$main_branch'${ENDCOLOR}"
    echo -e "${YELLOW}Pulling...${ENDCOLOR}"
    
    pull_output=$(git pull ${origin_name} ${main_branch} --no-rebase 2>&1)
    pull_code=$?

    echo

    # Handle pull errors, don't use single function with push beacause there is different output
    if [ $pull_code -ne 0 ] ; then
        if [[ $pull_output == *"Please commit your changes or stash them before you merge"* ]]; then
            echo -e "${RED}Cannot pull! There is uncommited changes, that will be overwritten by merge${ENDCOLOR}"
            files_to_commit=$(echo "$pull_output" | tail -n +4 | head -n +1)
            echo -e "${YELLOW}Files:${ENDCOLOR}"
            echo "$files_to_commit"
            echo
            echo -e "Commit changes and then use ${YELLOW}make branch-new${ENDCOLOR} again"
            exit $pull_code
        fi

        if [[ $pull_output == *"fix conflicts and then commit the result"* ]]; then
            echo -e "${RED}Cannot pull! You should fix conflicts${ENDCOLOR}"
            files_with_conflicts=$(git diff --name-only --diff-filter=U --relative | cat)
            echo -e "${YELLOW}Files:${ENDCOLOR}"
            echo "$files_with_conflicts"
            echo
            echo -e "Fix conflicts and commit result, then use ${YELLOW}make branch-new${ENDCOLOR} again"
            echo
            echo -e "Press ${YELLOW}n${ENDCOLOR} if you want to abort merge or any key to exit"
            read -n 1 -s choice
            if [ "$choice" == "n" ]; then
                echo -e "${YELLOW}Aborting merge...${ENDCOLOR}"
                git merge --abort
            fi
            exit $pull_code
        fi

        echo -e "${RED}Cannot pull '$main_branch', here is the error${ENDCOLOR}\n$pull_output"
        echo
        echo -e "Pull ${YELLOW}$main_branch${ENDCOLOR} firstly and then use ${YELLOW}make branch-new${ENDCOLOR} again"
        exit $pull_code
    fi

    echo -e "${GREEN}Successful pull!${ENDCOLOR}"
fi


### Step 4. Create a new branch and switch to it
switch_output=$(git switch -c $branch_name 2>&1)
switch_code=$?

echo

if [ $switch_code -eq 0 ]; then
    echo -e "${GREEN}${switch_output}${ENDCOLOR}"
    changes=$(git status -s)
    if [ -n "$changes" ]; then
        echo
        echo -e "${YELLOW}Moved changes:${ENDCOLOR}"
        git status -s
    fi
    exit
fi

if [[ $switch_output == *"already exists"* ]]; then
    echo -e "${RED}Branch with name '${branch_name}' already exists${ENDCOLOR}"
    exit $switch_code
fi

echo -e "${RED}Switch error: ${switch_output}${ENDCOLOR}"
exit $switch_code

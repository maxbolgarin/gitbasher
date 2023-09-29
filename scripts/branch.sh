#!/usr/bin/env bash

### Script for working with branches: create, checkout, remove
# Use a separate branch for writing new code, then merge it to main
# Read README.md to get more information how to use it
# Use this script only with gitbasher.sh

### Options
# n: create a new branch
# c: create a new branch from a current one instead of the main branch
# s: separator between type and name (default '/')
# b: name of main branch (default 'main')
# u: path to utils.sh (mandatory)


while getopts ncs:b:u: flag; do
    case "${flag}" in
        n) new="true";;
        c) current="true";;
        s) sep=${OPTARG};;

        b) main_branch=${OPTARG};;
        u) utils=${OPTARG};;
    esac
done

if [ -z "$main_branch" ]; then
    main_branch="main"
fi

if [ -z "$sep" ]; then
    sep="/"
fi

source $utils


branch_name=""
current_branch=$(git branch --show-current)

### This function prints the list of branches and user should choose one
function choose_branch {
    all_branches=$(git branch --list | cat 2>&1)
    all_branches="${all_branches//\*}"
    all_branches=${all_branches//[[:blank:]]/}

    IFS=$'\n' read -rd '' -a branches_temp <<<"$all_branches"
    reverse branches_temp branches

    number_of_branches=${#branches[@]}

    if [[ "$number_of_branches" == 1 ]] && [[ "${branches[0]}" == "${current_branch}" ]]; then
        echo
        echo -e "You have only a single branch: ${YELLOW}${current_branch}${ENDCOLOR}"
        exit
    fi

    for index in "${!branches[@]}"
    do
        echo "$(($index+1)). ${branches[index]}"
    done
    echo "0. Exit..."

    echo
    printf "Enter branch number: "

    while [ true ]; do
        if [ $number_of_branches -gt 9 ]; then
            read -n 2 choice
        else
            read -n 1 choice
        fi

        if [ "$choice" == "0" ] || [ "$choice" == "00" ]; then
            exit
        fi

        re='^[0-9]+$'
        if ! [[ $choice =~ $re ]]; then
           continue
        fi

        index=$(($choice-1))
        branch_name="${branches[index]}"
        if [ -n "$branch_name" ]; then
            break
        fi
    done
    echo
}


###
### Script logic below
###

### Print header
echo -e "${YELLOW}BRANCH MANAGER${ENDCOLOR}"
echo


### Run checkout logic
if [ -z "$new" ]; then
    echo -e "${YELLOW}Checkout from '${current_branch}' to local branch${ENDCOLOR}"

    choose_branch

    echo

    checkout_output=$(git checkout $branch_name 2>&1)
    checkout_code=$?

    echo $checkout_output
    echo $checkout_code

    ## Checkout is OK
    if [ "$checkout_code" == 0 ]; then
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

        get_push_log ${branch_name} ${main_branch}
        if [ -n "$push_log" ]; then
            echo
            echo -e "Your branch ${YELLOW}${branch_name}${ENDCOLOR} is ahead of ${YELLOW}${history_from}${ENDCOLOR} by this commits:"
            echo -e $push_log
        fi
        exit
    fi

    ## There are uncommited files with conflicts
    if [[ $checkout_output == *"Your local changes to the following files would be overwritten by checkout"* ]]; then
        conflicts="$(echo "$checkout_output" | tail -r | tail -n +3 | tail -r | tail -n +2)"
        echo -e "${RED}Changes would be overwritten by checkout to '${branch_name}':${ENDCOLOR}"       
        echo -e "${conflicts//[[:blank:]]/}"
        echo
        echo -e "${YELLOW}Commit these files and try to checkout for one more time${ENDCOLOR}"
        exit
    fi

    exit
fi


### Run create new branch logic
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

echo
echo -e "${YELLOW}Step 2.${ENDCOLOR} Enter the name of the branch, using '-' as a separator between words"
echo "Leave it blank if you want to exit"

read -p "Branch: ${branch_type}${sep}" -e branch_name

if [ -z $branch_name ]; then
    exit
fi

branch_name="${branch_type}${sep}${branch_name##*( )}"

if [ -z "${current}" ]; then
    checkout_output=$(git checkout $main_branch 2>&1)
    checkout_code=$?

    if [ $checkout_code -ne 0 ]; then
        echo -e "${RED}Cannot checkout to '$main_branch': $checkout_output${ENDCOLOR}"
        exit $checkout_code
    fi

    echo
    echo -e "${GREEN}Switched to '$main_branch'${ENDCOLOR}"
    echo -e "${YELLOW}Pulling...${ENDCOLOR}"
    
    pull_output=$(git pull origin ${main_branch} --no-rebase 2>&1)
    pull_code=$?

    echo
    if [ $pull_code -ne 0 ] ; then
        if [[ $pull_output == *"Please commit your changes or stash them before you merge"* ]]; then
            echo -e "${RED}Cannot pull! There is uncommited changes, that will be overwritten by merge${ENDCOLOR}"
            files_to_commit=$(echo "$pull_output" | tail -n +4 | head -n +1)
            echo -e "${YELLOW}Files:${ENDCOLOR}"
            echo "$files_to_commit"
            echo
            echo -e "Commit checnges and then use ${YELLOW}make branch-new${ENDCOLOR} again"
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

checkout_output=$(git checkout -b $branch_name 2>&1)
checkout_code=$?

echo

if [ $checkout_code -eq 0 ]; then
    echo -e "${GREEN}${checkout_output}${ENDCOLOR}"
    exit
fi

if [[ $checkout_output == *"already exists"* ]]; then
    echo -e "${RED}Branch with name '${branch_name}' already exists${ENDCOLOR}"
    exit $checkout_code
fi

echo -e "${RED}Checkout error: ${checkout_output}${ENDCOLOR}"
exit $checkout_code

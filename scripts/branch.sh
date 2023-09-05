#!/usr/bin/env bash

### Script for creating branches for developing
# Use this script only with gitbasher.sh

### Options
# n: create a new branch
# c: create a new branch from a current one instead of the main branch
# s: separator between type and name (default '/')

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

source $utils

if [ -z "$sep" ]; then
    sep="/"
fi

### Script logic below

echo -e "${YELLOW}BRANCH MANAGER${ENDCOLOR} v1.0"
echo

if [ -z "$new" ]; then
    all_branches=$(git branch --list | cat 2>&1)
    all_branches="${all_branches//\*}"
    all_branches=${all_branches//[[:blank:]]/}

    IFS=$'\n' read -rd '' -a branches_temp <<<"$all_branches"
    reverse branches_temp branches

    echo -e "${YELLOW}Checkout to local branch${ENDCOLOR}"
    for index in "${!branches[@]}"
    do
        echo "$(($index+1)). ${branches[index]}"
    done
    echo "0. Exit..."

    number_of_branches=${#branches[@]}

    echo
    printf "Enter branch number: "

    while [ true ]; do
        if [ $number_of_branches -gt 9 ]; then
            read -n 2 choice
        else
            read -n 1 -s choice
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

    ## TODO: handle errors
    git checkout $branch_name
    exit $?
fi


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

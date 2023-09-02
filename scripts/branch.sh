#!/usr/bin/env bash

### Script for creating branches for developing

### Options
# s: separator between type and name (default '/')

while getopts s:b:u: flag; do
    case "${flag}" in
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
        git restore --staged $git_add
        exit
    fi

    commit_type="${types[$choice]}"
    if [ -n "$commit_type" ]; then
        break
    fi
done
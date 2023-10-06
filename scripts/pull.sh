#!/usr/bin/env bash

### Script for pulling commits from remote git repository and merging branches
# Read README.md to get more information how to use it
# Use this script only with gitbasher.sh

### Options
# empty: pull current branch
# m: merge selected branch to current one (ask to fetch before merge)
# a: merge main to current one (ask to fetch before merge, pass with -m)
# t: merge current branch to main (pass with -m)
# e: text editor to write commit message (default 'nano')
# b: name of main branch (default 'main')
# o: name of remote (default 'origin')
# u: path to common.sh (mandator, auto pass by gitbasher.sh)


while getopts mate:b:o:u: flag; do
    case "${flag}" in
        m) merge="true";;
        a) main="true";;
        t) to_main="true";;

        e) editor=${OPTARG};;
        b) main_branch=${OPTARG};;
        o) origin_name=${OPTARG};;
        u) utils=${OPTARG};;
    esac
done

if [ -z "$editor" ]; then
    editor="nano"
fi

if [ -z "$main_branch" ]; then
    main_branch="main"
fi

if [ -z "$origin_name" ]; then
    origin_name="origin"
fi

source $utils

###
### Script logic here
###

### Pull current branch and exit (empty flags mode)
if [ -z "$merge" ]; then
    echo
    echo -e "${YELLOW}Pulling '$origin_name/$current_branch'...${ENDCOLOR}"
    echo
    pull $current_branch $origin_name $editor
    exit
fi


### Merge mode - print header
header="PULL MANAGER"
if [ -n "${to_main}" ]; then
    header="$header TO MAIN"
fi

echo -e "${YELLOW}${header}${ENDCOLOR}"
echo


### Select branch which will be merged
if [ -n "$main" ]; then
    if [ "$current_branch" == "${main_branch}" ]; then
        echo -e "${YELLOW}Already on ${main_branch}${ENDCOLOR}"
        exit
    fi
    merge_branch=${main_branch}

elif [ -n "$to_main" ]; then
    if [ "$current_branch" == "${main_branch}" ]; then
        echo -e "${YELLOW}Already on ${main_branch}${ENDCOLOR}"
        exit
    fi
    merge_branch=${current_branch}

else
    echo -e "${YELLOW}Which branch merge into '${current_branch}'?${ENDCOLOR}"
    choose_branch "merge"
    merge_branch=${branch_name}
    echo
fi


### Fetch before merge
echo -e "Do you want to fetch ${YELLOW}${merge_branch}${ENDCOLOR} before merge (y/n)?"
read -n 1 -s choice
if [ "$choice" == "y" ]; then
    echo
    echo -e "${YELLOW}Fetching...${ENDCOLOR}"

    fetch $merge_branch $origin_name
fi
echo


### Run merge-to-main logic - switch to main and merge
if [ -n "$to_main" ]; then
    switch_output=$(git switch $main_branch 2>&1)
    switch_code=$?

    ### Switch is OK
    if [ "$switch_code" == 0 ]; then
        echo -e "${GREEN}Switched to '$main_branch'${ENDCOLOR}"
        changes=$(git status -s)
        if [ -n "$changes" ]; then
            echo
            echo -e "${YELLOW}Moved changes:${ENDCOLOR}"
            git status -s
        fi
        echo
    fi

    ### There are uncommited files with conflicts
    if [[ $switch_output == *"Your local changes to the following files would be overwritten"* ]]; then
        conflicts="$(echo "$switch_output" | tail -r | tail -n +3 | tail -r | tail -n +2)"
        echo -e "${RED}Changes would be overwritten by switch to '$main_branch':${ENDCOLOR}"       
        echo -e "${conflicts//[[:blank:]]/}"
        echo
        echo -e "${YELLOW}Commit these files and try to merge for one more time${ENDCOLOR}"
        exit
    fi
fi


### Run merge and handle conflicts
merge $merge_branch $origin_name $editor


### Nothing to merge
if [[ $merge_output == *"Already up to date"* ]]; then
    echo -e "${GREEN}Nothing to merge - already up to date${ENDCOLOR}"
    exit
fi


### If we get here - it is success
echo -e "${GREEN}Successful merge!${ENDCOLOR}"
echo -e "${BLUE}[${merge_branch}${ENDCOLOR} -> ${BLUE}${current_branch}]${ENDCOLOR}"
echo


### Merged without conflicts
if [ $merge_code == 0 ] ; then
    print_changes_stat "$(echo "$merge_output" | tail -n +3)" 

### Merged with conflicts, but they were resolved
else
    commit_hash="$(git --no-pager log --pretty="%h" -1)"
    print_changes_stat "$(git --no-pager show $commit_hash --stat --format="")" 
fi

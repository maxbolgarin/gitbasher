#!/usr/bin/env bash

### Script for pulling commits from remote git repository
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

### Pull current branch (empty flags mode)
if [ -z "$merge" ]; then
    echo
    echo -e "${YELLOW}Pulling '$origin_name/$current_branch'...${ENDCOLOR}"
    echo
    pull $current_branch $origin_name $editor
    exit
fi


### Print header
echo -e "${YELLOW}MERGE MANAGER${ENDCOLOR}"
echo


### Select branch which will be merged to current branch
if [ -n "$main" ]; then
    merge_branch=${main_branch}
else
    echo -e "${YELLOW}Which branch merge into '${current_branch}'?${ENDCOLOR}"
    choose_branch "delete"
    merge_branch=${branch_name}
fi


### Fetch before merge
echo
echo -e "Do you want to fetch ${YELLOW}${merge_branch}${ENDCOLOR} before merge (y/n)?"
read -n 1 -s choice
if [ "$choice" == "y" ]; then
    echo -e "${YELLOW}Fetching...${ENDCOLOR}"
    echo

    fetch_output=$(git fetch ${origin_name} ${merge_branch} 2>&1)
    fetch_code=$?

    if [ $fetch_code != 0 ] ; then
        echo -e "${RED}Error during fetching ${merge_branch}!${ENDCOLOR}"
        echo -e "${fetch_output}"
        exit $fetch_code
    fi
fi


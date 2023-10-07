#!/usr/bin/env bash

### Script for pushing commits to remote git repository
# It will pull current branch if there are unpulled changes
# Read README.md to get more information how to use it
# Use this script only with gitbasher.sh

### Options
# y: fast push (answer 'yes')
# l: print list of commits to push and exit
# e: text editor to write commit message (in case of merge, default 'nano')
# b: name of main branch (default 'main')
# o: name of remote (default 'origin')
# u: path to common.sh (mandatory, auto pass by gitbasher.sh)


while getopts yle:b:o:u: flag; do
    case "${flag}" in
        y) fast="true";;
        l) list="true";;

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


### Use this function to push changes to origin
### It will exit if everyrhing is ok or there is a critical error, return if there is unpulled changes
# Using of global:
#     * current_branch
#     * main_branch
#     * origin_name
# Returns:
#     * push_output
#     * push_code
function push {
    push_output=$(git push ${origin_name} ${current_branch} 2>&1)
    push_code=$?

    if [ $push_code -eq 0 ] ; then 
        echo -e "${GREEN}Successful push!${ENDCOLOR}"

        repo=$(get_repo $origin_name)
        echo -e "${YELLOW}Repo:${ENDCOLOR}\t${repo}"
        if [[ ${current_branch} != ${main_branch} ]]; then
            if [[ $repo == *"github"* ]]; then
                echo -e "${YELLOW}PR:${ENDCOLOR}\t${repo}/pull/new/${current_branch}"
            elif [[ $repo == *"gitlab"* ]]; then
                echo -e "${YELLOW}MR:${ENDCOLOR}\t${repo}/-/merge_requests/new?merge_request%5Bsource_branch%5D=${current_branch}"
            fi
        fi
        exit
    fi

    if [[ $push_output != *"[rejected]"* ]]; then
        echo -e "${RED}Cannot push! Here is the error${ENDCOLOR}"
        echo "$push_output"
        exit $push_code
    fi
}

###
### Script logic here
###

### Check if there are commits to push
get_push_list ${current_branch} ${main_branch} ${origin_name}

if [ "${history_from}" != "${origin_name}/${current_branch}" ]; then
    echo -e "Branch ${YELLOW}${current_branch}${ENDCOLOR} doesn't exist in ${origin_name}, so get commit diff from base commit"
fi

if [ -z "$push_list" ]; then
    echo
    echo -e "${GREEN}Nothing to push${ENDCOLOR}"
    exit
fi


### Print header only in normal mode `make push`
if [ -z "$list" ] && [ -z "$fast" ]; then
    echo -e "${YELLOW}PUSH MANAGER${ENDCOLOR}"
fi

if [ -z "$fast" ]; then
    echo
fi


### Print list of unpushed commits
echo -e "${YELLOW}Commit history from ${history_from}:${ENDCOLOR}"
echo -e "$push_list"


### List mode - print only unpushed commits
if [ -n "$list" ]; then
    exit
fi


### If not in fast mode - ask if user wants to push
if [ -z "${fast}" ]; then
    echo -e "Do you want to push it to ${YELLOW}${origin_name}/${current_branch}${ENDCOLOR} (y/n)?"
    yes_no_choice "Pushing..."
else
    echo -e "${YELLOW}Pushing...${ENDCOLOR}"
    echo
fi


### Pushing
push


### Get push error - there is unpulled changes
echo -e "${RED}Cannot push! There is unpulled changes in '${origin_name}/${current_branch}'${ENDCOLOR}"
echo
echo -e "Do you want to pull ${YELLOW}${origin_name}/${current_branch}${ENDCOLOR} with --no-rebase (y/n)?"
yes_no_choice "Pulling..."

pull $current_branch $origin_name $editor


### Push after pull
echo
echo -e "${YELLOW}Pushing...${ENDCOLOR}"
echo
push

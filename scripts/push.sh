#!/usr/bin/env bash

### Script for pushing commits in git repository
# It will pull current branch if there are unpulled changes
# Read README.md to get more information how to use it
# Use this script only with gitbasher.sh

### Options
# y: fast push (answer 'yes')
# l: list of commits to push
# b: name of main branch (default 'main')
# o: name of remote (default 'origin')
# u: path to utils.sh (mandator, auto pass by gitbasher.sh)


while getopts ylb:o:u: flag; do
    case "${flag}" in
        y) fast="true";;
        l) list="true";;

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

source $utils


branch=$(git branch --show-current)

### Use this function to push changes to origin
### It will exit if everyrhing is ok or there is a critical error
function push {
    push_output=$(git push ${origin_name} ${branch} 2>&1)
    push_code=$?

    if [ $push_code -eq 0 ] ; then 
        echo -e "${GREEN}Successful push!${ENDCOLOR}"
        repo=$(git config --get remote.${origin_name}.url)
        repo="${repo/":"/"/"}" 
        repo="${repo/"git@"/"https://"}"
        repo="${repo/".git"/""}" 
        echo -e "${YELLOW}Repo:${ENDCOLOR}\t${repo}"
        if [[ ${branch} != ${main_branch} ]]; then
            if [[ $repo == *"github"* ]]; then
                echo -e "${YELLOW}PR:${ENDCOLOR}\t${repo}/pull/new/${branch}"
            elif [[ $repo == *"gitlab"* ]]; then
                echo -e "${YELLOW}MR:${ENDCOLOR}\t${repo}/-/merge_requests/new?merge_request%5Bsource_branch%5D=${branch}"
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

### Print header
if [ -z "$list" ]; then
    echo -e "${YELLOW}PUSH MANAGER${ENDCOLOR}"
fi
echo


### Check if there is commits to push
get_push_log ${branch} ${main_branch} ${origin_name}

if [ "${history_from}" != "${origin_name}/${branch}" ]; then
    echo -e "Branch ${YELLOW}${branch}${ENDCOLOR} doesn't exist in ${origin_name}, so get commit diff from base commit"
fi

if [ -z "$push_log" ]; then
    echo -e "${GREEN}Nothing to push${ENDCOLOR}"
    exit
fi

echo -e "${YELLOW}Commit history from ${history_from}:${ENDCOLOR}"
echo -e $push_log


### List mode - print only unpushed commits
if [ -n "$list" ]; then
    exit
fi


### Run fast mode - push without asking and fixing errors
if [ -n "${fast}" ]; then
    push
    exit
fi


### Push
echo -e "Do you want to push it to ${YELLOW}${origin_name}/${branch}${ENDCOLOR} (y/n)?"
yes_no_choice "Pushing..."
push


### Gut push error - there is unpulled changes
echo -e "${RED}Cannot push! There is unpulled changes in ${origin_name}/${branch}${ENDCOLOR}"
echo

echo -e "Do you want to pull ${YELLOW}${origin_name}/${branch}${ENDCOLOR} with --no-rebase (y/n)?"
yes_no_choice "Pulling..."

pull_output=$(git pull ${origin_name} ${branch} --no-rebase 2>&1)
pull_code=$?


### Successful pull - push and exit
if [ $pull_code -eq 0 ] ; then
    echo -e "${GREEN}Successful pull!${ENDCOLOR}"
    echo -e "${YELLOW}Pushing...${ENDCOLOR}"
    echo
    push
fi


### Cannot pull because there is uncommitted files that changed in origin
if [[ $pull_output == *"Please commit your changes or stash them before you merge"* ]]; then
    echo -e "${RED}Cannot pull! There is uncommited changes, that will be overwritten by merge${ENDCOLOR}"
    files_to_commit=$(echo "$pull_output" | tail -n +4 | head -n +1)
    echo -e "${YELLOW}Files:${ENDCOLOR}"
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
echo -e "${RED}Cannot pull! You should fix conflicts${ENDCOLOR}"
files_with_conflicts=$(git diff --name-only --diff-filter=U --relative | cat)
echo -e "${YELLOW}Files:${ENDCOLOR}"
echo "$files_with_conflicts"
echo
echo -e "Fix conflicts and commit result, then use ${YELLOW}make push${ENDCOLOR} for one more time"


### Abort merge
echo -e "Press ${YELLOW}n${ENDCOLOR} if you want to abort merge or any key to exit"
read -n 1 -s choice
if [ "$choice" == "n" ]; then
    echo -e "${YELLOW}Aborting merge...${ENDCOLOR}"
    git merge --abort
fi

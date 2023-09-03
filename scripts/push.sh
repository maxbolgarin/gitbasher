#!/usr/bin/env bash

### Script for pushing commits in git repository
# It will pull current branch if there are unpulled changes

### Options
# y: fast push (answer 'yes')
# l: list of commits to push
# r: repo url to print after push

while getopts ylr:b:u: flag; do
    case "${flag}" in
        y) fast="true";;
        l) list="true";;
        r) repo=${OPTARG};;

        b) main_branch=${OPTARG};;
        u) utils=${OPTARG};;
    esac
done

if [ -z "$main_branch" ]; then
    main_branch="main"
fi

source $utils

branch=$(git branch --show-current)
# TODO: fix local branches
push_log=$(git --no-pager log --pretty=format:"\t%h - %an, %ar:\t%s\n" origin/${branch}..HEAD)

if [ -z "$list" ]; then
    echo -e "${YELLOW}PUSH MANAGER${ENDCOLOR} v1.0"
fi

echo

if [ -z "$push_log" ]; then
    echo -e "${GREEN}Nothing to push${ENDCOLOR}"
    exit
fi

echo -e "${YELLOW}Commit history:${ENDCOLOR}"
echo -e $push_log

if [ -n "$list" ]; then
    exit
fi

if [ -n "${fast}" ]; then
    git push origin ${branch}
    exit
fi

echo -e "Do you want to push it to ${YELLOW}origin/${branch}${ENDCOLOR} (y/n)?"
while [ true ]; do
    read -n 1 -s choice
    if [ "$choice" == "y" ]; then
        echo -e "${YELLOW}Pushing...${ENDCOLOR}"
        echo
        break
    fi
    if [ "$choice" == "n" ]; then
        exit
    fi
done

function push {
    push_output=$(git push origin ${branch} 2>&1)
    push_code=$?

    if [ $push_code -eq 0 ] ; then 
        echo -e "${GREEN}Successful push!${ENDCOLOR}"
        echo -e "${YELLOW}Repo: ${ENDCOLOR}${repo}"
        exit
    fi

    if [[ $push_output != *"[rejected]"* ]]; then
        echo -e "${RED}Cannot push! Here is the error${ENDCOLOR}"
        echo "$push_output"
        exit $push_code
    fi
}

# will exit if everythinh is ok
push

echo -e "${RED}Cannot push! There is unpulled changes in origin/${branch}${ENDCOLOR}"
echo

echo -e "Do you want to pull ${YELLOW}origin/${branch}${ENDCOLOR} with --no-rebase (y/n)?"
while [ true ]; do
    read -n 1 -s choice
    if [ "$choice" == "y" ]; then
        echo -e "${YELLOW}Pulling...${ENDCOLOR}"
        echo
        break
    fi
    if [ "$choice" == "n" ]; then
        exit
    fi
done

pull_output=$(git pull origin ${branch} --no-rebase 2>&1)
pull_code=$?

if [ $pull_code -eq 0 ] ; then
    echo -e "${GREEN}Successful pull!${ENDCOLOR}"
    echo -e "${YELLOW}Pushing...${ENDCOLOR}"
    echo
    push
fi

if [[ $pull_output == *"Please commit your changes or stash them before you merge"* ]]; then
    echo -e "${RED}Cannot pull! There is uncommited changes, that will be overwritten by merge${ENDCOLOR}"
    files_to_commit=$(echo "$pull_output" | tail -n +4 | head -n +1)
    echo -e "${YELLOW}Files:${ENDCOLOR}"
    echo "$files_to_commit"
    exit $pull_code
fi

if [[ $pull_output != *"fix conflicts and then commit the result"* ]]; then
    echo -e "${RED}Cannot pull! Here is the error${ENDCOLOR}"
    echo "$pull_output"
    exit $pull_code
fi

echo -e "${RED}Cannot pull! You should fix conflicts${ENDCOLOR}"
files_with_conflicts=$(git diff --name-only --diff-filter=U --relative | cat)
echo -e "${YELLOW}Files:${ENDCOLOR}"
echo "$files_with_conflicts"
echo
echo -e "Fix conflicts and commit result, then use ${YELLOW}make push${ENDCOLOR} for one more time"

echo -e "Press ${YELLOW}n${ENDCOLOR} if you want to abort merge or any key to exit"
read -n 1 -s choice
if [ "$choice" == "n" ]; then
    echo -e "${YELLOW}Aborting merge...${ENDCOLOR}"
    git merge --abort
fi

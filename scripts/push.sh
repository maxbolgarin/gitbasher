#!/usr/bin/env bash

### Script for pushing commits in git repository

### Options
# y: fast push (answer 'yes')
# r: repo url to print after push

while getopts yr:b:u: flag; do
    case "${flag}" in
        y) fast="true";;
        r) repo=${OPTARG};;

        b) main_branch=${OPTARG};;
        u) utils=${OPTARG};;
    esac
done

if [ -z "$main_branch" ]; then
    main_branch="main"
fi

source $utils

### TODO: pull and merge

echo -e "${YELLOW}PUSH MANAGER${ENDCOLOR} v1.0"
echo

branch=$(git branch --show-current)
push_log=$(git --no-pager log --pretty=format:"\t%h - %an, %ar:\t%s\n" origin/${branch}..HEAD)

if [ -z "$push_log" ]; then
    echo "Nothing to push"
    exit
fi

echo -e "${YELLOW}Commit history:${ENDCOLOR}"
echo -e $push_log

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
 
git push origin ${branch} 

if [ $? -eq 0 ] ; then 
    echo
    echo -e "${GREEN}Successful push!${ENDCOLOR}"
    echo -e "${YELLOW}Repo: ${ENDCOLOR}${repo}"
fi

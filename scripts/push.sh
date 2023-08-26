#!/usr/bin/env bash

### Script for pushing commits in git repository

### Options
# f: fast push (not force!)

while getopts fb:u: flag; do
    case "${flag}" in
        f) fast="true";;

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
        echo "Pushing..."
        break
    fi
    if [ "$choice" == "n" ]; then
        exit
    fi
done
 
git push origin ${branch} 

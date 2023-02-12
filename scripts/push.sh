#!/bin/bash

YELLOW="\e[33m"
ENDCOLOR="\e[0m"

# f: fast push (not force!)

while getopts f flag; do
    case "${flag}" in
        f) fast="true";;
    esac
done

branch=$(git branch --show-current)
push_log=$(git --no-pager log --pretty=format:"\t%h - %an, %ar:\t%s\n" origin/${branch}..HEAD)

if [ -z "$push_log" ]; then
    echo "Nothing to push"
    exit 1
fi

echo -e "${YELLOW}Commit history:${ENDCOLOR}"
echo -e $push_log

if [ -n "${fast}" ]; then
    git push origin ${branch}
    exit 0
fi

echo -e "Do you want to push it to ${YELLOW}origin/${branch}${ENDCOLOR} (y/n)?"
while [ true ]; do
    read -n 1 -s choice
    if [ "$choice" == "y" ]; then
        echo "Pushing..."
        break
    fi
    if [ "$choice" == "n" ]; then
        exit 1
    fi
done
 
git push origin ${branch} 

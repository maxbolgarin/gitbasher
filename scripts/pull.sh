#!/usr/bin/env bash

### Script for pulling commits from remote git repository
# Read README.md to get more information how to use it
# Use this script only with gitbasher.sh

### Options
# e: text editor to write commit message (default 'nano')
# b: name of main branch (default 'main')
# o: name of remote (default 'origin')
# u: path to common.sh (mandator, auto pass by gitbasher.sh)


while getopts e:b:o:u: flag; do
    case "${flag}" in
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


branch=$(git branch --show-current)

echo
echo -e "${YELLOW}Pulling '$origin_name/$branch'...${ENDCOLOR}"
echo
pull $branch $origin_name $editor

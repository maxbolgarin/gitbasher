#!/usr/bin/env bash

### Script for managing git tags
# Read README.md to get more information how to use it
# Semver reference: https://semver.org/
# Use this script only with gitbasher.sh

### Options
# empty: create a new tag from a current branch and commit
# s: select commit instead of using current one
# a: create an annotated tag with message
# l: print list of local tags and exit
# d: select a tag to delete 
# r: pull tags from remote
# p: push tags (pass -s to select what tag to push)
# e: text editor to write commit message (default 'nano')
# b: name of main branch (default 'main')
# o: name of remote (default 'origin')
# u: path to utils.sh (mandatory, auto pass by gitbasher.sh)


while getopts saldrpe:b:o:u: flag; do
    case "${flag}" in
        s) select="true";;
        a) annotated="true";;
        l) list="true";;
        d) delete="true";;
        r) remote="true";;
        p) push="true";;

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

### Print header
if [ -n "${annotated}" ]; then
    echo -e "${YELLOW}TAG MANAGER${ENDCOLOR} ANNOTATED"
elif [ -n "${delete}" ]; then
    echo -e "${YELLOW}TAG MANAGER${ENDCOLOR} DELETE"
elif [ -n "${push}" ]; then
    echo -e "${YELLOW}TAG MANAGER${ENDCOLOR} PUSH"
else
    echo -e "${YELLOW}TAG MANAGER${ENDCOLOR}"
fi

echo

count=10

tags_list=$(git for-each-ref --count=$count --format="%(refname:short) | %(creatordate:relative) | %(objectname:short) - %(contents:subject)" --sort=-creatordate refs/tags | column -ts'|' )
tags_only=$(git for-each-ref --count=$count --format="%(refname:short)" --sort=-creatordate refs/tags)

IFS=$'\n' read -rd '' -a tags_info <<<"$tags_list"
IFS=$'\n' read -rd '' -a tags <<<"$tags_only"

echo -e "${YELLOW}Last local tags${ENDCOLOR}"

for index in "${!tags[@]}"
do
    tag_line=$(sed "s/${tags[index]}/${GREEN_ES}${tags[index]}${ENDCOLOR_ES}/g" <<< ${tags_info[index]})
    echo -e "${tag_line}"
    #echo -e "$(($index+1)). ${tag_line}"
done

if [ -n "$list" ]; then
    exit
fi

echo
echo -e "${YELLOW}Current commit${ENDCOLOR}"

current_branch=$(git branch --show-current)
commit_hash=$(git rev-parse HEAD)
commit_message=$(git log -1 --pretty=%B | cat)
echo -e "${BLUE}[$current_branch ${commit_hash::7}]${ENDCOLOR} ${commit_message}"

echo

echo -e "${YELLOW}Enter the name of a new tag${ENDCOLOR}"
echo -e "If this tag will be using for release, use version number in semver format, like '1.0.0-alpha'"
echo -e "Leave it blank to exit"

read -p "git tag " -e tag_name

if [ -z $tag_name ]; then
    exit
fi

echo

tag_output=$(git tag $tag_name 2>&1)
tag_code=$?

if [ $tag_code != 0 ]; then
    if [[ $tag_output == *"already exists" ]]; then
        echo -e "${RED}Tag '${tag_name}' already exists${ENDCOLOR}"
    else
        echo -e "${RED}Cannot create tag '${tag_name}'${ENDCOLOR}"
        echo -e "$tag_output"
    fi
    exit
fi

echo -e "${GREEN}Successfully created tag '${tag_name}'${ENDCOLOR}"

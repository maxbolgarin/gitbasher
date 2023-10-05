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
# u: path to common.sh (mandatory, auto pass by gitbasher.sh)


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

count=14
if [ -n "${delete}" ]; then
    count=9
fi

tags_list=$(git for-each-ref --count=$count --format="%(refname:short) | %(creatordate:relative) | %(objectname:short) - %(contents:subject)" --sort=-creatordate refs/tags | column -ts'|' )
tags_only=$(git for-each-ref --count=$count --format="%(refname:short)" --sort=-creatordate refs/tags)

IFS=$'\n' read -rd '' -a tags_info <<<"$tags_list"
IFS=$'\n' read -rd '' -a tags <<<"$tags_only"

number_of_tags=${#tags[@]}

if [ $number_of_tags == 0 ]; then
    echo -e "${YELLOW}There is no local tags${ENDCOLOR}"
    if [ -n "${delete}" ]; then
        exit
    fi
else
    echo -e "${YELLOW}Last ${number_of_tags} local tags${ENDCOLOR}"

    for index in "${!tags[@]}"
    do
        tag_line=$(sed "1,/${tags[index]}/ s/${tags[index]}/${GREEN_ES}${tags[index]}${ENDCOLOR_ES}/" <<< ${tags_info[index]})
        if [ -n "${delete}" ]; then
            echo -e "$(($index+1)). ${tag_line}"
        else
            echo -e "${tag_line}"
        fi
    done
fi

if [ -n "$list" ]; then
    exit
fi

if [ -n "${delete}" ]; then
    echo "0. Exit..."
    echo
    printf "Enter tag number to delete: "
    while [ true ]; do
        read -n 1 -s choice

        if [ "$choice" == "0" ]; then
            printf $choice
            exit
        fi

        re='^[0-9]+$'
        if ! [[ $choice =~ $re ]]; then
            continue
        fi

        index=$(($choice-1))
        tag_name=${tags[index]}
        if [ -n "$tag_name" ]; then
            printf $choice
            break
        fi
    done

    echo
    echo

    delete_result=$(git tag -d $tag_name 2>&1)
    delete_code=$?

    if [ $delete_code != 0 ]; then
        echo -e "${RED}Cannot delete tag '${tag_name}'!${ENDCOLOR}"
        echo -e "$delete_result"
        exit
    fi

    echo -e "${GREEN}Successfully deleted tag '${tag_name}'${ENDCOLOR}"

    exit
fi

echo

current_branch=$(git branch --show-current)

if [ -n "$select" ]; then
    echo -e "${YELLOW}Select commit for a new tag on branch '$current_branch'${ENDCOLOR}"
    choose_commit 9
    commit_message=$(git log -1 --pretty=%B $commit_hash | cat)

else
    echo -e "${YELLOW}Current commit${ENDCOLOR}"

    commit_hash=$(git rev-parse HEAD)
    commit_message=$(git log -1 --pretty=%B | cat)
    echo -e "${BLUE}[$current_branch ${commit_hash::7}]${ENDCOLOR} ${commit_message}"

fi

echo
echo -e "${YELLOW}Enter the name of a new tag${ENDCOLOR}"
echo -e "If this tag will be using for release, use version number in semver format, like '1.0.0-alpha'"
echo -e "Leave it blank to exit"

if [ -n "${annotated}" ]; then
    prompt="$(echo -n -e "${YELLOW}git tag -a${ENDCOLOR} ")"
else
    prompt="$(echo -n -e "${YELLOW}git tag${ENDCOLOR} ")"
fi

read -p "$prompt" -e tag_name

if [ -z $tag_name ]; then
    exit
fi

echo

if [ -n "$annotated" ]; then
    tag_file=".tagmsg__"
    touch $tag_file

    echo """
###
### Write some words about a new tag '${tag_name}'
### [$current_branch ${commit_hash::7}] ${commit_message}
### 
### You can place changelog here, if this tag means a new release
""" >> $tag_file

    while [ true ]; do
        $editor $tag_file
        tag_message=$(cat $tag_file | sed '/^#/d')

        if [ -n "$tag_message" ]; then
            break
        fi
        echo
        echo -e "${YELLOW}Tag message cannot be empty${ENDCOLOR}"
        echo
        read -n 1 -p "Try for one more time? (y/n) " -s -e choice
        if [ "$choice" != "y" ]; then
            find . -name "$tag_file*" -delete
            exit
        fi    
    done

    find . -name "$tag_file*" -delete
fi


if [ -z "$select" ]; then
    commit_hash=""
fi

if [ -n "$annotated" ]; then
    tag_output=$(git tag -a -m """$tag_message""" $tag_name $commit_hash 2>&1)
else
    tag_output=$(git tag $tag_name $commit_hash 2>&1)
fi

tag_code=$?

if [ $tag_code != 0 ]; then
    if [[ $tag_output == *"already exists" ]]; then
        echo -e "${RED}Tag '${tag_name}' already exists!${ENDCOLOR}"
    else
        echo -e "${RED}Cannot create tag '${tag_name}'!${ENDCOLOR}"
        echo -e "$tag_output"
    fi
    exit
fi

if [ -n "$annotated" ]; then
    is_annotated=" annotated"
fi

if [ -n "$select" ]; then
    is_commit_hash=" from commit '${commit_hash}'"
fi

echo -e "${GREEN}Successfully created${is_annotated} tag '${tag_name}'${is_commit_hash}!${ENDCOLOR}"

if [ -n "$tag_message" ]; then
    echo -e "$tag_message"
fi

echo

echo -e "Do you want to push this tag to ${origin} (y/n)?"
yes_no_choice "Pushing..."

#push_result=$(git tag -d $tag_name 2>&1)
#push_code=$?

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
fi

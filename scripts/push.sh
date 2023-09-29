#!/usr/bin/env bash

### Script for pushing commits in git repository
# It will pull current branch if there are unpulled changes
# Read README.md to get more information how to use it
# Use this script only with gitbasher.sh

### Options
# y: fast push (answer 'yes')
# l: list of commits to push
# b: name of main branch
# u: path to utils.sh (mandatory)


while getopts ylb:u: flag; do
    case "${flag}" in
        y) fast="true";;
        l) list="true";;

        b) main_branch=${OPTARG};;
        u) utils=${OPTARG};;
    esac
done

if [ -z "$main_branch" ]; then
    main_branch="main"
fi

source $utils


branch=$(git branch --show-current)

### Use this function to push changes to origin
### It will exit if everyrhing is ok or there is a critical error
function push {
    push_output=$(git push origin ${branch} 2>&1)
    push_code=$?

    if [ $push_code -eq 0 ] ; then 
        echo -e "${GREEN}Successful push!${ENDCOLOR}"
        repo=$(git config --get remote.origin.url)
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

### This function asks user to enter yes or no, it will exit at no answer
# $1: What to write to console on success
function yes_no_choice {
    while [ true ]; do
        read -n 1 -s choice
        if [ "$choice" == "y" ]; then
            if [ -n "$1" ]; then 
                echo -e "${YELLOW}$1${ENDCOLOR}"
                echo
            fi
            return
        fi
        if [ "$choice" == "n" ]; then
            exit
        fi
    done
}

### Function returns git log diff between provided argument and HEAD
# $1: branch or commit from which to calc diff
function gitlog_diff {
    git --no-pager log --pretty=format:"\t%h - %an, %ar:\t%s\n" $1..HEAD 2>&1
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
push_log=$(gitlog_diff origin/${branch})
history_from="origin/${branch}"
if [[ $push_log == *"unknown revision or path not in the working tree"* ]]; then
    echo "${YELLOW}Branch ${branch} doesn't exist in origin, so get commit diff from base commit${ENDCOLOR}"
    
    base_commit=$(diff -u <(git rev-list --first-parent ${branch}) <(git rev-list --first-parent ${main_branch}) | sed -ne 's/^ //p' | head -1)
    if [ -n "$base_commit" ]; then
        push_log=$(gitlog_diff ${base_commit})
        history_from="${base_commit} (base ${branch} commit)"
    else
        push_log=$(gitlog_diff "origin/${main_branch}")
        history_from="origin/${main_branch}"
    fi
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
echo -e "Do you want to push it to ${YELLOW}origin/${branch}${ENDCOLOR} (y/n)?"
yes_no_choice "Pushing..."
push


### Gut push error - there is unpulled changes
echo -e "${RED}Cannot push! There is unpulled changes in origin/${branch}${ENDCOLOR}"
echo

echo -e "Do you want to pull ${YELLOW}origin/${branch}${ENDCOLOR} with --no-rebase (y/n)?"
yes_no_choice "Pulling..."

pull_output=$(git pull origin ${branch} --no-rebase 2>&1)
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


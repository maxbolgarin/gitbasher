#!/usr/bin/env bash

### Script for pushing commits in git repository
# It will pull current branch if there are unpulled changes
# Read README.md to get more information how to use it
# Use this script only with gitbasher.sh

### Options
# y: fast push (answer 'yes')
# l: list of commits to push
# e: text editor to write commit message (default 'nano')
# b: name of main branch (default 'main')
# o: name of remote (default 'origin')
# u: path to utils.sh (mandator, auto pass by gitbasher.sh)


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


branch=$(git branch --show-current)

### Use this function to push changes to origin
### It will exit if everyrhing is ok or there is a critical error, return if there is unpulled changes
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
echo -e "${RED}Cannot push! There is unpulled changes in '${origin_name}/${branch}'${ENDCOLOR}"
echo

echo -e "Do you want to pull ${YELLOW}${origin_name}/${branch}${ENDCOLOR} with --no-rebase (y/n)?"
yes_no_choice "Pulling..."

pull_output=$(git pull $origin_name $branch --no-rebase 2>&1)
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
echo -e "${RED}Cannot pull! There are conflicts in staged files${ENDCOLOR}"
echo -e "${YELLOW}Files with conflicts${ENDCOLOR}"

IFS=$'\n' read -rd '' -a files_with_conflicts <<<"$(git --no-pager diff --name-only --diff-filter=U --relative)"
files_with_conflicts_line=""
for index in "${!files_with_conflicts[@]}"
do
    files_with_conflicts_line="${files_with_conflicts_line} ${files_with_conflicts[index]}"
    echo -e "\t${files_with_conflicts[index]}"
done

echo


### Merge process
default_message="Merge branch '$origin_name/$branch' into '$branch'"
echo -e "${YELLOW}You should fix conflicts manually.${ENDCOLOR} There are some options:"
echo -e "1. Create merge commit with generated message and continue push"
printf "\tMessage: ${BLUE}${default_message}${ENDCOLOR}\n"
echo -e "2. Create merge commit with entered message and continue push"
echo -e "3. Abort merge (undo pulling)"
echo -e "Press any another key to exit from this script without merge abort"


while [ true ]; do
    read -n 1 -s choice

    re='^[0-9]+$'
    if ! [[ $choice =~ $re ]]; then
        exit
    fi

    if [ "$choice" == "1" ] || [ "$choice" == "2" ]; then
        echo

        IFS=$'\n' read -rd '' -a files_with_conflicts_new <<<"$(grep --files-with-matches -r -E "[<=>]{7} HEAD" .)"
        number_of_conflicts=${#files_with_conflicts_new[@]}
        if [ $number_of_conflicts -gt 0 ]; then
            echo -e "${YELLOW}There are still some files with conflicts${ENDCOLOR}"
            for index in "${!files_with_conflicts_new[@]}"
            do
                echo -e $(sed '1 s/.\///' <<< "\t${files_with_conflicts_new[index]}")
            done
            echo
            echo -e "Fix conflicts and press ${YELLOW}${choice}${ENDCOLOR} for one more time"
            continue
        fi

        git add $files_with_conflicts_line

        if [ "$choice" == "1" ]; then
            result=$(git commit -m "$default_message" 2>&1)
            check_code $? "$result" "merge commit"
        else
            staged_with_tab="$(sed 's/^/###\t/' <<< "${files_with_conflicts}")"
            commitmsg_file=".commitmsg__"
            touch $commitmsg_file
            echo """
###
### Write a message about merge from '$origin_name/$branch' into '$branch'. Lines starting with '#' will be ignored. 
### 
### On branch ${branch}
### Changes to be commited:
${staged_with_tab}
""" >> $commitmsg_file
            while [ true ]; do
                $editor $commitmsg_file
                commit_message=$(cat $commitmsg_file | sed '/^#/d')

                if [ -n "$commit_message" ]; then
                    break
                fi
                echo
                echo -e "${YELLOW}Merge commit message cannot be empty${ENDCOLOR}"
                echo
                read -n 1 -p "Try for one more time? (y/n) " -s -e choice
                if [ "$choice" != "y" ]; then
                    git restore --staged $files_with_conflicts_line
                    find . -name "$commitmsg_file*" -delete
                    exit
                fi    
            done

            find . -name "$commitmsg_file*" -delete
            
            result=$(git commit -m """$commitmsg_file""" 2>&1)
            check_code $? "$result" "merge commit"
        fi

        echo -e "${GREEN}Successful merge!${ENDCOLOR}"
        echo -e "${YELLOW}Pushing...${ENDCOLOR}"
        echo
        push
    fi

    if [ "$choice" == "3" ]; then
        echo
        echo -e "${YELLOW}Cancel merge and undo pull${ENDCOLOR}"
        git merge --abort
        exit $?
    fi

    if [ "$choice" == "0" ]; then
        exit
    fi
done


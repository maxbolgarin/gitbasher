#!/usr/bin/env bash

### Script for working with branches: create, switch, delete
# Use a separate branch for writing new code, then merge it to main
# Read README.md to get more information how to use it
# Use this script only with gitbasher.sh

### Options
# no options: switch to local branch
# r: switch to a remote branch
# m: switch to the main branch
# n: create a new branch
# c: create a new branch from a current one instead of the main branch
# d: delete a local branch
# s: separator between type and name (default '/')
# b: name of main branch (default 'main')
# o: name of remote (default 'origin')
# u: path to common.sh (mandatory, auto pass by gitbasher.sh)


while getopts rmncds:b:o:u: flag; do
    case "${flag}" in
        r) remote="true";;
        m) main="true";;
        n) new="true";;
        c) current="true";;
        d) delete="true";;
        s) sep=${OPTARG};;

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

if [ -z "$sep" ]; then
    sep="/"
fi

source $utils

###
### Script logic below
###

### Print header
header="BRANCH MANAGER"
if [ -n "${new}" ]; then
    header="$header NEW"
elif [ -n "${remote}" ]; then
    header="$header REMOTE"
elif [ -n "${delete}" ]; then
    header="$header DELETE"
fi

if [ -z "${main}" ]; then
    echo -e "${YELLOW}${header}${ENDCOLOR}"
fi
echo


### Run switch to main logic
if [[ -n "${main}" ]]; then
    switch ${main_branch}
    exit
fi


### Run switch to local logic
if [[ -z "$new" ]] && [[ -z "$remote" ]] && [[ -z "$delete" ]]; then
    echo -e "${YELLOW}Switch from '${current_branch}' to local branch${ENDCOLOR}"

    choose_branch

    echo

    switch ${branch_name}
    exit


### Run switch to remote logic
elif [[ -z "$new" ]] && [[ -n "$remote" ]] && [[ -z "$delete" ]]; then
    echo -e "${YELLOW}Fetching remote...${ENDCOLOR}"
    echo

    fetch_output=$(git fetch 2>&1)
    fetch_code=$?
    if [ $fetch_code -ne 0 ] ; then
        echo -e "${RED}Cannot fetch remote!${ENDCOLOR}"
        echo -e "${fetch_output}"
        exit $fetch_code
    fi

    echo -e "${YELLOW}Switch from '${current_branch}' to remote branch${ENDCOLOR}"
    
    choose_branch "remote"

    echo

    switch ${branch_name}
    exit


### Run delete local logic
elif [[ -z "$new" ]] && [[ -n "$delete" ]]; then

    # Try to delete all merged branches
    IFS=$'\n' read -rd '' -a merged_branches <<<"$(git branch -v --sort=-committerdate --merged | cat 2>&1)"

    merged_branches_without_main=()
    for index in "${!merged_branches[@]}"
    do
        branch_with_info="$(echo "${merged_branches[index]}" | sed -e 's/^[[:space:]]*//')"
        if [[ ${branch_with_info} != "${main_branch}"* ]] && [[ ${branch_with_info} != "*"* ]] ; then
            merged_branches_without_main+=("$branch_with_info")
        fi
    done
    number_of_branches=${#merged_branches_without_main[@]}

    if [ $number_of_branches != 0 ]; then
        echo -e "${YELLOW}Do you want to delete merged local branches?${ENDCOLOR}"
        echo -e "These are branches without new changes regarding ${main_branch}"
        for index in "${!merged_branches_without_main[@]}"
        do
            printf "\t${merged_branches_without_main[index]}\n"
        done

        printf "\nAnswer (y/n): "
        
        while [ true ]; do
            read -n 1 -s choice
            if [ "$choice" == "y" ]; then
                printf "y\n\n"
                branches_to_delete="$(git branch --merged | egrep -v "(^\*|master|main|develop|${main_branch})" | xargs)"
                IFS=$' ' read -rd '' -a branches <<<"$branches_to_delete"
                for index in "${!branches[@]}"
                do
                    branch_to_delete="$(echo "${branches[index]}" | xargs)"
                    delete_output=$(git branch -d $branch_to_delete 2>&1)
                    delete_code=$?
                    if [ $delete_code == 0 ]; then
                        echo -e "${GREEN}Deleted branch '$branch_to_delete'${ENDCOLOR}"
                    else
                        echo -e "${RED}Cannot delete branch '$branch_to_delete'!${ENDCOLOR}"
                        echo -e "${delete_output}"
                        break
                    fi
                done
                echo
                break

            elif [ "$choice" == "n" ]; then
                printf "n\n\n"
                break
            fi
        done
    fi

    # Delete in normal way
    echo -e "${YELLOW}Delete local branch${ENDCOLOR}"

    choose_branch "delete"

    echo

    delete_output=$(git branch -d $branch_name 2>&1)
    delete_code=$?

    if [ "$delete_code" == 0 ]; then
        echo -e "${GREEN}Deleted branch '$branch_name'${ENDCOLOR}"
        exit
    fi

    if [[ ${delete_output} == *"is not fully merged"* ]]; then
        echo -e "${RED}The branch '$branch_name' is not fully merged${ENDCOLOR}"
        echo "Do you want to force delete (-D flag) this branch?"

        printf "\nAnswer (y/n): "
        
        while [ true ]; do
            read -n 1 -s choice
            if [ "$choice" == "y" ]; then
                printf "y\n\n"
                delete_output=$(git branch -D $branch_name 2>&1)
                delete_code=$?
                if [ "$delete_code" == 0 ]; then
                    echo -e "${GREEN}Deleted branch '$branch_name'${ENDCOLOR}"
                    exit
                fi
                echo -e "${RED}Cannot delete branch '$branch_to_delete'!${ENDCOLOR}"
                echo -e "${delete_output}"
                exit

            elif [ "$choice" == "n" ]; then
                printf "n\n"
                exit
            fi
        done

        exit
    fi

    echo -e "${RED}Cannot delete branch '$branch_to_delete'!${ENDCOLOR}"
    echo -e "${delete_output}"
   
    exit
fi


### Run create new branch logic
### Step 1. Choose branch type
echo -e "${YELLOW}Step 1.${ENDCOLOR} What type of branch do you want to create?"
echo "1. feat:      new feature or logic changes, 'feat' and 'perf' commits"
echo "2. fix:       small changes, eg. not critical bug fix"
echo "3. hotfix:    fix, that should be merged as fast as possible"
echo "4. refactor:  non important and/or style changes"
echo "5. misc:      non-code changes, e.g. 'ci', 'docs', 'build' commits"
echo "6. wip:       'work in progress', for changes not ready for merging in the near future"
echo "7.            don't use prefix for branch naming"
echo "0. Exit without changes"

declare -A types=(
    [1]="feat"
    [2]="fix"
    [3]="hotfix"
    [4]="refactor"
    [5]="misc"
    [6]="wip"
)

branch_type=""
while [ true ]; do
    read -n 1 -s choice

    if [ "$choice" == "0" ]; then
        exit
    fi
    
    if [ "$choice" == "7" ]; then
        break
    fi

    re='^[0-9]+$'
    if ! [[ $choice =~ $re ]]; then
        continue
    fi

    branch_type="${types[$choice]}"
    if [ -n "$branch_type" ]; then
        branch_type_and_sep="${branch_type}${sep}"
        break
    fi
done


### Step 2. Enter branch name
echo
echo -e "${YELLOW}Step 2.${ENDCOLOR} Enter the name of the branch, using '-' as a separator between words"
echo "Leave it blank if you want to exit"

read -p "Branch: ${branch_type_and_sep}" -e branch_name

if [ -z $branch_name ]; then
    exit
fi

branch_name="${branch_type_and_sep}${branch_name##*( )}"

if [[ "$branch_name" == "HEAD" ]]; then
    echo
    echo -e "${RED}This name is forbidden${ENDCOLOR}"
    exit
fi

### Step 3. Switch to main and pull it
from_branch=$current_branch
if [ -z "${current}" ]; then
    echo
    switch $main_branch "true"

    echo -e "${YELLOW}Pulling '$origin_name/$main_branch'...${ENDCOLOR}"
    echo
    pull $main_branch $origin_name $editor

    from_branch=$main_branch
fi


### Step 4. Create a new branch and switch to it
create_output=$(git switch -c $branch_name 2>&1)
create_code=$?

echo

if [ $create_code -eq 0 ]; then
    echo -e "${GREEN}${create_output} from '$from_branch'${ENDCOLOR}"
    changes=$(git status -s)
    if [ -n "$changes" ]; then
        echo
        echo -e "${YELLOW}Moved changes:${ENDCOLOR}"
        git status -s
    fi
    exit
fi

if [[ $create_output == *"already exists"* ]]; then
    echo -e "${RED}Branch with name '${branch_name}' already exists!${ENDCOLOR}"
    exit $create_code
fi

echo -e "${RED}Switch error: ${create_output}${ENDCOLOR}"
exit $create_code

#!/usr/bin/env bash

### Script for merging changes between branches
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Main function
# $1: mode
    # empty: merge selected branch to the current one (ask to fetch before merge)
    # main: merge default branch to the current one (ask to fetch before merge)
    # to-main: merge current branch to default
function merge_script {
    case "$1" in
        main|master|m)          main="true";;
        to-main|to-master|tm)   to_main="true";;
        help|h)                 help="true";;
        *)
            wrong_mode "merge" $1
    esac

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb merge <mode>${ENDCOLOR}"
        echo
        echo -e "${YELLOW}Available modes${ENDCOLOR}"
        echo -e "<empty>\t\t\tSelect a branch to merge into the current one and fix conflicts"
        echo -e "main|master|m\t\tMerge $main_branch to the current branch and fix conflicts"
        echo -e "to-main|to-master|tm\tSwitch to $main_branch and merge the current branch into $main_branch"
        echo -e "help|h\t\t\tShow this help"
        exit
    fi


    ### Merge mode - print header
    header="GIT MERGE"
    if [ -n "${to_main}" ]; then
        header="$header MAIN"
    elif [ -n "${to_main}" ]; then
        header="$header TO MAIN"
    fi

    echo -e "${YELLOW}${header}${ENDCOLOR}"
    echo


    ### Select branch which will be merged
    if [ -n "$main" ]; then
        if [ "$current_branch" == "${main_branch}" ]; then
            echo -e "${YELLOW}Already on ${main_branch}${ENDCOLOR}"
            exit
        fi
        merge_branch=${main_branch}

    elif [ -n "$to_main" ]; then
        if [ "$current_branch" == "${main_branch}" ]; then
            echo -e "${YELLOW}Already on ${main_branch}${ENDCOLOR}"
            exit
        fi
        merge_branch=${current_branch}

    else
        echo -e "${YELLOW}Select which branch to merge into '${current_branch}'${ENDCOLOR}"
        choose_branch "merge"
        merge_branch=${branch_name}
        echo
    fi


    ### Fetch before merge
    echo -e "Do you want to fetch ${YELLOW}${origin_name}/${merge_branch}${ENDCOLOR} before merge (y/n)?"
    read -n 1 -s choice
    if [ "$choice" == "y" ]; then
        echo
        echo -e "${YELLOW}Fetching ${origin_name}/${merge_branch}...${ENDCOLOR}"

        fetch $merge_branch $origin_name
        merge_from_origin=true
    fi
    echo


    ### Run merge-to-main logic - switch to main and merge
    if [ -n "$to_main" ]; then
        switch $main_branch "true"
        echo
        current_branch=$main_branch
    fi

    commit_message_before_merge="$(git --no-pager log --pretty="%s" -1)"

    ### Run merge and handle conflicts
    merge $merge_branch $origin_name $editor "merge" $merge_from_origin


    ### Nothing to merge
    if [[ $merge_output == *"Already up to date"* ]]; then
        echo -e "${GREEN}Nothing to merge - already up to date${ENDCOLOR}"
        exit
    fi

    ### If we got here - there is no errors

    commit_message_after_merge="$(git --no-pager log --pretty="%s" -1)"
    if [[ "$commit_message_after_merge" != "$commit_message_before_merge" ]]; then
        echo -e "${GREEN}Successful merge!${ENDCOLOR} ${BLUE}[$merge_branch${ENDCOLOR} -> ${BLUE}$current_branch]${ENDCOLOR}"
        echo -e "$commit_message_after_merge"
    else
        echo -e "${GREEN}Successful fast-forward merge!${ENDCOLOR} ${BLUE}[$merge_branch${ENDCOLOR} -> ${BLUE}$current_branch]${ENDCOLOR}"
    fi

    changes=$(echo "$merge_output" | tail -n +3)
    if [[ $changes == *"conflict"* ]]; then
        commit_hash="$(git --no-pager log --pretty="%h" -1)"
        changes=$(git --no-pager show $commit_hash --stat --format="")
    fi

    if [ -n "$changes" ]; then
        echo
        print_changes_stat "$changes"
    fi
}


### Function merges provided branch and handles errors
# $1: branch name from
# $2: origin name
# $3: editor
# $4: operation name (e.g. merge or pull)
# $5: is merge from origin?
# $6: arguments
# Returns:
#      * merge_output
#      * merge_code - 0 if everything is ok, not zero if there are conflicts
function merge {
    if [ "$5" == "true" ]; then
        merge_output=$(git merge $6 $2/$1 2>&1)
    else
        merge_output=$(git merge $6 $1 2>&1)
    fi
    merge_code=$?

    if [ $merge_code == 0 ] ; then
        return
    fi

    operation="$4"
    if [ "$operation" == "" ]; then
        operation="merge"
    fi

    ### Cannot merge because there are uncommitted files that changed in origin
    if [[ $merge_output == *"Please commit your changes or stash them before you merge"* ]]; then
        echo -e "${RED}Cannot $operation! There are uncommited changes that will be overwritten by $operation${ENDCOLOR}"
        files_to_commit=$(echo "$merge_output" | tail -n +2 | tail -r | tail -n +4 | tail -r)
        echo -e "${YELLOW}Files with changes${ENDCOLOR}"
        echo "$files_to_commit"
        exit $merge_code
    fi

    ### Cannot merge because of some other error
    if [[ $merge_output != *"fix conflicts and then commit the result"* ]]; then
        echo -e "${RED}Cannot $operation! Error message:${ENDCOLOR}"
        echo "$merge_output"
        exit $merge_code
    fi

    echo -e "${RED}Cannot $operation! There are conflicts in staged files${ENDCOLOR}"
    resolve_conflicts $1 $2 $3

    # if we got here - conflicts were resolved
    merge_code=0
    echo
}


### Function pulls provided branch, handles errors and makes a merge
# $1: branch name
# $2: origin name
# $3: editor
function resolve_conflicts {

    ### Ask user what he wants to do
    echo
    default_message="Merge branch '$2/$1' into '$1'"
    echo -e "${YELLOW}You should resolve conflicts manually${ENDCOLOR}"
    echo -e "After resolving, select an option to continue"
    echo -e "1. Create a merge commit with a generated message:"
    printf "\t${BLUE}${default_message}${ENDCOLOR}\n"
    echo -e "2. Create a merge commit with an entered message"
    echo -e "3. Abort merge and return to the original state: ${YELLOW}git merge --abort${ENDCOLOR}"
    echo -e "0. Exit from this script ${BOLD}without${NORMAL} merge abort"

    ### Print files with conflicts
    echo
    echo -e "${YELLOW}Files with conflicts${ENDCOLOR}"
    IFS=$'\n' read -rd '' -a files_with_conflicts <<<"$(git --no-pager diff --name-only --diff-filter=U --relative)"
    echo -e "$(sed 's/^/\t/' <<< "$files_with_conflicts")"

    ### Merge process
    while [ true ]; do
        read -n 1 -s choice

        if [ "$choice" == "1" ] || [ "$choice" == "2" ]; then
            merge_commit $choice $files_with_conflicts "${default_message}" $1 $2 $3
            if [ "$merge_error" == "false" ]; then
                return
            fi
        fi

        if [ "$choice" == "3" ]; then
            echo
            echo -e "${YELLOW}Aborting merge...${ENDCOLOR}"
            git merge --abort
            exit $?
        fi

        if [ "$choice" == "0" ]; then
            exit
        fi
    done
}


### Function creates merge commit
# $1: 1 for merge with default message, 2 for merge with editor
# $2: files with conflicts that should be added to commit
# $3: default message for merge with $1 -eq 1
# $4: branch name
# $5: origin name
# $6: editor
# Returns: 
#     merge_error - "true" if something is bad
function merge_commit {
    merge_error="false"

    ### Check if there are files with conflicts
    files_with_conflicts_one_line="$(tr '\n' ' ' <<< "$2")"
    IFS=$'\n' read -rd '' -a files_with_conflicts_new <<<"$(grep --files-with-matches -r -E "[<=>]{7} HEAD" $files_with_conflicts_one_line)"
    number_of_conflicts=${#files_with_conflicts_new[@]}
    if [ $number_of_conflicts -gt 0 ]; then
        echo
        echo -e "${YELLOW}There are still some files with conflicts${ENDCOLOR}"
        for index in "${!files_with_conflicts_new[@]}"
        do
            echo -e $(sed '1 s/.\///' <<< "\t${files_with_conflicts_new[index]}")
        done

        echo
        echo -e "Fix conflicts and press ${YELLOW}$1${ENDCOLOR} for one more time"
        merge_error="true"
        return
    fi


    ### Add files with resolved conflicts to commit
    files_with_conflicts_one_line="$(tr '\n' ' ' <<< "$2")"
    git add $files_with_conflicts_one_line

    ### 1. Commit with default message
    if [ "$1" == "1" ]; then
        commit_message="$3"
        result=$(git commit -m "$commit_message" 2>&1)
        if [[ $result != *"not staged for commit"* ]]; then
            check_code $? "$result" "creating default merge commit"
        fi  
        

    ### 2. Commit with entered message
    else
        staged_with_tab="$(sed 's/^/###\t/' <<< "$2")"
        commitmsg_file=".commitmsg__"
        touch $commitmsg_file
        echo """
###
### Write a message about merge from '$5/$4' into '$4'. Lines starting with '#' will be ignored. 
### 
### On branch $4
### Changes to be commited:
${staged_with_tab}
""" >> $commitmsg_file

        while [ true ]; do
            $6 $commitmsg_file
            commit_message=$(cat $commitmsg_file | sed '/^#/d')

            if [ -n "$commit_message" ]; then
                break
            fi
            echo
            echo -e "${YELLOW}Merge commit message cannot be empty${ENDCOLOR}"
            echo
            read -n 1 -p "Do you want to try for one more time? (y/n) " -s -e choice
            if [ "$choice" != "y" ]; then
                git restore --staged $files_with_conflicts_one_line
                find . -name "$commitmsg_file*" -delete
                merge_error="true"
                exit
            fi    
        done

        find . -name "$commitmsg_file*" -delete
        
        result=$(git commit -m """$commit_message""" 2>&1)

        if [[ $result != *"not staged for commit"* ]]; then
            check_code $? "$result" "creating merge commit"
        fi  
    fi
}

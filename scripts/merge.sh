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
        remote|r)               remote="true";;
        help|h)                 help="true";;
        *)
            wrong_mode "merge" $1
    esac


    ### Merge mode - print header
    header="GIT MERGE"
    if [ -n "${main}" ]; then
        header="$header MAIN"
    elif [ -n "${to_main}" ]; then
        header="$header TO MAIN"
    elif [ -n "${remote}" ]; then
        header="$header REMOTE"
    fi

    echo -e "${YELLOW}${header}${ENDCOLOR}"
    echo


    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb merge <mode>${ENDCOLOR}"
        echo
        msg="${YELLOW}Mode${ENDCOLOR}_${GREEN}Aliases${ENDCOLOR}_\t${BLUE}Description${ENDCOLOR}"
        msg="$msg\n${BOLD}<empty>${ENDCOLOR}_ _Select a branch to merge into the current one and fix conflicts"
        msg="$msg\n${BOLD}main${ENDCOLOR}_master|m_Merge $main_branch to the current branch and fix conflicts"
        msg="$msg\n${BOLD}to-main${ENDCOLOR}_to-master|tm_Switch to $main_branch and merge the current branch into $main_branch"
        msg="$msg\n${BOLD}remote${ENDCOLOR}_r_Fetch $origin_name and select a remote branch to merge into current"
        msg="$msg\n${BOLD}help${ENDCOLOR}_h_Show this help"
        echo -e "$(echo -e "$msg" | column -ts'_')"
        echo
        echo -e "${YELLOW}Conflict resolution options (available during merge conflicts):${ENDCOLOR}"
        echo -e "Accept all incoming changes\tResolve all conflicts by accepting changes from the target branch"
        echo -e "Accept all current changes\tResolve all conflicts by keeping changes from your current branch"
        exit
    fi


    ### Check current branch for remote changes (skip for to-main mode as we'll switch anyway)
    if [ -z "$to_main" ]; then
        echo -e "${YELLOW}Checking current branch for remote changes...${ENDCOLOR}"
        
        # Get the current local commit hash for current branch
        current_local_commit=$(git rev-parse HEAD 2>/dev/null)
        
        # Get the remote commit hash for current branch
        current_remote_commit=$(git ls-remote $origin_name refs/heads/$current_branch 2>/dev/null | cut -f1)
        
        if [ -z "$current_remote_commit" ]; then
            echo -e "${YELLOW}Remote branch ${origin_name}/${current_branch} not found - proceeding with local merge${ENDCOLOR}"
        elif [ "$current_local_commit" != "$current_remote_commit" ]; then
            echo -e "${YELLOW}Remote changes detected in current branch ${current_branch}!${ENDCOLOR}"
            echo
            echo -e "Do you want to pull ${YELLOW}${origin_name}/${current_branch}${ENDCOLOR} first (y/n)?"
            read -n 1 -s choice
            if [ "$choice" == "y" ]; then
                echo
                echo -e "${YELLOW}Pulling ${origin_name}/${current_branch}...${ENDCOLOR}"
                
                pull_output=$(git pull $origin_name $current_branch 2>&1)
                pull_code=$?
                
                if [ $pull_code -eq 0 ]; then
                    echo -e "${GREEN}Successfully pulled current branch${ENDCOLOR}"
                    if [[ $pull_output == *"file changed"* ]] || [[ $pull_output == *"files changed"* ]]; then
                        # Extract only the file statistics (lines starting with space and containing |)
                        # and the summary line (contains "file changed" or "files changed")
                        changes=$(echo "$pull_output" | grep -E "^ .+\|.+|[0-9]+ files? changed")
                        if [ -n "$changes" ]; then
                            echo
                            print_changes_stat "$changes"
                        fi
                    fi
                else
                    echo -e "${RED}Failed to pull current branch:${ENDCOLOR}"
                    echo "$pull_output"
                    exit $pull_code
                fi
            fi
        else
            echo -e "${GREEN}Current branch is up to date with remote${ENDCOLOR}"
        fi
        echo
    fi


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

    elif [ -n "$remote" ]; then
        echo -e "${YELLOW}Fetching remote...${ENDCOLOR}"
        echo

        fetch_output=$(git fetch 2>&1)
        check_code $? "$fetch_output" "fetch remote"

        prune_output=$(git remote prune $origin_name 2>&1)

        echo -e "${YELLOW}Select which remote branch to merge into '${current_branch}'${ENDCOLOR}"
        
        choose_branch "remote"

        merge_branch=${branch_name}
        merge_from_origin=true
        echo

    else
        echo -e "${YELLOW}Select which branch to merge into '${current_branch}'${ENDCOLOR}"
        choose_branch "merge"
        merge_branch=${branch_name}
        echo
    fi


    ### Fetch before merge (skip if already fetched for remote mode)
    if [ -z "$remote" ]; then
        echo -e "${YELLOW}Checking for remote changes...${ENDCOLOR}"
        
        # Get the current local commit hash for the branch
        local_commit=""
        if git show-ref --verify --quiet refs/heads/$merge_branch; then
            local_commit=$(git rev-parse refs/heads/$merge_branch 2>/dev/null)
        fi
        
        # Get the remote commit hash
        remote_commit=$(git ls-remote $origin_name refs/heads/$merge_branch 2>/dev/null | cut -f1)
        
        if [ -z "$remote_commit" ]; then
            echo -e "${YELLOW}Remote branch ${origin_name}/${merge_branch} not found - proceeding with local merge${ENDCOLOR}"
        elif [ "$local_commit" != "$remote_commit" ]; then
            echo -e "${YELLOW}Remote changes detected!${ENDCOLOR}"
            echo
            echo -e "Do you want to fetch ${YELLOW}${origin_name}/${merge_branch}${ENDCOLOR} before merge (y/n)?"
            read -n 1 -s choice
            if [ "$choice" == "y" ]; then
                echo
                echo -e "${YELLOW}Fetching ${origin_name}/${merge_branch}...${ENDCOLOR}"

                fetch $merge_branch $origin_name
                merge_from_origin=true
            fi
        else
            echo -e "${GREEN}Local branch is up to date with remote${ENDCOLOR}"
        fi
        echo
    fi


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

    # Always get proper file statistics using git show for successful merges
    if [[ "$commit_message_after_merge" != "$commit_message_before_merge" ]]; then
        # New merge commit was created, show its changes
        commit_hash="$(git --no-pager log --pretty="%h" -1)"
        changes=$(git --no-pager show $commit_hash --stat --format="")
    else
        # Fast-forward merge, show changes between the old and new position
        old_commit=$(git reflog --format="%H" -n 2 | tail -n 1)
        new_commit=$(git rev-parse HEAD)
        changes=$(git --no-pager diff --stat $old_commit..$new_commit)
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
# $6: ff
# Returns:
#      * merge_output
#      * merge_code - 0 if everything is ok, not zero if there are conflicts
function merge {
    args=""
    if [ "$6" == "true" ]; then
        args="--ff-only"
    fi
    if [ "$5" == "true" ]; then
        merge_output=$(git merge $args $2/$1 2>&1)
    else
        merge_output=$(git merge $args $1 2>&1)
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

    if [[ $merge_output == *"possible to fast-forward"* ]]; then
        echo -e "${RED}Branches cannot be fast forwarded!${ENDCOLOR}"
        echo -e "You should use merge or rebase"
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
    default_message="Merge branch '$2/$1' into '$current_branch'"
    echo -e "${YELLOW}You should resolve conflicts manually${ENDCOLOR}"
    echo -e "After resolving, select an option to continue"
    echo -e "1. Create a merge commit with a generated message:"
    printf "\t${YELLOW}${default_message}${ENDCOLOR}\n"
    echo -e "2. Create a merge commit with an entered message"
    echo -e "3. Abort merge and return to the original state: ${YELLOW}git merge --abort${ENDCOLOR}"
    echo -e "4. Accept all incoming changes: ${GREEN}git checkout --theirs .${ENDCOLOR}"
    echo -e "5. Accept all current changes: ${GREEN}git checkout --ours .${ENDCOLOR}"
    echo -e "0. Exit from this script ${BOLD}without${NORMAL} merge abort"

    ### Print files with conflicts
    echo
    echo -e "${YELLOW}Files with conflicts${ENDCOLOR}"
    IFS=$'\n' read -rd '' -a files_with_conflicts <<<"$(git --no-pager diff --name-only --diff-filter=U --relative)"
    for file in "${files_with_conflicts[@]}"; do
        echo -e "\t$file"
    done

    ### Merge process
    while [ true ]; do
        read -n 1 -s choice

        if [ "$choice" == "1" ] || [ "$choice" == "2" ]; then
            merge_commit $choice "${files_with_conflicts[@]}" "${default_message}" $1 $2 $3
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

        if [ "$choice" == "4" ]; then
            echo
            echo -e "Are you sure you want to ${GREEN}accept all incoming changes${ENDCOLOR} and discard current changes (y/n)?"
            read -n 1 -s choice_yes
            if [ "$choice_yes" == "y" ]; then
                echo
                echo -e "${YELLOW}Accepting all incoming changes...${ENDCOLOR}"
                
                # Check for deleted files in conflicts
                deleted_files=$(git --no-pager diff --name-only --diff-filter=D --relative 2>/dev/null)
                if [ -n "$deleted_files" ]; then
                    echo -e "${YELLOW}Warning: Some files were deleted in the incoming branch:${ENDCOLOR}"
                    echo "$deleted_files" | sed 's/^/\t/'
                    echo
                    echo -e "Do you want to continue and accept the deletions (y/n)?"
                    read -n 1 -s choice_delete
                    if [ "$choice_delete" != "y" ]; then
                        echo -e "${YELLOW}Cancelled. Continuing...${ENDCOLOR}"
                        continue
                    fi
                fi
                
                # Accept all incoming changes (theirs) with better error handling
                checkout_output=$(git checkout --theirs . 2>&1)
                checkout_code=$?
                
                if [ $checkout_code -ne 0 ]; then
                    echo -e "${RED}Failed to accept incoming changes:${ENDCOLOR}"
                    echo "$checkout_output"
                    echo
                    echo -e "${YELLOW}This might be due to deleted files. You can:${ENDCOLOR}"
                    echo -e "1. Manually resolve conflicts and stage files"
                    echo -e "2. Try again (if you want to force accept)"
                    echo -e "3. Abort merge"
                    echo
                    echo -e "What would you like to do (1/2/3)?"
                    read -n 1 -s choice_resolve
                    if [ "$choice_resolve" == "1" ]; then
                        echo -e "${YELLOW}Please manually resolve conflicts and stage files, then return to this menu.${ENDCOLOR}"
                        continue
                    elif [ "$choice_resolve" == "2" ]; then
                        echo -e "${YELLOW}Force accepting incoming changes...${ENDCOLOR}"
                        # Force remove files that don't exist in theirs
                        git ls-files --deleted | xargs -r git rm 2>/dev/null
                        git checkout --theirs . 2>/dev/null
                        git add .
                    elif [ "$choice_resolve" == "3" ]; then
                        echo -e "${YELLOW}Aborting merge...${ENDCOLOR}"
                        git merge --abort
                        exit $?
                    else
                        continue
                    fi
                fi
                
                # Add all changes and create merge commit
                git add .
                
                echo -e "${YELLOW}Creating merge commit with accepted incoming changes...${ENDCOLOR}"
                commit_result=$(git commit -m "$default_message" 2>&1)
                commit_code=$?
                
                if [ $commit_code -eq 0 ]; then
                    echo -e "${GREEN}Successfully accepted all incoming changes and created merge commit!${ENDCOLOR}"
                    return
                else
                    echo -e "${RED}Failed to create merge commit:${ENDCOLOR}"
                    echo "$commit_result"
                    exit $commit_code
                fi
            else
                echo -e "${YELLOW}Continuing...${ENDCOLOR}"
            fi
            continue
        fi

        if [ "$choice" == "5" ]; then
            echo
            echo -e "Are you sure you want to ${GREEN}accept all current changes${ENDCOLOR} and discard incoming changes (y/n)?"
            read -n 1 -s choice_yes
            if [ "$choice_yes" == "y" ]; then
                echo
                echo -e "${YELLOW}Accepting all current changes...${ENDCOLOR}"
                
                # Check for deleted files in conflicts
                deleted_files=$(git --no-pager diff --name-only --diff-filter=D --relative 2>/dev/null)
                if [ -n "$deleted_files" ]; then
                    echo -e "${YELLOW}Warning: Some files were deleted in the current branch:${ENDCOLOR}"
                    echo "$deleted_files" | sed 's/^/\t/'
                    echo
                    echo -e "Do you want to continue and accept the deletions (y/n)?"
                    read -n 1 -s choice_delete
                    if [ "$choice_delete" != "y" ]; then
                        echo -e "${YELLOW}Cancelled. Continuing...${ENDCOLOR}"
                        continue
                    fi
                fi
                
                # Accept all current changes (ours) with better error handling
                checkout_output=$(git checkout --ours . 2>&1)
                checkout_code=$?
                
                if [ $checkout_code -ne 0 ]; then
                    echo -e "${RED}Failed to accept current changes:${ENDCOLOR}"
                    echo "$checkout_output"
                    echo
                    echo -e "${YELLOW}This might be due to deleted files. You can:${ENDCOLOR}"
                    echo -e "1. Manually resolve conflicts and stage files"
                    echo -e "2. Try again (if you want to force accept)"
                    echo -e "3. Abort merge"
                    echo
                    echo -e "What would you like to do (1/2/3)?"
                    read -n 1 -s choice_resolve
                    if [ "$choice_resolve" == "1" ]; then
                        echo -e "${YELLOW}Please manually resolve conflicts and stage files, then return to this menu.${ENDCOLOR}"
                        continue
                    elif [ "$choice_resolve" == "2" ]; then
                        echo -e "${YELLOW}Force accepting current changes...${ENDCOLOR}"
                        # Force remove files that don't exist in ours
                        git ls-files --deleted | xargs -r git rm 2>/dev/null
                        git checkout --ours . 2>/dev/null
                        git add .
                    elif [ "$choice_resolve" == "3" ]; then
                        echo -e "${YELLOW}Aborting merge...${ENDCOLOR}"
                        git merge --abort
                        exit $?
                    else
                        continue
                    fi
                fi
                
                # Add all changes and create merge commit
                git add .
                
                echo -e "${YELLOW}Creating merge commit with accepted current changes...${ENDCOLOR}"
                commit_result=$(git commit -m "$default_message" 2>&1)
                commit_code=$?
                
                if [ $commit_code -eq 0 ]; then
                    echo -e "${GREEN}Successfully accepted all current changes and created merge commit!${ENDCOLOR}"
                    return
                else
                    echo -e "${RED}Failed to create merge commit:${ENDCOLOR}"
                    echo "$commit_result"
                    exit $commit_code
                fi
            else
                echo -e "${YELLOW}Continuing...${ENDCOLOR}"
            fi
            continue
        fi

        if [ "$choice" == "0" ]; then
            exit
        fi
    done
    
    echo
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
    files_with_conflicts_one_line="$(echo "$2" | tr '\n' ' ' | sed 's/ $//')"
    files_with_conflicts_new="$(git --no-pager grep -l --name-only -E "[<=>]{7} HEAD" $files_with_conflicts_one_line)"
    if [ "$files_with_conflicts_new" != "" ]; then
        echo
        echo -e "${YELLOW}There are files with conflicts${ENDCOLOR}"
        echo -e "$(echo -e "${files_with_conflicts_new}" | tr ' ' '\n' | sed 's/^/\t/')"

        echo
        echo -e "Fix conflicts and press ${YELLOW}$1${ENDCOLOR} for one more time"
        merge_error="true"
        return
    fi


    ### Add all files that were in conflict to commit (they should be resolved now)
    echo
    echo -e "${YELLOW}Adding resolved files to commit...${ENDCOLOR}"
    
    # Add all modified files (this includes the resolved conflict files)
    git add -u

    ### 1. Commit with default message
    if [ "$1" == "1" ]; then
        commit_message="$3"
        result=$(git commit -m "$commit_message" 2>&1)
        commit_status=$?
        if [[ $result != *"not staged for commit"* ]]; then
            check_code $commit_status "$result" "creating default merge commit"
        fi  
        

    ### 2. Commit with entered message
    else
        staged_with_tab="$(sed 's/^/####\t/' <<< "$2")"
        commitmsg_file=$(mktemp "/tmp/commitmsg.XXXXXX")
        echo """
####
#### Write a message about merge from '$5/$4' into '$4'. Lines starting with '#' will be ignored. 
#### 
#### On branch $4
#### Changes to be commited:
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
                rm -f "$commitmsg_file"
                merge_error="true"
                exit
            fi    
        done

        rm -f "$commitmsg_file"
        
        result=$(git commit -m """$commit_message""" 2>&1)

        if [[ $result != *"not staged for commit"* ]]; then
            check_code $? "$result" "creating merge commit"
        fi  
    fi
}

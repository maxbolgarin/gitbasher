#!/usr/bin/env bash

### Script for rebasing commits
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Main function
# $1: mode
    # empty: select base branch to rebase current changes
    # main: rebase current branch onto default branch
    # interactive: select base commit in current branch and rebase in an interactive mode
    # autosquash: rebase on current branch in an interactive mode with --autosquash
    # pull: take all commits from selected branch and apply them to current branch
function rebase_script {
    case "$1" in
        main|master|m)           main="true";;
        interactive|i)           interactive="true";;
        autosquash|a|s|ia)        autosquash="true";;
        fastautosquash|fast|sf|f) fastautosquash="true";;
        pull|p)                  pull_commits="true";;
        help|h)                  help="true";;
        *)
            wrong_mode "rebase" $1
    esac

    ### Merge mode - print header
    header="GIT REBASE"
    if [ -n "${interactive}" ]; then
        header="$header INTERACTIVE"
    elif [ -n "${autosquash}" ]; then
        header="$header AUTOSQUASH"
    elif [ -n "${fastautosquash}" ]; then
        header="$header FAST AUTOSQUASH"
    elif [ -n "${main}" ]; then
        header="$header MAIN"
    elif [ -n "${pull_commits}" ]; then
        header="$header PULL COMMITS"
    fi
    echo -e "${YELLOW}${header}${ENDCOLOR}"
    echo


    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb rebase <mode>${ENDCOLOR}"
        echo
        msg="${YELLOW}Mode${ENDCOLOR}_${GREEN}Aliases${ENDCOLOR}_\t${BLUE}Description${ENDCOLOR}"
        msg="$msg\n${BOLD}<empty>${ENDCOLOR}_ _Select base branch to rebase current changes"
        msg="$msg\n${BOLD}main${ENDCOLOR}_master|m_Rebase current branch onto default branch"
        msg="$msg\n${BOLD}interactive${ENDCOLOR}_i_Select base commit in current branch and rebase in an interactive mode"
        msg="$msg\n${BOLD}autosquash${ENDCOLOR}_a|s|ia_Rebase on the current local branch in an interactive mode with --autosquash"
        msg="$msg\n${BOLD}fastautosquash${ENDCOLOR}_fast|sf|f_Fast autosquash rebase - automatically merge fixup commits without interaction"
        msg="$msg\n${BOLD}pull${ENDCOLOR}_p_Take all commits from selected branch and apply them to current branch"
        msg="$msg\n${BOLD}help${ENDCOLOR}_h_Show this help"
        echo -e "$(echo -e "$msg" | column -ts'_')"
        echo
        echo -e "${YELLOW}Conflict resolution options (available during rebase conflicts):${ENDCOLOR}"
        echo -e "Accept all incoming changes\tResolve all conflicts by accepting changes from the target branch"
        echo -e "Accept all current changes\tResolve all conflicts by keeping changes from your current branch"
        exit
    fi


    ### Check current branch for remote changes (skip for autosquash modes as they work on local commits)
    if [ -z "$autosquash" ] && [ -z "$fastautosquash" ]; then
        echo -e "${YELLOW}Checking current branch for remote changes...${ENDCOLOR}"
        
        # Get the current local commit hash for current branch
        current_local_commit=$(git rev-parse HEAD 2>/dev/null)
        
        # Get the remote commit hash for current branch
        current_remote_commit=$(git ls-remote $origin_name refs/heads/$current_branch 2>/dev/null | cut -f1)
        
        if [ -z "$current_remote_commit" ]; then
            echo -e "${YELLOW}Remote branch ${origin_name}/${current_branch} not found - proceeding with local rebase${ENDCOLOR}"
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


    is_clean=$(git status | tail -n 1)
    if [ "$is_clean" != "nothing to commit, working tree clean" ]; then
        echo -e "${RED}Cannot rebase! There are uncommited changes:"
        git_status
        exit 1
    fi


    ### Handle pull commits mode - take all commits from another branch
    if [ -n "$pull_commits" ]; then
        echo -e "${YELLOW}Select branch to pull commits from into '${current_branch}'${ENDCOLOR}"
        choose_branch "pull commits from"
        source_branch=${branch_name}
        echo

        # Check if source branch exists
        if ! git show-ref --verify --quiet refs/heads/$source_branch; then
            echo -e "${RED}Source branch '${source_branch}' does not exist locally${ENDCOLOR}"
            exit 1
        fi

        # Check if source branch is the same as current branch
        if [ "$source_branch" == "$current_branch" ]; then
            echo -e "${YELLOW}Source and target branches are the same${ENDCOLOR}"
            exit
        fi

        # Find commits that are in source branch but not in current branch
        commits_to_pull=$(git rev-list $current_branch..$source_branch --reverse 2>/dev/null)
        
        if [ -z "$commits_to_pull" ]; then
            echo -e "${GREEN}No new commits to pull from '${source_branch}'${ENDCOLOR}"
            exit
        fi

        # Show commits that will be pulled
        commit_count=$(echo "$commits_to_pull" | wc -l | tr -d ' ')
        echo -e "${YELLOW}Found ${commit_count} commits to pull from '${source_branch}':${ENDCOLOR}"
        echo
        
        # Show commits with details
        commits_to_pull_with_dates=$(git log -n 10 --oneline --format="${YELLOW}%h${ENDCOLOR} (${BLUE}%cr${ENDCOLOR}) ${BOLD}%s${ENDCOLOR}" $current_branch..$source_branch --reverse)
        echo -e "$commits_to_pull_with_dates" | sed 's/^/\t/'
        if [ "$commit_count" -gt 10 ]; then
            echo -e "\t${YELLOW}... and $((commit_count - 10)) more commits${ENDCOLOR}"
        fi
        echo

        # Ask for confirmation
        echo -e "Proceed with pulling ${commit_count} commits from '${source_branch}' to '${current_branch}' (y/n/0)?"
        read -n 1 -s choice
        if [ "$choice" == "0" ]; then
            exit
        fi
        if [ "$choice" != "y" ]; then
            echo
            echo -e "${YELLOW}Pull commits cancelled${ENDCOLOR}"
            exit
        fi
        echo

        # Cherry-pick all commits
        pull_commits_from_branch "$source_branch" "$commits_to_pull"
        exit
    fi


    ### Select branch which will become a base
    if [ -n "$main" ]; then
        if [ "$current_branch" == "${main_branch}" ]; then
            echo -e "${YELLOW}Already on ${main_branch}${ENDCOLOR}"
            exit
        fi
        new_base_branch=${main_branch}

    elif [ -n "$autosquash" ] || [ -n "$fastautosquash" ]; then
        new_base_branch=${current_branch}
    else
        echo -e "${YELLOW}Select which branch will become a new base for '${current_branch}'${ENDCOLOR}"
        choose_branch "rebase"
        new_base_branch=${branch_name}
        echo
    fi

    if [ -z "$autosquash" ] && [ -z "$fastautosquash" ]; then
        ### Check target branch for remote changes before rebase
        echo -e "${YELLOW}Checking target branch for remote changes...${ENDCOLOR}"
        
        # Get the current local commit hash for the target branch
        local_commit=""
        if git show-ref --verify --quiet refs/heads/$new_base_branch; then
            local_commit=$(git rev-parse refs/heads/$new_base_branch 2>/dev/null)
        fi
        
        # Get the remote commit hash for target branch
        remote_commit=$(git ls-remote $origin_name refs/heads/$new_base_branch 2>/dev/null | cut -f1)
        
        if [ -z "$remote_commit" ]; then
            echo -e "${YELLOW}Remote branch ${origin_name}/${new_base_branch} not found - proceeding with local rebase${ENDCOLOR}"
        elif [ "$local_commit" != "$remote_commit" ]; then
            echo -e "${YELLOW}Remote changes detected in target branch!${ENDCOLOR}"
            echo
            echo -e "Do you want to fetch ${YELLOW}${origin_name}/${new_base_branch}${ENDCOLOR} before rebase (y/n/0)?"
            read -n 1 -s choice
            if [ "$choice" == "0" ]; then
                exit
            fi
            if [ "$choice" == "y" ]; then
                echo
                echo -e "${YELLOW}Fetching ${origin_name}/${new_base_branch}...${ENDCOLOR}"

                fetch $new_base_branch $origin_name
                from_origin=true
            fi
        else
            echo -e "${GREEN}Target branch is up to date with remote${ENDCOLOR}"
        fi
        echo
    fi


    ### Run rebase and handle conflicts

    rebase_branch "$new_base_branch" "$origin_name" "$from_origin" "$interactive" "$autosquash" "$autosquash" "$fastautosquash"


    ### Nothing to rebase
    if [[ $rebase_output == *"is up to date"* ]]; then
        echo -e "${GREEN}Nothing to rebase - already up to date${ENDCOLOR}"
        exit
    fi

    if [ $rebase_code == 0 ] ; then
        echo -e "${GREEN}Successful rebase!${ENDCOLOR}"
        echo -e "${BLUE}[${new_base_branch}${ENDCOLOR} -> ${BLUE}${current_branch}]${ENDCOLOR}"
    else
        echo -e "${RED}Cannot rebase! Error message:${ENDCOLOR}"
        echo -e "$rebase_output"
    fi
}


### Function rebases current branch to the provided one
# $1: new base branch name
# $2: origin name
# $3: is from origin?
# $4: interactive
# $5: autosquash
# $6: is select base commit for autosquash
# $7: fastautosquash
# Returns:
#      * rebase_output
#      * rebase_code - 0 if everything is ok, not zero if there are conflicts
function rebase_branch {
    ref=$1
    if [ "$3" == "true" ]; then
        ref=$2/$1
    fi

    if [ "$7" == "true" ]; then
        # Fast autosquash mode - automatically determine base commit
        echo -e "${YELLOW}Finding fixup commits to squash automatically...${ENDCOLOR}"
        
        # Try to find merge-base with main branch first
        merge_base=$(git merge-base HEAD ${main_branch} 2>/dev/null)
        if [ -n "$merge_base" ] && [ "$merge_base" != "$(git rev-parse HEAD)" ]; then
            ref="$merge_base"
            echo -e "${YELLOW}Using merge-base with ${main_branch}: ${ref::7}${ENDCOLOR}"
        else
            # Fall back to HEAD~50 or the root commit if less than 50 commits
            commit_count=$(git rev-list --count HEAD 2>/dev/null || echo "0")
            if [ "$commit_count" -gt 50 ]; then
                ref="HEAD~50"
                echo -e "${YELLOW}Using HEAD~50 as base commit${ENDCOLOR}"
            else
                # Use root commit
                ref=$(git rev-list --max-parents=0 HEAD 2>/dev/null | tail -1)
                if [ -n "$ref" ]; then
                    echo -e "${YELLOW}Using root commit: ${ref::7}${ENDCOLOR}"
                else
                    ref="HEAD~10"  # fallback
                    echo -e "${YELLOW}Using HEAD~10 as fallback base commit${ENDCOLOR}"
                fi
            fi
        fi
        
        # Check if there are any fixup commits
        fixup_commits=$(git log --oneline --grep="^fixup!" $ref..HEAD 2>/dev/null || echo "")
        if [ -z "$fixup_commits" ]; then
            echo -e "${GREEN}No fixup commits found to squash${ENDCOLOR}"
            rebase_code=0
            rebase_output="No fixup commits to squash"
            return
        fi
        
        echo -e "${GREEN}Found fixup commits:${ENDCOLOR}"
        # Show commits with relative dates
        fixup_commits_with_dates=$(git log --format="${YELLOW}%h${ENDCOLOR} (${BLUE}%cr${ENDCOLOR}) ${BOLD}%s${ENDCOLOR}" --grep="^fixup!" $ref..HEAD 2>/dev/null || echo "")
        echo -e "$fixup_commits_with_dates" | sed 's/^/\t/'
        echo
        
        # Ask for confirmation before proceeding
        echo -e "Proceed with fast autosquash rebase (y/n/0)?"
        read -n 1 -s choice
        if [ "$choice" == "0" ]; then
            exit
        fi
        if [ "$choice" != "y" ]; then
            echo
            echo -e "${YELLOW}Rebase cancelled${ENDCOLOR}"
            exit
        fi
        echo
        echo -e "${YELLOW}Proceeding with fast autosquash rebase...${ENDCOLOR}"
        echo
        
        # Run fast autosquash with non-interactive editor
        rebase_output=$(GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash $ref 3>&2 2>&1 1>&3)

    elif [ "$5" == "true" ]; then
        if [ "$6" == "true" ]; then
            echo -e "Select a new ${BOLD}base${NORMAL} commit from which to squash fixup commits (third one or older):"
            choose_commit 20 "number" $ref
            ref="$commit_hash"
        fi
        
        rebase_output=$(git rebase -i --autosquash $ref 3>&2 2>&1 1>&3)

    elif [ "$4" == "true" ]; then
        rebase_output=$(git rebase -i $ref 3>&2 2>&1 1>&3)
    else
        rebase_output=$(git rebase $ref 3>&2 2>&1 1>&3)
    fi

    rebase_code=$?

    if [ $rebase_code == 0 ] ; then
        return
    fi

    ### Cannot rebase because there are uncommitted files
    if [[ $rebase_output == *"Please commit or stash them"* ]]; then
        echo -e "${RED}Cannot rebase! There are uncommited changes:"
        git_status
        exit $rebase_code
    fi

    ### Cannot rebase because there are uncommitted files
    if [[ $rebase_output == *"error: invalid"* ]]; then
        rebase_todo_errors "$rebase_output"
        echo
    fi

    ### Cannot rebase because of conflicts
    if [[ $rebase_output == *"Resolve all conflicts manually"* ]] || [[ $rebase_output == *"previous cherry-pick is now empty"* ]]; then
        echo -e "${RED}Cannot rebase! There are conflicts${ENDCOLOR}"
        rebase_conflicts $rebase_output 
        echo
    fi

    ### Cannot rebase because of some error
    if [[ $rebase_output != *"Successfully rebased"* ]]; then
        echo -e "${RED}Cannot rebase! Error message:${ENDCOLOR}"
        echo "$rebase_output"
        exit $rebase_code
    fi
}

### Function helps to fix errors in todo plan
# $1: rebase_output
# $2: conflicts fix mode
function rebase_todo_errors {
    rebase_output=$1
    output_to_print=$1
    while [ true ]; do
        echo -e "${RED}Cannot rebase! Your rebase plan has errors:${ENDCOLOR}"
        echo "$(sed '$d' <<< $output_to_print)"
        echo
        echo -e "${YELLOW}You should fix errors${ENDCOLOR}"
        echo -e "1. Open editor to change rebase plan: ${BLUE}git rebase --edit-todo${ENDCOLOR}"
        echo -e "2. Abort rebase and return to the original state: ${YELLOW}git rebase --abort${ENDCOLOR}"
        echo -e "0. Exit from this script ${BOLD}without${NORMAL} rebase abort"

        while [ true ]; do
            read -n 1 -s choice
            re='^[012]+$'
            if [[ $choice =~ $re ]]; then
                break
            fi
        done

        if [ "$choice" == "1" ]; then
            todo_output=$(git rebase --edit-todo 3>&2 2>&1 1>&3)
            rebase_output=$(git rebase --continue 2>&1)
            rebase_code=$?

        elif [ "$choice" == "2" ]; then
            echo
            echo -e "${YELLOW}Aborting rebase...${ENDCOLOR}"
            git rebase --abort
            exit

        elif [ "$choice" == "0" ]; then
            exit $rebase_code
        fi

        if [ "$2" != "" ] ; then
            output_to_print=$todo_output
            if [[ $todo_output != *"can fix this with"* ]]; then
                break
            fi
        else
            output_to_print=$rebase_output
            if [[ $rebase_output != *"error: invalid"* ]]; then
                break
            fi
        fi
        
        echo
    done
}

### Function pulls provided branch, handles errors and makes a merge
# $1: rebase_output
function rebase_conflicts {
    ### Ask user what he wants to do
    
    print_menu="true"
    new_step="true"
    rebase_output=$1

    ### Rebase process
    while [ true ]; do
        if [ "$print_menu" == "true" ]; then
            echo
            echo -e "${YELLOW}You should resolve conflicts manually${ENDCOLOR}"
            echo -e "After resolving, select an option to continue"
            echo -e "1. Add changes and continue: ${YELLOW}git rebase --continue${ENDCOLOR}"
            echo -e "2. Open editor to change rebase plan: ${BLUE}git rebase --edit-todo${ENDCOLOR}"
            echo -e "3. Throw away the commit from the history: ${RED}git rebase --skip${ENDCOLOR}"
            echo -e "4. Abort rebase and return to the original state: ${YELLOW}git rebase --abort${ENDCOLOR}"
            echo -e "5. Accept all incoming changes: ${GREEN}git checkout --theirs .${ENDCOLOR}"
            echo -e "6. Accept all current changes: ${GREEN}git checkout --ours .${ENDCOLOR}"
            echo -e "0. Exit from this script ${BOLD}without${NORMAL} rebase abort"

            print_menu="false"
        fi

        if [ "$new_step" == "true" ]; then
            status=$(git status)
            current_step=$(echo "$status" | sed -n 's/.*Last commands done (\([0-9]*\) commands done):/\1/p')
            if [ "$current_step" == "" ]; then
                current_step=$(echo "$status" | sed -n 's/.*Last command done (\([0-9]*\) command done):/\1/p')
            fi
            remaining_steps=$(echo "$status" | sed -n 's/.*Next commands to do (\([0-9]*\) remaining commands):/\1/p')
            total_steps=$((current_step + remaining_steps))
            commit_name=$(echo "$status" | sed -n '/done):/,/Next command/p' | sed 's/^[ \t]*//;s/[ \t]*$//' | sed '/^[LN(]/d' | tail -n 1 )
            commit_name=$(echo "$commit_name" | sed 's/^[ \t]*//;s/[ \t]*$//' | sed "s/\([a-z]* [0-9a-f]*\)/${BLUE_ES}\[\1\]${ENDCOLOR_ES}/")
            files=$(echo "$status" | sed -n '/^Unmerged paths:/,/^$/p' | sed '/^Unmerged paths:/d;/^$/d;/^ *(/d')
            files=$(sed "s/\(.*\)both modified:/\1${YELLOW_ES}modified:${ENDCOLOR_ES}/" <<< "${files}")
            files=$(sed "s/\(.*\)both added:/\1${YELLOW_ES}added:${ENDCOLOR_ES}/" <<< "${files}")

            echo
            echo -e "${GREEN}Step $current_step/$total_steps:${ENDCOLOR} $commit_name"
            if [ "$files" != "" ]; then
                echo -e "$files"
            else
                echo
                echo -e "${YELLOW}The previous commit is now empty due to conflict resolution${ENDCOLOR}"
                echo -e "${GREEN}You can skip this commit by pressing ${BOLD}3${ENDCOLOR}"
                force_skip="true"
            fi

            new_step="false"
        fi

        while [ true ]; do
            read -n 1 -s choice
            re='^[0123456]+$'
            if [[ $choice =~ $re ]]; then
                break
            fi
        done

        if [ "$choice" == "1" ]; then
            files_with_conflicts_one_line="$(tr '\n' ' ' <<< "$(git --no-pager diff --name-only --diff-filter=U --relative)")"
            
            if [ -n "$files_with_conflicts_one_line" ] && [ "$files_with_conflicts_one_line" != " " ]; then
                files_with_conflicts_new="$(git grep -l --name-only -E "[<=>]{7}" $files_with_conflicts_one_line 2>/dev/null || echo "")"
                
                if [ "$files_with_conflicts_new" != "" ]; then
                    echo
                    echo -e "${YELLOW}There are files with conflicts${ENDCOLOR}"
                    echo -e "$(echo -e "${files_with_conflicts_new}" | tr ' ' '\n' | sed 's/^/\t/')"
                    continue
                fi
            fi
           
            git add .

            rebase_output=$(git -c core.editor=true rebase --continue 2>&1)
            rebase_code=$?

            if [[ $rebase_output == *"Successfully rebased"* ]]; then
                return
            fi

            if [[ $rebase_output != *"CONFLICT"* ]]; then
                echo -e "${RED}Cannot rebase! Error message:${ENDCOLOR}"
                echo "$rebase_output"
                exit $rebase_code
            fi
            new_step="true"
            continue
        fi

        if [ "$choice" == "2" ]; then
            todo_output=$(git rebase --edit-todo 3>&2 2>&1 1>&3)
            rebase_output=$(git rebase --continue 2>&1)

            if [[ $todo_output == *"error: invalid"* ]]; then
                echo
                rebase_todo_errors "$todo_output" "true"
                print_menu="true"
                new_step="true"
            fi

            echo
            echo -e "${YELLOW}Successfull plan edit, continuing...${ENDCOLOR}"
            
            continue
        fi

        if [ "$choice" == "3" ]; then
            if [ "$force_skip" != "true" ]; then
                echo
                echo -e "Are you sure you want to ${RED}skip${ENDCOLOR} commit and ${RED}throw it away${ENDCOLOR} (y/n)?"
                read -n 1 -s choice_yes
                if [ "$choice_yes" != "y" ]; then
                    echo -e "${YELLOW}Continuing...${ENDCOLOR}"
                    continue
                fi
            fi
            
            force_skip="false"

            rebase_output=$(git rebase --skip 2>&1)
            rebase_code=$?

            if [[ $rebase_output == *"Successfully rebased"* ]]; then
                echo
                return
            fi

            echo -e "${YELLOW}Skipping commit${ENDCOLOR}"
            new_step="true"
            continue
        fi


        if [ "$choice" == "4" ]; then
            echo
            echo -e "Are you sure you want to ${YELLOW}abort rebase${ENDCOLOR} (y/n)?"
            read -n 1 -s choice_yes
            if [ "$choice_yes" == "y" ]; then
                echo
                echo -e "${YELLOW}Aborting rebase...${ENDCOLOR}"
                git rebase --abort
                exit $?
            else
                echo -e "${YELLOW}Continuing...${ENDCOLOR}"
            fi
            continue
        fi

        if [ "$choice" == "5" ]; then
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
                    echo -e "3. Abort rebase"
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
                        echo -e "${YELLOW}Aborting rebase...${ENDCOLOR}"
                        git rebase --abort
                        exit $?
                    else
                        continue
                    fi
                fi
                
                # Add all changes and continue
                git add .
                
                rebase_output=$(git -c core.editor=true rebase --continue 2>&1)
                rebase_code=$?

                if [[ $rebase_output == *"Successfully rebased"* ]]; then
                    echo -e "${GREEN}Successfully accepted all incoming changes and continued rebase!${ENDCOLOR}"
                    return
                fi

                if [[ $rebase_output != *"CONFLICT"* ]]; then
                    echo -e "${RED}Cannot rebase! Error message:${ENDCOLOR}"
                    echo "$rebase_output"
                    exit $rebase_code
                fi
                
                echo -e "${GREEN}Accepted all incoming changes, moving to next conflict${ENDCOLOR}"
                new_step="true"
            else
                echo -e "${YELLOW}Continuing...${ENDCOLOR}"
            fi
            continue
        fi

        if [ "$choice" == "6" ]; then
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
                
                # Get list of conflicted files
                conflicted_files=$(git --no-pager diff --name-only --diff-filter=U --relative)
                
                if [ -n "$conflicted_files" ]; then
                    checkout_failed_files=""
                    
                    # Process each conflicted file individually
                    while IFS= read -r file; do
                        if [ -n "$file" ]; then
                            # Try to checkout our version of the file
                            checkout_output=$(git checkout --ours "$file" 2>&1)
                            checkout_code=$?
                            
                            if [ $checkout_code -ne 0 ]; then
                                # If checkout fails, the file doesn't have "our version"
                                # This typically means it was added by them but doesn't exist in our branch
                                # Remove it from the index to keep it deleted/non-existent
                                git rm --cached "$file" 2>/dev/null || git reset HEAD "$file" 2>/dev/null
                                checkout_failed_files="$checkout_failed_files\n\t$file (removed - didn't exist in our branch)"
                            fi
                        fi
                    done <<< "$conflicted_files"
                    
                    if [ -n "$checkout_failed_files" ]; then
                        echo -e "${YELLOW}Some files were removed because they don't exist in your current branch:${ENDCOLOR}"
                        echo -e "$checkout_failed_files"
                    fi
                else
                    echo -e "${YELLOW}No conflicted files found${ENDCOLOR}"
                fi
                
                # Add all changes and continue
                git add .
                
                rebase_output=$(git -c core.editor=true rebase --continue 2>&1)
                rebase_code=$?

                if [[ $rebase_output == *"Successfully rebased"* ]]; then
                    echo -e "${GREEN}Successfully accepted all current changes and continued rebase!${ENDCOLOR}"
                    return
                fi

                if [[ $rebase_output != *"CONFLICT"* ]]; then
                    echo -e "${RED}Cannot rebase! Error message:${ENDCOLOR}"
                    echo "$rebase_output"
                    exit $rebase_code
                fi
                
                echo -e "${GREEN}Accepted all current changes, moving to next conflict${ENDCOLOR}"
                new_step="true"
            else
                echo -e "${YELLOW}Continuing...${ENDCOLOR}"
            fi
            continue
        fi

        if [ "$choice" == "0" ]; then
            exit
        fi
    done
}


### Function to pull commits from another branch via cherry-pick
# $1: source branch name
# $2: commits to pull (newline separated commit hashes)
function pull_commits_from_branch {
    source_branch=$1
    commits=$2
    
    echo -e "${YELLOW}Pulling commits from '${source_branch}' to '${current_branch}'...${ENDCOLOR}"
    echo
    
    # Convert commits to array
    commit_array=()
    while IFS= read -r commit; do
        if [ -n "$commit" ]; then
            commit_array+=("$commit")
        fi
    done <<< "$commits"
    
    total_commits=${#commit_array[@]}
    current_commit_index=0
    
    # Cherry-pick each commit
    for commit_hash in "${commit_array[@]}"; do
        current_commit_index=$((current_commit_index + 1))
        
        # Get commit info
        commit_subject=$(git log --format="%s" -n 1 "$commit_hash" 2>/dev/null)
        commit_author=$(git log --format="%an" -n 1 "$commit_hash" 2>/dev/null)
        commit_date=$(git log --format="%cr" -n 1 "$commit_hash" 2>/dev/null)
        
        echo -e "${GREEN}Step $current_commit_index/$total_commits:${ENDCOLOR} ${BLUE}[${commit_hash::7}]${ENDCOLOR} $commit_subject"
        echo -e "\t${YELLOW}by $commit_author ($commit_date)${ENDCOLOR}"
        
        # Cherry-pick the commit
        cherry_pick_output=$(git cherry-pick "$commit_hash" 2>&1)
        cherry_pick_code=$?
        
        if [ $cherry_pick_code -eq 0 ]; then
            echo -e "\t${GREEN}✓ Applied successfully${ENDCOLOR}"
            echo
            continue
        fi
        
        # Handle cherry-pick conflicts - check for various conflict indicators
        if [[ $cherry_pick_output == *"CONFLICT"* ]] || [[ $cherry_pick_output == *"Automatic merge failed"* ]] || [[ $cherry_pick_output == *"fix conflicts"* ]]; then
            echo -e "\t${RED}✗ Conflicts detected${ENDCOLOR}"
            echo
            handle_cherry_pick_conflicts "$commit_hash" "$current_commit_index" "$total_commits" "$commit_subject"
            # After handling conflicts, check if we should continue to next commit
            echo
            continue
        fi

        # Handle other cherry-pick errors with sophisticated error detection
        handle_cherry_pick_error "$commit_hash" "$current_commit_index" "$total_commits" "$commit_subject" "$cherry_pick_output"
        echo
    done
    
    echo -e "${GREEN}Successfully pulled $total_commits commits from '${source_branch}' to '${current_branch}'!${ENDCOLOR}"
    echo -e "${BLUE}[${source_branch}${ENDCOLOR} -> ${BLUE}${current_branch}]${ENDCOLOR}"
}


### Function to handle cherry-pick errors (non-conflict)
# $1: commit hash
# $2: current commit index  
# $3: total commits
# $4: commit subject
# $5: cherry-pick output
function handle_cherry_pick_error {
    commit_hash=$1
    current_index=$2
    total_commits=$3
    commit_subject=$4
    cherry_pick_output=$5
    
    echo -e "\t${RED}✗ Cherry-pick failed${ENDCOLOR}"
    echo
    
    # Analyze the error type and provide contextual information
    if [[ $cherry_pick_output == *"is now empty"* ]]; then
        echo -e "${YELLOW}Issue:${ENDCOLOR} The commit is now empty"
        echo -e "${BLUE}[$current_index/$total_commits]${ENDCOLOR} ${BLUE}[${commit_hash::7}]${ENDCOLOR} $commit_subject"
        echo
        echo -e "${GRAY}This usually happens when:${ENDCOLOR}"
        echo -e "\t• The changes in this commit already exist in your current branch"
        echo -e "\t• Previous conflict resolutions have made this commit redundant"
        echo -e "\t• The commit only contained changes that are no longer relevant"
        echo
        echo -e "${YELLOW}Git suggests using:${ENDCOLOR}"
        echo -e "\t${GREEN}git commit --allow-empty${ENDCOLOR} to keep it anyway"
        echo -e "\t${GREEN}git cherry-pick --skip${ENDCOLOR} to skip it"
        
    elif [[ $cherry_pick_output == *"would be overwritten"* ]]; then
        echo -e "${YELLOW}Issue:${ENDCOLOR} Files would be overwritten"
        echo -e "${BLUE}[$current_index/$total_commits]${ENDCOLOR} ${BLUE}[${commit_hash::7}]${ENDCOLOR} $commit_subject"
        echo
        echo -e "${GRAY}This happens when:${ENDCOLOR}"
        echo -e "\t• You have uncommitted changes that conflict with this commit"
        echo -e "\t• Some files are in an unexpected state"
        echo
        # Extract file names from error
        overwritten_files=$(echo "$cherry_pick_output" | grep -E "^\s*[a-zA-Z0-9]" | grep -v "error:" | grep -v "hint:" | head -5)
        if [ -n "$overwritten_files" ]; then
            echo -e "${YELLOW}Affected files:${ENDCOLOR}"
            echo "$overwritten_files" | sed 's/^/\t/'
            echo
        fi
        
    elif [[ $cherry_pick_output == *"bad object"* ]] || [[ $cherry_pick_output == *"invalid"* ]]; then
        echo -e "${YELLOW}Issue:${ENDCOLOR} Invalid commit reference"
        echo -e "${BLUE}[$current_index/$total_commits]${ENDCOLOR} ${BLUE}[${commit_hash::7}]${ENDCOLOR} $commit_subject"
        echo
        echo -e "${GRAY}This happens when:${ENDCOLOR}"
        echo -e "\t• The commit hash is corrupted or doesn't exist"
        echo -e "\t• The repository is in an inconsistent state"
        echo -e "\t• There are issues with the git object database"
        
    else
        echo -e "${YELLOW}Issue:${ENDCOLOR} Unknown cherry-pick error"
        echo -e "${BLUE}[$current_index/$total_commits]${ENDCOLOR} ${BLUE}[${commit_hash::7}]${ENDCOLOR} $commit_subject"
        echo
        echo -e "${GRAY}Git error details:${ENDCOLOR}"
        # Clean up the error message and format it nicely
        cleaned_error=$(echo "$cherry_pick_output" | grep -v "hint:" | head -3)
        echo "$cleaned_error" | sed 's/^/\t/' | sed "s/error:/\t${RED}error:${ENDCOLOR}/"
    fi
    
    echo
    echo -e "${YELLOW}What would you like to do?${ENDCOLOR}"
    
    if [[ $cherry_pick_output == *"is now empty"* ]]; then
        echo -e "1. Keep empty commit: ${GREEN}git commit --allow-empty${ENDCOLOR}"
        echo -e "2. Skip this commit: ${YELLOW}git cherry-pick --skip${ENDCOLOR}"
        echo -e "3. Abort pull operation: ${RED}abort and reset${ENDCOLOR}"
        echo -e "0. Exit script"
    else
        echo -e "1. Skip this commit and continue: ${YELLOW}git cherry-pick --skip${ENDCOLOR}"
        echo -e "2. Abort pull operation: ${RED}abort and reset${ENDCOLOR}"
        echo -e "3. Show full git error details"
        echo -e "0. Exit script"
    fi
    
    while [ true ]; do
        read -n 1 -s choice
        
        if [[ $cherry_pick_output == *"is now empty"* ]]; then
            case "$choice" in
                1)
                    echo
                    echo -e "${YELLOW}Keeping empty commit...${ENDCOLOR}"
                    
                    # Get the original commit message to preserve it
                    original_message=$(git log --format="%s" -n 1 "$commit_hash" 2>/dev/null)
                    
                    # For empty cherry-pick state, we use git commit --allow-empty with the original message
                    commit_output=$(git commit --allow-empty -m "$original_message" 2>&1)
                    commit_code=$?
                    
                    if [ $commit_code -eq 0 ]; then
                        echo -e "\t${GREEN}✓ Empty commit preserved with original message${ENDCOLOR}"
                        return
                    else
                        echo -e "${RED}Failed to keep empty commit:${ENDCOLOR}"
                        echo "$commit_output" | sed 's/^/\t/'
                        echo
                        echo -e "${YELLOW}You may need to resolve this manually:${ENDCOLOR}"
                        echo -e "\t${BLUE}git commit --allow-empty${ENDCOLOR} (provide message manually)"
                        echo -e "\tOR ${BLUE}git cherry-pick --skip${ENDCOLOR} (to skip the commit)"
                        echo
                        continue
                    fi
                    ;;
                2)
                    echo
                    echo -e "${YELLOW}Skipping empty commit ${commit_hash::7}...${ENDCOLOR}"
                    git cherry-pick --skip 2>/dev/null
                    echo -e "\t${GREEN}✓ Commit skipped${ENDCOLOR}"
                    return
                    ;;
                3)
                    echo
                    echo -e "${YELLOW}Aborting pull commits operation...${ENDCOLOR}"
                    git cherry-pick --abort 2>/dev/null
                    git reset --hard HEAD~$((current_index - 1)) 2>/dev/null
                    exit 1
                    ;;
                0)
                    exit 1
                    ;;
            esac
        else
            case "$choice" in
                1)
                    echo
                    echo -e "${YELLOW}Skipping commit ${commit_hash::7}...${ENDCOLOR}"
                    git cherry-pick --abort 2>/dev/null
                    echo -e "\t${GREEN}✓ Commit skipped${ENDCOLOR}"
                    return
                    ;;
                2)
                    echo
                    echo -e "${YELLOW}Aborting pull commits operation...${ENDCOLOR}"
                    git cherry-pick --abort 2>/dev/null
                    git reset --hard HEAD~$((current_index - 1)) 2>/dev/null
                    exit 1
                    ;;
                3)
                    echo
                    echo -e "${YELLOW}Full git error details:${ENDCOLOR}"
                    echo "$cherry_pick_output" | sed 's/^/\t/'
                    echo
                    echo -e "Press any key to return to options..."
                    read -n 1 -s
                    echo
                    echo -e "${YELLOW}What would you like to do?${ENDCOLOR}"
                    echo -e "1. Skip this commit and continue: ${YELLOW}git cherry-pick --skip${ENDCOLOR}"
                    echo -e "2. Abort pull operation: ${RED}abort and reset${ENDCOLOR}"
                    echo -e "3. Show full git error details"
                    echo -e "0. Exit script"
                    ;;
                0)
                    exit 1
                    ;;
            esac
        fi
    done
}


### Function to handle cherry-pick conflicts
# $1: commit hash
# $2: current commit index  
# $3: total commits
# $4: commit subject
function handle_cherry_pick_conflicts {
    commit_hash=$1
    current_index=$2
    total_commits=$3
    commit_subject=$4
    print_menu="true"
    
    while [ true ]; do
        if [ "$print_menu" == "true" ]; then
            echo -e "${YELLOW}Resolve conflicts for commit ${commit_hash::7}${ENDCOLOR}"
            echo -e "${BLUE}[$current_index/$total_commits]${ENDCOLOR} $commit_subject"
            echo
            
            # Show conflicted files
            conflicted_files=$(git --no-pager diff --name-only --diff-filter=U --relative 2>/dev/null)
            if [ -n "$conflicted_files" ]; then
                echo -e "${YELLOW}Conflicted files:${ENDCOLOR}"
                echo "$conflicted_files" | sed 's/^/\t/'
                echo
            fi
            
            echo -e "After resolving conflicts, select an option:"
            echo -e "1. Add changes and continue: ${GREEN}git cherry-pick --continue${ENDCOLOR}"
            echo -e "2. Skip this commit: ${RED}git cherry-pick --skip${ENDCOLOR}"
            echo -e "3. Accept all incoming changes: ${GREEN}git checkout --theirs .${ENDCOLOR}"
            echo -e "4. Accept all current changes: ${GREEN}git checkout --ours .${ENDCOLOR}"
            echo -e "5. Abort pull operation: ${YELLOW}abort and reset${ENDCOLOR}"
            echo -e "0. Exit script"
            
            print_menu="false"
        fi
        
        read -n 1 -s choice
        
        case "$choice" in
            1)
                # Check if conflicts are resolved
                files_with_conflicts=$(git grep -l --name-only -E "[<=>]{7}" $(git --no-pager diff --name-only --diff-filter=U --relative) 2>/dev/null || echo "")
                
                if [ -n "$files_with_conflicts" ]; then
                    echo
                    echo -e "${YELLOW}There are still unresolved conflicts in:${ENDCOLOR}"
                    echo "$files_with_conflicts" | sed 's/^/\t/'
                    echo
                    continue
                fi
                
                git add .
                
                continue_output=$(git cherry-pick --continue 2>&1)
                continue_code=$?
                
                if [ $continue_code -eq 0 ]; then
                    echo
                    return
                else
                    echo
                    echo -e "${RED}Failed to continue cherry-pick:${ENDCOLOR}"
                    echo "$continue_output"
                    print_menu="true"
                fi
                ;;
            2)
                echo
                echo -e "Are you sure you want to ${RED}skip${ENDCOLOR} this commit (y/n)?"
                read -n 1 -s choice_yes
                if [ "$choice_yes" == "y" ]; then
                    echo
                    echo -e "${YELLOW}Skipping commit ${commit_hash::7}${ENDCOLOR}"
                    git cherry-pick --skip 2>/dev/null
                    return
                else
                    echo
                    echo -e "${YELLOW}Continuing...${ENDCOLOR}"
                fi
                ;;
            3)
                echo
                echo -e "Are you sure you want to ${GREEN}accept all incoming changes${ENDCOLOR} (y/n)?"
                read -n 1 -s choice_yes
                if [ "$choice_yes" == "y" ]; then
                    echo
                    echo -e "${YELLOW}Accepting all incoming changes...${ENDCOLOR}"
                    git checkout --theirs . 2>/dev/null
                    git add .
                    
                    continue_output=$(git cherry-pick --continue 2>&1)
                    if [ $? -eq 0 ]; then
                        echo -e "\t${GREEN}✓ Applied with incoming changes${ENDCOLOR}"
                        return
                    else
                        echo -e "${RED}Failed to continue:${ENDCOLOR}"
                        echo "$continue_output"
                        print_menu="true"
                    fi
                else
                    echo
                    echo -e "${YELLOW}Continuing...${ENDCOLOR}"
                fi
                ;;
            4)
                echo
                echo -e "Are you sure you want to ${GREEN}accept all current changes${ENDCOLOR} (y/n)?"
                read -n 1 -s choice_yes
                if [ "$choice_yes" == "y" ]; then
                    echo
                    echo -e "${YELLOW}Accepting all current changes...${ENDCOLOR}"
                    git checkout --ours . 2>/dev/null
                    git add .
                    
                    continue_output=$(git cherry-pick --continue 2>&1)
                    if [ $? -eq 0 ]; then
                        echo -e "\t${GREEN}✓ Applied with current changes${ENDCOLOR}"
                        return
                    else
                        echo -e "${RED}Failed to continue:${ENDCOLOR}"
                        echo "$continue_output"
                        print_menu="true"
                    fi
                else
                    echo
                    echo -e "${YELLOW}Continuing...${ENDCOLOR}"
                fi
                ;;
            5)
                echo
                echo -e "Are you sure you want to ${YELLOW}abort${ENDCOLOR} the pull operation (y/n)?"
                read -n 1 -s choice_yes
                if [ "$choice_yes" == "y" ]; then
                    echo
                    echo -e "${YELLOW}Aborting pull commits operation...${ENDCOLOR}"
                    git cherry-pick --abort 2>/dev/null
                    # Reset to state before any commits were applied
                    git reset --hard HEAD~$((current_index - 1)) 2>/dev/null
                    exit 1
                else
                    echo
                    echo -e "${YELLOW}Continuing...${ENDCOLOR}"
                fi
                ;;
            0)
                exit 1
                ;;
        esac
    done
    return
}


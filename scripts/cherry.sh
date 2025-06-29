#!/usr/bin/env bash

### Script for cherry-picking commits
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Main function
# $1: mode
    # empty: interactive mode to select commits from a branch
    # hash <commit-hash>: cherry-pick a specific commit by hash
    # range <from>..<to>: cherry-pick a range of commits
    # abort: abort current cherry-pick operation
    # continue: continue cherry-pick after resolving conflicts
function cherry_script {
    case "$1" in
        hash|hs)                hash_mode="true"; commit_hash="$2";;
        range|r)                range_mode="true"; commit_range="$2";;
        abort|a)                abort_mode="true";;
        continue|cont|c)        continue_mode="true";;
        help|h)                 help="true";;
        *)
            if [ -n "$1" ] && [[ ! "$1" =~ ^[a-f0-9]+$ ]]; then
                wrong_mode "cherry" $1
            elif [ -n "$1" ]; then
                # If argument looks like a commit hash, treat it as hash mode
                hash_mode="true"
                commit_hash="$1"
            else
                interactive_mode="true"
            fi
    esac

    ### Cherry-pick mode - print header
    header="GIT CHERRY-PICK"
    if [ -n "${hash_mode}" ]; then
        header="$header HASH"
    elif [ -n "${range_mode}" ]; then
        header="$header RANGE"
    elif [ -n "${abort_mode}" ]; then
        header="$header ABORT"
    elif [ -n "${continue_mode}" ]; then
        header="$header CONTINUE"
    elif [ -n "${interactive_mode}" ]; then
        header="$header INTERACTIVE"
    fi

    echo -e "${YELLOW}${header}${ENDCOLOR}"
    echo

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb cherry <mode> [args]${ENDCOLOR}"
        echo
        echo -e "${YELLOW}Available modes${ENDCOLOR}"
        echo -e "<empty>\t\t\tInteractive mode: select commits from a branch to cherry-pick"
        echo -e "\t\t\t(Use '=' to show all commits, space-separated numbers to select multiple)"
        echo -e "hash|hs <hash>\t\tCherry-pick a specific commit by its hash"
        echo -e "range|r <from>..<to>\tCherry-pick a range of commits (e.g., abc123..def456)"
        echo -e "<commit-hash>\t\tShorthand for cherry-pick by hash"
        echo -e "abort|a\t\t\tAbort current cherry-pick operation"
        echo -e "continue|cont|c\t\tContinue cherry-pick after resolving conflicts"
        echo -e "help|h\t\t\tShow this help"
        exit
    fi

    # Check if we're in the middle of a cherry-pick operation
    if [ -d ".git/sequencer" ]; then
        if [ -z "${continue_mode}" ] && [ -z "${abort_mode}" ]; then
            echo -e "${YELLOW}You are in the middle of a cherry-pick operation${ENDCOLOR}"
            echo -e "Use ${GREEN}gitb cherry continue${ENDCOLOR} to continue after resolving conflicts"
            echo -e "Use ${GREEN}gitb cherry abort${ENDCOLOR} to abort the operation"
            exit 1
        fi
    fi

    ### Handle abort mode
    if [ -n "${abort_mode}" ]; then
        if [ ! -d ".git/sequencer" ]; then
            echo -e "${YELLOW}No cherry-pick operation in progress${ENDCOLOR}"
            exit
        fi
        
        echo -e "${YELLOW}Aborting cherry-pick operation...${ENDCOLOR}"
        abort_output=$(git cherry-pick --abort 2>&1)
        check_code $? "$abort_output" "cherry-pick abort"
        
        echo -e "${GREEN}Cherry-pick operation aborted successfully${ENDCOLOR}"
        exit
    fi

    ### Handle continue mode
    if [ -n "${continue_mode}" ]; then
        if [ ! -d ".git/sequencer" ]; then
            echo -e "${YELLOW}No cherry-pick operation in progress${ENDCOLOR}"
            exit
        fi
        
        # Check if there are unresolved conflicts
        if git diff --name-only --diff-filter=U | grep -q .; then
            echo -e "${RED}There are still unresolved conflicts${ENDCOLOR}"
            echo -e "${YELLOW}Conflicted files:${ENDCOLOR}"
            git diff --name-only --diff-filter=U | sed 's/^/  /'
            echo
            echo -e "Resolve conflicts and then run ${GREEN}gitb cherry continue${ENDCOLOR} again"
            exit 1
        fi
        
        echo -e "${YELLOW}Continuing cherry-pick operation...${ENDCOLOR}"
        continue_output=$(git cherry-pick --continue 2>&1)
        continue_code=$?
        
        if [ $continue_code == 0 ]; then
            echo -e "${GREEN}Cherry-pick operation completed successfully${ENDCOLOR}"
            after_cherry_pick
        else
            handle_cherry_pick_conflicts "$continue_output" $continue_code
        fi
        exit
    fi

    ### Check for uncommitted changes (except in continue/abort/hash/range modes)
    if [ -z "${continue_mode}" ] && [ -z "${abort_mode}" ] && [ -z "${hash_mode}" ] && [ -z "${range_mode}" ]; then
        is_clean=$(git status --porcelain)
        if [ -n "$is_clean" ]; then
            echo -e "${YELLOW}Warning: You have uncommitted changes${ENDCOLOR}"
            echo -e "Files with changes:"
            git status --porcelain | sed 's/^/  /'
            echo
            echo -e "Continue with cherry-pick? This may cause conflicts. (y/n)"
            yes_no_choice "Proceeding..."
            echo
        fi
    fi

    ### Handle hash mode
    if [ -n "${hash_mode}" ]; then
        if [ -z "${commit_hash}" ]; then
            echo -e "${RED}No commit hash provided${ENDCOLOR}"
            echo -e "Usage: ${YELLOW}gitb cherry hash <commit-hash>${ENDCOLOR}"
            exit 1
        fi
        
        # Validate commit hash exists
        if ! git cat-file -e "${commit_hash}" 2>/dev/null; then
            echo -e "${RED}Invalid commit hash: ${commit_hash}${ENDCOLOR}"
            exit 1
        fi
        
        perform_cherry_pick "${commit_hash}"
        exit
    fi

    ### Handle range mode
    if [ -n "${range_mode}" ]; then
        if [ -z "${commit_range}" ]; then
            echo -e "${RED}No commit range provided${ENDCOLOR}"
            echo -e "Usage: ${YELLOW}gitb cherry range <from>..<to>${ENDCOLOR}"
            exit 1
        fi
        
        # Validate range format
        if [[ ! "${commit_range}" =~ \.\. ]]; then
            echo -e "${RED}Invalid range format. Use: <from>..<to>${ENDCOLOR}"
            exit 1
        fi
        
        perform_cherry_pick "${commit_range}"
        exit
    fi

    ### Handle interactive mode (default)
    if [ -n "${interactive_mode}" ]; then
        echo -e "${YELLOW}Select a branch to cherry-pick commits from:${ENDCOLOR}"
        choose_branch "cherry-pick"
        source_branch=${branch_name}
        echo
        
        # Show recent commits from the selected branch
        echo -e "${YELLOW}Select commits to cherry-pick from '${source_branch}':${ENDCOLOR}"
        echo -e "${GRAY}(You can select multiple commits)${ENDCOLOR}"
        echo
        
        choose_commits_interactive "${source_branch}"
        exit
    fi
}

### Function to perform the actual cherry-pick operation
# $1: commit hash or range
function perform_cherry_pick {
    local target="$1"
    
    echo -e "${YELLOW}Cherry-picking ${target}...${ENDCOLOR}"
    echo
    
    cherry_output=$(git cherry-pick "${target}" 2>&1)
    cherry_code=$?
    
    if [ $cherry_code == 0 ]; then
        echo -e "${GREEN}Cherry-pick completed successfully${ENDCOLOR}"
        after_cherry_pick
    else
        handle_cherry_pick_conflicts "$cherry_output" $cherry_code
    fi
}

### Function to handle cherry-pick conflicts and errors
# $1: cherry-pick output
# $2: cherry-pick return code
function handle_cherry_pick_conflicts {
    local output="$1"
    local code="$2"
    
    # Check for conflicts
    if [[ $output == *"fix conflicts and run \"git cherry-pick --continue\""* ]] || [[ $output == *"after resolving the conflicts"* ]]; then
        echo -e "${RED}Cherry-pick conflicts detected${ENDCOLOR}"
        echo
        echo -e "${YELLOW}Conflicted files:${ENDCOLOR}"
        git diff --name-only --diff-filter=U | sed 's/^/  /'
        echo
        echo -e "${YELLOW}Steps to resolve:${ENDCOLOR}"
        echo -e "1. Edit the conflicted files to resolve conflicts"
        echo -e "2. Add the resolved files: ${BLUE}git add <files>${ENDCOLOR}"
        echo -e "3. Continue cherry-pick: ${GREEN}gitb cherry continue${ENDCOLOR}"
        echo
        echo -e "Or abort the operation: ${GREEN}gitb cherry abort${ENDCOLOR}"
        return
    fi
    
    # Check for empty commit
    if [[ $output == *"The previous cherry-pick is now empty"* ]]; then
        echo -e "${YELLOW}The commit is empty after cherry-pick (changes already applied)${ENDCOLOR}"
        echo -e "Skip this commit? (y/n)"
        yes_no_choice "Skipping empty commit..."
        
        skip_output=$(git cherry-pick --skip 2>&1)
        if [ $? == 0 ]; then
            echo -e "${GREEN}Empty commit skipped${ENDCOLOR}"
            after_cherry_pick
        else
            echo -e "${RED}Failed to skip commit:${ENDCOLOR}"
            echo "$skip_output"
        fi
        return
    fi
    
    # Other errors
    echo -e "${RED}Cherry-pick failed with error:${ENDCOLOR}"
    echo "$output"
    exit $code
}

### Function to show information after successful cherry-pick
function after_cherry_pick {
    echo
    commit_hash=$(git rev-parse HEAD)
    commit_message=$(git log -1 --pretty=%B | head -n 1)
    
    echo -e "${BLUE}[${current_branch} ${commit_hash::7}]${ENDCOLOR}"
    echo -e "${commit_message}"
    echo
    
    # Show changes statistics
    changes=$(git --no-pager show ${commit_hash} --stat --format="")
    if [ -n "$changes" ]; then
        print_changes_stat "$changes"
    fi
    
    echo
    echo -e "Push your changes: ${YELLOW}gitb push${ENDCOLOR}"
    echo -e "Undo cherry-pick: ${YELLOW}gitb reset${ENDCOLOR}"
}

### Function to interactively select commits from a branch
# $1: source branch name
function choose_commits_interactive {
    local source_branch="$1"
    local commits=()
    local commit_messages=()
    local commit_hashes=()
    local show_all=false
    
    # Get list of commits from source branch that are not in current branch
    mapfile -t all_commits < <(git rev-list "${current_branch}..${source_branch}" --reverse)
    
    if [ ${#all_commits[@]} -eq 0 ]; then
        echo -e "${YELLOW}No commits to cherry-pick from '${source_branch}'${ENDCOLOR}"
        echo -e "All commits from '${source_branch}' are already in '${current_branch}'"
        exit
    fi
    
    while true; do
        # Limit to last 20 commits for readability unless show_all is true
        local max_commits=20
        if [ "$show_all" = true ] || [ ${#all_commits[@]} -le $max_commits ]; then
            commits=("${all_commits[@]}")
            if [ "$show_all" = true ]; then
                echo -e "${GRAY}Showing all ${#all_commits[@]} commits${ENDCOLOR}"
            fi
        else
            echo -e "${GRAY}Showing last ${max_commits} commits (${#all_commits[@]} total available)${ENDCOLOR}"
            commits=("${all_commits[@]: -$max_commits}")
        fi
        
        # Build commit info arrays
        commit_hashes=()
        commit_messages=()
        for commit in "${commits[@]}"; do
            commit_hashes+=("$commit")
            message=$(git log -1 --pretty=format:"%s" "$commit")
            author=$(git log -1 --pretty=format:"%an" "$commit")
            date=$(git log -1 --pretty=format:"%cr" "$commit")
            commit_messages+=("${commit::7} - $message ${GRAY}($author, $date)${ENDCOLOR}")
        done
        
        # Display commits and let user choose
        echo -e "${YELLOW}Available commits:${ENDCOLOR}"
        for i in "${!commit_messages[@]}"; do
            echo -e "$((i+1)). ${commit_messages[$i]}"
        done
        echo -e "0. Exit"
        if [ "$show_all" = false ] && [ ${#all_commits[@]} -gt $max_commits ]; then
            echo -e "Enter = to show all commits"
        fi
        echo
        
        echo -e "Enter commit numbers to cherry-pick (space-separated, e.g., '1 3 5'):"
        read -e selected_numbers
        
        # Handle special cases
        if [ -z "$selected_numbers" ]; then
            exit
        fi
        
        if [ "$selected_numbers" = "=" ] && [ "$show_all" = false ] && [ ${#all_commits[@]} -gt $max_commits ]; then
            show_all=true
            echo
            continue
        fi
        
        # If we reach here, process the selection
        break
    done
    
    # Parse selected numbers
    local selected_commits=()
    
    # Split the input into an array using IFS
    local IFS=' '
    local selected_array=($selected_numbers)
    
    for num in "${selected_array[@]}"; do
        # Trim whitespace
        num=$(echo "$num" | xargs)
        if [ -z "$num" ]; then
            continue
        fi
        
        if [[ "$num" =~ ^[0-9]+$ ]]; then
            if [ "$num" == "0" ]; then
                exit
            elif [ "$num" -gt 0 ] && [ "$num" -le ${#commits[@]} ]; then
                selected_commits+=("${commit_hashes[$((num-1))]}")
            else
                echo -e "${RED}Invalid selection: $num (must be between 1 and ${#commits[@]})${ENDCOLOR}"
                exit 1
            fi
        else
            echo -e "${RED}Invalid selection: '$num' (must be a number)${ENDCOLOR}"
            exit 1
        fi
    done
    
    if [ ${#selected_commits[@]} -eq 0 ]; then
        echo -e "${YELLOW}No valid commits selected${ENDCOLOR}"
        exit
    fi
    
    # Confirm selection
    echo
    echo -e "${YELLOW}Selected commits to cherry-pick:${ENDCOLOR}"
    for commit in "${selected_commits[@]}"; do
        message=$(git log -1 --pretty=format:"%s" "$commit")
        echo -e "  ${commit::7} - $message"
    done
    echo
    echo -e "Proceed with cherry-pick? (y/n)"
    yes_no_choice "Proceeding with cherry-pick..."
    
    # Perform cherry-picks
    local success_count=0
    local total_count=${#selected_commits[@]}
    
    for commit in "${selected_commits[@]}"; do
        echo -e "${YELLOW}Cherry-picking ${commit::7}...${ENDCOLOR}"
        
        cherry_output=$(git cherry-pick "$commit" 2>&1)
        cherry_code=$?
        
        if [ $cherry_code == 0 ]; then
            ((success_count++))
            message=$(git log -1 --pretty=format:"%s" "$commit")
            echo -e "${GREEN}✓${ENDCOLOR} Successfully cherry-picked: $message"
        else
            echo -e "${RED}✗${ENDCOLOR} Failed to cherry-pick ${commit::7}"
            handle_cherry_pick_conflicts "$cherry_output" $cherry_code
            # If we reach here, the conflict handling should have exited
            break
        fi
        echo
    done
    
    if [ $success_count -eq $total_count ]; then
        echo -e "${GREEN}All ${total_count} commits cherry-picked successfully!${ENDCOLOR}"
        after_cherry_pick
    fi
} 
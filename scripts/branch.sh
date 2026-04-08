#!/usr/bin/env bash

### Script for working with branches: create, switch, delete
# Use a separate branch for writing new code, then merge it to default branch
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Main function
# $1: mode
    # <empty>: switch to a local branch
    # list: print a list of local branches
    # remote: switch to a remote branch
    # main: switch to the default branch
    # new: create a new branch from the current one 
    # newd: create a new branch from the default branch
    # delete: delete a local branch
function branch_script {
    case "$1" in
        list|l)      list="true";;
        remote|r|re) remote="true";;
        main|def|m)  main="true";;
        new|n|c)          
            new="true"
            current="true"    
        ;;
        newd|nd|cd)        
            new="true"
        ;;
        delete|del|d) delete="true";;
        prev|p|-)     prev="true";;
        recent|rc)    recent="true";;
        gone|g)       gone="true";;
        tag|t)        tag="true";;
        help|h)       help="true";;
        *)
            wrong_mode "branch" $1
    esac


    ### Print header
    header="GIT BRANCH"
    if [ -n "${remote}" ]; then
        header="$header REMOTE"
    elif [ -n "${main}" ]; then
        header="$header DEFAULT"
    elif [ -n "${current}" ]; then
        header="$header NEW"
    elif [ -n "${new}" ]; then
        header="$header NEW FROM DEFAULT"
    elif [ -n "${list}" ]; then
        header="$header LIST"
    elif [ -n "${delete}" ]; then
        header="$header DELETE"
    elif [ -n "${prev}" ]; then
        header="$header PREVIOUS"
    elif [ -n "${recent}" ]; then
        header="$header RECENT"
    elif [ -n "${gone}" ]; then
        header="$header GONE"
    elif [ -n "${tag}" ]; then
        header="$header TAG"
    fi

    echo -e "${YELLOW}${header}${ENDCOLOR}"
    echo
    

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb branch <mode>${ENDCOLOR}"
        echo
        msg="${YELLOW}Mode${ENDCOLOR}_${GREEN}Aliases${ENDCOLOR}_\t${BLUE}Description${ENDCOLOR}"
        msg="$msg\n${BOLD}<empty>${ENDCOLOR}_ _Select a local branch to switch"
        msg="$msg\n${BOLD}list${ENDCOLOR}_l_Print a list of local branches"
        msg="$msg\n${BOLD}remote${ENDCOLOR}_re|r_Fetch $origin_name and select a remote branch to switch"
        msg="$msg\n${BOLD}main${ENDCOLOR}_def|m_Switch to $main_branch without additional confirmations"
        msg="$msg\n${BOLD}tag${ENDCOLOR}_t_Checkout to a specific tag"
        msg="$msg\n${BOLD}new${ENDCOLOR}_n|c_Build a conventional name and create a new branch from current branch"
        msg="$msg\n${BOLD}newd${ENDCOLOR}_nd|cd_Build a conventional name, switch to $main_branch, pull it and create new branch"
        msg="$msg\n${BOLD}delete${ENDCOLOR}_del|d_Delete branches (cleanup orphaned, merged, or select specific branch)"
        msg="$msg\n${BOLD}prev${ENDCOLOR}_p|-_Switch to the previous branch (like cd -)"
        msg="$msg\n${BOLD}recent${ENDCOLOR}_rc_Show recently checked out branches and select one to switch"
        msg="$msg\n${BOLD}gone${ENDCOLOR}_g_Delete local branches whose remote tracking branch is gone"
        msg="$msg\n${BOLD}help${ENDCOLOR}_h_Show this help"
        echo -e "$(echo -e "$msg" | column -ts'_')"
        exit
    fi
        
   

    ### Run switch to previous branch
    if [[ -n "${prev}" ]]; then
        prev_branch=$(git rev-parse --symbolic-full-name @{-1} 2>/dev/null | sed 's|refs/heads/||')

        if [ -z "$prev_branch" ]; then
            echo -e "${RED}No previous branch found${ENDCOLOR}"
            exit 1
        fi

        echo -e "Switching to previous branch: ${YELLOW}${prev_branch}${ENDCOLOR}"
        echo
        switch "$prev_branch"
        exit
    fi


    ### Run recent branches logic
    if [[ -n "${recent}" ]]; then
        echo -e "${YELLOW}Recently checked out branches:${ENDCOLOR}"
        echo

        # Extract unique branch names from reflog checkout entries
        recent_branches=()
        while IFS= read -r branch; do
            # Skip current branch and empty lines
            if [ -n "$branch" ] && [ "$branch" != "$current_branch" ]; then
                # Check if this branch still exists locally
                if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
                    # Check if already in list
                    is_dup="false"
                    for existing in "${recent_branches[@]}"; do
                        if [ "$existing" == "$branch" ]; then
                            is_dup="true"
                            break
                        fi
                    done
                    if [ "$is_dup" == "false" ]; then
                        recent_branches+=("$branch")
                    fi
                fi
            fi
            # Limit to 10 recent branches
            if [ ${#recent_branches[@]} -ge 10 ]; then
                break
            fi
        done < <(git reflog --pretty="%gs" | grep "^checkout: moving from" | sed 's/checkout: moving from .* to //')

        if [ ${#recent_branches[@]} -eq 0 ]; then
            echo -e "${GREEN}No recent branches found${ENDCOLOR}"
            exit
        fi

        for index in "${!recent_branches[@]}"; do
            branch="${recent_branches[$index]}"
            # Get last commit on that branch
            last_msg=$(git log -n 1 --pretty="${YELLOW_ES}%h${ENDCOLOR_ES} %s (${GREEN_ES}%cr${ENDCOLOR_ES})" "refs/heads/$branch" 2>/dev/null)
            echo -e "$(($index+1)). ${BLUE}${branch}${ENDCOLOR}\t$last_msg"
        done
        echo "0. Exit"
        echo

        read_prefix="Select branch number: "
        choose "${recent_branches[@]}"
        echo
        echo

        switch "$choice_result"
        exit
    fi


    ### Run gone branches cleanup
    if [[ -n "${gone}" ]]; then
        echo -e "${YELLOW}Fetching and pruning remote references...${ENDCOLOR}"
        echo

        fetch_output=$(git fetch --prune 2>&1)
        check_code $? "$fetch_output" "fetch and prune remote"

        # Find local branches whose upstream is gone
        gone_branches=()
        while IFS= read -r line; do
            branch=$(echo "$line" | sed 's/^[ *]*//' | awk '{print $1}')
            if [ -n "$branch" ] && [ "$branch" != "$main_branch" ] && [ "$branch" != "$current_branch" ]; then
                gone_branches+=("$branch")
            fi
        done < <(git branch -vv | grep ': gone\]')

        if [ ${#gone_branches[@]} -eq 0 ]; then
            echo -e "${GREEN}No branches with gone remote tracking found${ENDCOLOR}"
            echo -e "All local branches have corresponding remote branches"
            exit
        fi

        echo -e "${YELLOW}Found ${#gone_branches[@]} branch(es) with gone remote tracking:${ENDCOLOR}"
        for branch in "${gone_branches[@]}"; do
            printf "\t$branch\n"
        done
        echo

        echo -e "${YELLOW}Do you want to delete these branches?${ENDCOLOR}"
        echo -e "Do you want to continue (y/n)?"
        yes_no_choice "Deleting gone branches..."

        for branch in "${gone_branches[@]}"; do
            delete_output=$(git branch -D "$branch" 2>&1)
            delete_code=$?
            if [ $delete_code -eq 0 ]; then
                echo -e "${GREEN}Branch '$branch' deleted${ENDCOLOR}"
            else
                echo -e "${RED}Cannot delete branch '$branch'!${ENDCOLOR}"
                echo -e "${delete_output}"
            fi
        done
        exit
    fi


    ### Run switch to main logic
    if [[ -n "${main}" ]]; then
        switch ${main_branch}
        exit
    fi


    ### Run tag checkout logic
    if [[ -n "${tag}" ]]; then
        echo -e "${YELLOW}Do you want to fetch remote tags first?${ENDCOLOR}"
        read -n 1 -p "Fetch remote? (y/n) " choice
        echo

        if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
            echo
            echo -e "${YELLOW}Fetching remote tags...${ENDCOLOR}"
            fetch_output=$(git fetch --tags 2>&1)
            check_code $? "$fetch_output" "fetch remote tags"
        fi
        echo

        echo -e "${YELLOW}Select a tag to checkout:${ENDCOLOR}"
        
        # Get all tags sorted by version
        tags_info_str=$(git for-each-ref --count=999  --sort=-creatordate refs/tags --format="${BLUE_ES}%(refname:short)${ENDCOLOR_ES} | %(contents:subject) | ${YELLOW_ES}%(objectname:short)${ENDCOLOR_ES} | ${CYAN_ES}%(creatordate:human)${ENDCOLOR_ES}" | column -ts'|' )
        IFS=$'\n' read -rd '' -a tags_info <<<"$tags_info_str"

        if [ -z "$tags_info" ]; then
            echo -e "${RED}No tags found in this repository${ENDCOLOR}"
            exit
        fi

        # Convert to array and display
        for index in "${!tags_info[@]}"; do
            echo -e "$(($index+1)). ${tags_info[index]}"
        done
        echo "0. Exit without changes"
        echo

        while [ true ]; do
            read -p "Select tag number: " choice

            if [ "$choice" == "0" ] || [ "$choice" == "" ]; then
                exit
            fi

            re='^[1-9][0-9]*$'
            if [[ $choice =~ $re ]]; then
                index=$((choice - 1))
                if [ $index -ge 0 ] && [ $index -lt ${#tags_info[@]} ]; then
                    selected_tag=$(git for-each-ref --count=999 --sort=-creatordate refs/tags --format='%(refname:short)' | sed -n "$((index+1))p")
                    break
                else
                    echo -e "${RED}Invalid tag number! Please choose from 1-${#tags_info[@]}.${ENDCOLOR}"
                    echo
                    continue
                fi
            else
                echo -e "${RED}Please enter a valid tag number.${ENDCOLOR}"
                echo
                continue
            fi
        done

        echo
        echo -e "${YELLOW}Checking out to tag ${selected_tag}...${ENDCOLOR}"
        echo
        
        checkout_output=$(git checkout $selected_tag 2>&1)
        checkout_code=$?

        if [ $checkout_code -eq 0 ]; then
            echo -e "${GREEN}Successfully checked out to tag '${selected_tag}'${ENDCOLOR}"
            echo -e "${YELLOW}Note: You are now in 'detached HEAD' state${ENDCOLOR}"
            echo -e "If you want to make changes, create a new branch: ${YELLOW}gitb branch new${ENDCOLOR}"
        else
            echo -e "${RED}Failed to checkout to tag ${selected_tag}! Error message:${ENDCOLOR}"
            echo "${checkout_output}"
            exit $checkout_code
        fi

        exit
    fi


    ### Run switch to local logic
    if [[ -z "$new" ]] && [[ -z "$remote" ]] && [[ -z "$delete" ]] && [[ -z "$list" ]] && [[ -z "$tag" ]]; then
        echo -e "${YELLOW}Select a branch to switch from '${current_branch}'${ENDCOLOR}:"

        choose_branch

        echo

        switch ${branch_name}
        exit


    ### Run switch to remote logic
    elif [[ -z "$new" ]] && [[ -n "$remote" ]] && [[ -z "$delete" ]] && [[ -z "$tag" ]]; then
        echo -e "${YELLOW}Fetching remote...${ENDCOLOR}"
        echo

        fetch_output=$(git fetch 2>&1)
        check_code $? "$fetch_output" "fetch remote"

        prune_output=$(git remote prune $origin_name 2>&1)

        echo -e "${YELLOW}Switch from '${current_branch}' to the remote branch${ENDCOLOR}"
        
        choose_branch "remote"

        echo

        switch ${branch_name}
        exit


    ### Run delete local logic
    elif [[ -z "$new" ]] && [[ -n "$delete" ]] && [[ -z "$tag" ]]; then

        # Delete local branches that don't exist on remote
        echo -e "${YELLOW}Do you want to delete local branches that don't exist on remote?${ENDCOLOR}"
        echo -e "This will clean up branches that were deleted from the remote repository"
        echo

        printf "Answer (y/n): "

        while [ true ]; do
            read -n 1 -s choice
            if is_yes "$choice"; then
                printf "y\n\n"
                echo -e "${YELLOW}Fetching remote and pruning...${ENDCOLOR}"
                echo

                fetch_output=$(git fetch --prune 2>&1)
                check_code $? "$fetch_output" "fetch and prune remote"

                # Get all local branches
                IFS=$'\n' read -rd '' -a local_branches <<<"$(git branch --format='%(refname:short)' | cat 2>&1)"

                branches_to_delete=()
                for branch in "${local_branches[@]}"; do
                    # Skip main branch and current branch
                    if [[ "$branch" == "$main_branch" ]] || [[ "$branch" == "$current_branch" ]]; then
                        continue
                    fi

                    # Check if remote tracking branch exists
                    remote_exists=$(git rev-parse --verify --quiet $origin_name/$branch 2>&1)
                    if [ $? -ne 0 ]; then
                        branches_to_delete+=("$branch")
                    fi
                done

                if [ ${#branches_to_delete[@]} -eq 0 ]; then
                    echo -e "${GREEN}No orphaned local branches found!${ENDCOLOR}"
                    echo -e "All local branches have corresponding remote branches"
                    echo
                else
                    echo -e "${YELLOW}Found ${#branches_to_delete[@]} local branch(es) without remote:${ENDCOLOR}"
                    for branch in "${branches_to_delete[@]}"; do
                        printf "\t$branch\n"
                    done
                    echo

                    echo -e "${YELLOW}Do you want to delete these branches?${ENDCOLOR}"
                    printf "Answer (y/n): "

                    while [ true ]; do
                        read -n 1 -s delete_choice
                        if is_yes "$delete_choice"; then
                            printf "y\n\n"
                            for branch in "${branches_to_delete[@]}"; do
                                delete_output=$(git branch -D $branch 2>&1)
                                delete_code=$?
                                if [ $delete_code -eq 0 ]; then
                                    echo -e "${GREEN}Branch '$branch' is deleted!${ENDCOLOR}"
                                else
                                    echo -e "${RED}Cannot delete branch '$branch'!${ENDCOLOR}"
                                    echo -e "${delete_output}"
                                fi
                            done
                            echo
                            break
                        elif is_no "$delete_choice"; then
                            printf "n\n\n"
                            break
                        fi
                    done
                fi
                break
            elif is_no "$choice"; then
                printf "n\n\n"
                break
            fi
        done

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
            echo -e "These are branches without new changes regarding ${YELLOW}${main_branch}${ENDCOLOR}"
            for index in "${!merged_branches_without_main[@]}"
            do
                printf "\t${merged_branches_without_main[index]}\n"
            done

            printf "\nAnswer (y/n): "
            
            while [ true ]; do
                read -n 1 -s choice
                if is_yes "$choice"; then
                    printf "y\n\n"
                    branches_to_delete="$(git branch --merged | egrep -v "(^\*|master|main|develop|${main_branch})" | xargs)"
                    IFS=$' ' read -rd '' -a branches <<<"$branches_to_delete"
                    for index in "${!branches[@]}"
                    do
                        branch_to_delete="$(echo "${branches[index]}" | xargs)"
                        delete_output=$(git branch -d $branch_to_delete 2>&1)
                        delete_code=$?
                        if [ $delete_code == 0 ]; then
                            echo -e "${GREEN}Branch '$branch_to_delete' is deleted!${ENDCOLOR}"
                        else
                            echo -e "${RED}Cannot delete branch '$branch_to_delete'!${ENDCOLOR}"
                            echo -e "${delete_output}"
                            break
                        fi
                    done
                    echo
                    break

                else
                    printf "n\n\n"
                    break
                fi
            done
        fi

        # Detect squash-merged branches
        # These branches were squash-merged into main (not regular merge),
        # so `git branch --merged` won't detect them
        squash_merged_branches=()
        IFS=$'\n' read -rd '' -a all_local <<<"$(git branch --format='%(refname:short)' | cat 2>&1)"

        for branch in "${all_local[@]}"; do
            # Skip main, current, and already-deleted branches
            if [[ "$branch" == "$main_branch" ]] || [[ "$branch" == "$current_branch" ]] || [[ -z "$branch" ]]; then
                continue
            fi
            # Skip if already detected as merged
            already_merged="false"
            for merged_entry in "${merged_branches_without_main[@]}"; do
                merged_name=$(echo "$merged_entry" | awk '{print $1}')
                if [[ "$merged_name" == "$branch" ]]; then
                    already_merged="true"
                    break
                fi
            done
            if [ "$already_merged" == "true" ]; then
                continue
            fi

            # Check if this branch was squash-merged into main
            # Create a single commit representing all branch changes, then use
            # git cherry to check if an equivalent patch exists in main
            merge_base=$(git merge-base "$main_branch" "$branch" 2>/dev/null)
            if [ -n "$merge_base" ]; then
                # Create a temporary commit with the branch's tree parented by merge-base
                # This represents "all branch changes squashed into one commit"
                squash_commit=$(git commit-tree "$branch^{tree}" -p "$merge_base" -m "tmp" 2>/dev/null)
                if [ -n "$squash_commit" ]; then
                    # Check if main already contains an equivalent change
                    cherry_result=$(git cherry "$main_branch" "$squash_commit" 2>/dev/null)
                    if [[ "$cherry_result" == "-"* ]]; then
                        squash_merged_branches+=("$branch")
                    fi
                fi
            fi
        done

        if [ ${#squash_merged_branches[@]} -gt 0 ]; then
            echo -e "${YELLOW}Found ${#squash_merged_branches[@]} squash-merged branch(es):${ENDCOLOR}"
            echo -e "These branches appear to have been squash-merged into ${YELLOW}${main_branch}${ENDCOLOR}"
            for branch in "${squash_merged_branches[@]}"; do
                printf "\t$branch\n"
            done
            echo

            echo -e "${YELLOW}Do you want to delete these squash-merged branches?${ENDCOLOR}"
            printf "Answer (y/n): "

            while [ true ]; do
                read -n 1 -s choice
                if is_yes "$choice"; then
                    printf "y\n\n"
                    for branch in "${squash_merged_branches[@]}"; do
                        delete_output=$(git branch -D "$branch" 2>&1)
                        delete_code=$?
                        if [ $delete_code -eq 0 ]; then
                            echo -e "${GREEN}Branch '$branch' is deleted!${ENDCOLOR}"
                        else
                            echo -e "${RED}Cannot delete branch '$branch'!${ENDCOLOR}"
                            echo -e "${delete_output}"
                        fi
                    done
                    echo
                    break
                elif is_no "$choice"; then
                    printf "n\n\n"
                    break
                fi
            done
        fi

        # Delete in normal way
        echo -e "${YELLOW}Delete a local branch${ENDCOLOR}"

        choose_branch "delete"

        echo

        delete_output=$(git branch -d $branch_name 2>&1)
        delete_code=$?

        if [ "$delete_code" == 0 ]; then
            echo -e "${GREEN}Branch '$branch_name' is deleted!${ENDCOLOR}"

        elif [[ ${delete_output} == *"is not fully merged"* ]]; then
            echo -e "${RED}The branch '$branch_name' is not fully merged${ENDCOLOR}"
            echo "Do you want to force delete (-D flag) this branch?"

            printf "Answer (y/n): "
            
            while [ true ]; do
                read -n 1 -s choice
                if is_yes "$choice"; then
                    printf "y\n\n"
                    delete_output=$(git branch -D $branch_name 2>&1)
                    delete_code=$?
                    if [ "$delete_code" != 0 ]; then
                        echo -e "${RED}Cannot delete branch '$branch_name'! Error message:${ENDCOLOR}"
                        echo -e "${delete_output}"
                        exit
                    fi
                    echo -e "${GREEN}Branch '$branch_name' is deleted!${ENDCOLOR}"
                    break

                elif is_no "$choice"; then
                    printf "n\n"
                    exit
                fi
            done

        else
            echo -e "${RED}Cannot delete branch '$branch_name'! Error message:${ENDCOLOR}"
            echo -e "${delete_output}"
            exit
        fi

        remote_check=$(git --no-pager log $origin_name/$branch_name..HEAD 2>&1)
        if [[ $remote_check != *"unknown revision or path not in the working tree"* ]]; then
            echo
            echo -e "${YELLOW}Do you want to delete this branch in the remote?${ENDCOLOR}"

            printf "Answer (y/n): "
            
            while [ true ]; do
                read -n 1 -s choice
                if is_yes "$choice"; then
                    printf "y\n\n"
                    echo -e "${YELLOW}Deleting...${YELLOW}"

                    push_output=$(git push $origin_name -d $branch_name 2>&1)
                    push_code=$?

                    echo
                    if [ "$push_code" != 0 ]; then
                        # Check if the error is because the branch doesn't exist on remote (which is OK)
                        if [[ $push_output == *"remote ref does not exist"* ]] || [[ $push_output == *"unable to delete"*"does not exist"* ]]; then
                            echo -e "${YELLOW}Branch '$branch_name' doesn't exist on remote (already deleted or never pushed)${ENDCOLOR}"
                        else
                            echo -e "${RED}Cannot delete branch '$branch_name'! Error message:${ENDCOLOR}"
                            echo -e "${push_output}"
                            exit
                        fi
                    else
                        echo -e "${GREEN}Branch '$branch_name' is deleted in the remote!${ENDCOLOR}"
                    fi
                    break

                elif is_no "$choice"; then
                    printf "n\n"
                    exit
                fi
            done
        fi

        exit
    fi

    if [ -n "$current" ]; then
        echo -e "${YELLOW}Current local branches:${ENDCOLOR}"
        list_branches
    else
         echo -e "It will switch to ${BOLD}${BLUE}${main_branch}${ENDCOLOR} and pull it first"
    fi

    if [ -n "$list" ]; then
        exit
    fi

    echo

    ### Run create new branch logic
    # Detect prefixes from existing branches
    detected_prefixes=""
    all_branches=$(git branch -a --format='%(refname:short)' 2>/dev/null | sed 's|origin/||g' | sort -u)
    if [ -n "$all_branches" ]; then
        declare -A prefix_candidates
        
        while IFS= read -r branch; do
            if [ -n "$branch" ] && [[ "$branch" != "$main_branch" ]] && [[ "$branch" != "HEAD" ]]; then
                # Extract prefix from branch name using common separators
                if [[ "$branch" =~ ^([a-zA-Z0-9]+)[-_/](.+)$ ]]; then
                    prefix="${BASH_REMATCH[1]}"
                    # Filter out very short or common prefixes
                    if [[ ${#prefix} -ge 2 ]] && [[ ! "$prefix" =~ ^(dev|tmp|old|new|test)$ ]]; then
                        prefix_candidates["$prefix"]=1
                    fi
                fi
            fi
        done <<< "$all_branches"
        
        # Convert to sorted array
        detected_prefixes_array=()
        for prefix in "${!prefix_candidates[@]}"; do
            detected_prefixes_array+=("$prefix")
        done
        
        # Sort the array
        if [ ${#detected_prefixes_array[@]} -gt 0 ]; then
            IFS=$'\n' detected_prefixes_sorted=($(sort <<<"${detected_prefixes_array[*]}"))
            unset IFS
            detected_prefixes="${detected_prefixes_sorted[*]}"
        fi
    fi

    # Build the prefixes array with ticket_name first if it exists
    all_prefixes=""
    if [ -n "$ticket_name" ]; then
        if [ -n "$detected_prefixes" ]; then
            all_prefixes="$ticket_name $detected_prefixes"
        else
            all_prefixes="$ticket_name"
        fi
    elif [ -n "$detected_prefixes" ]; then
        all_prefixes="$detected_prefixes"
    fi

    branch_type=""
    branch_type_and_sep=""

    # If no prefixes detected, skip to branch name entry
    if [ -z "$all_prefixes" ]; then
        echo -e "${YELLOW}Step 1.${ENDCOLOR} Enter the full name of the branch"
        echo "Press Enter if you want to exit"

        printf "${BOLD}git branch${ENDCOLOR} "
        read -e branch_name

        if [ -z "$branch_name" ]; then
            exit
        fi
        
        # Sanitize branch name input
        if ! sanitize_git_name "$branch_name"; then
            show_sanitization_error "branch name" "Use only letters, numbers, dots, dashes, underscores, and slashes."
            exit 1
        fi
        branch_name="$sanitized_git_name"
    else
        ### Step 1. Select branch prefix
        branch_to_show=$current_branch
        if [ -z "$current" ]; then
            branch_to_show=$main_branch
        fi
        echo -e "${YELLOW}Step 1.${ENDCOLOR} Enter a ${YELLOW}prefix${ENDCOLOR} for your new branch from ${BOLD}${BLUE}${branch_to_show}${ENDCOLOR}"
        echo -e "A branch will be created with '${YELLOW}${sep}${ENDCOLOR}' as a separator (e.g., ${YELLOW}prefix${sep}name${ENDCOLOR})"
        echo -e "Press Enter to continue without prefix or enter 0 to exit without changes"
        
        # Build the display array
        IFS=' ' read -r -a prefixes_array <<< "$all_prefixes"
        declare -A prefixes_map
        
        res=""
        for i in "${!prefixes_array[@]}"; do
            option=$((i+1))
            prefixes_map["$option"]="${prefixes_array[$i]}"
            
            res="$res$option. ${BOLD}${prefixes_array[$i]}${ENDCOLOR}|"
        done
        
        # Add no prefix option
        no_prefix_option=$((${#prefixes_array[@]}+1))
        prefixes_map["$no_prefix_option"]=""
        
        echo -e "You can select one of the ${YELLOW}detected prefixes${ENDCOLOR}: $(echo $res | column -ts'|')"

        while [ true ]; do
            read -p "<prefix>: " choice

            if [ "$choice" == "0" ]; then
                exit
            fi
            
            # Handle empty input (Enter) - continue without prefix
            if [ "$choice" == "" ]; then
                branch_type=""
                branch_type_and_sep=""
                break
            fi

            # Check if it's a number (option selection)
            re='^[1-9][0-9]*$'
            if [[ $choice =~ $re ]] && [ -n "${prefixes_map[$choice]+isset}" ]; then
                branch_type="${prefixes_map[$choice]}"
                if [ -n "$branch_type" ]; then
                    branch_type_and_sep="${branch_type}${sep}"
                fi
                break
            else
                # Manual prefix entry - sanitize and validate format
                if [ -n "$choice" ]; then
                    # Sanitize prefix input
                    if ! sanitize_git_name "$choice"; then
                        show_sanitization_error "branch prefix" "Use only letters, numbers, dots, dashes, underscores, and slashes."
                        echo
                        continue
                    fi
                    branch_type="$sanitized_git_name"
                    branch_type_and_sep="${branch_type}${sep}"
                    break
                else
                    echo -e "${RED}Please enter a valid option number or custom prefix.${ENDCOLOR}"
                    echo
                    continue
                fi
            fi
        done

        ### Step 2. Enter branch name
        echo
        echo -e "${YELLOW}Step 2.${ENDCOLOR} Enter the ${YELLOW}name${ENDCOLOR} of the branch"
        echo "Press Enter if you want to exit"

        printf "${BOLD}git branch${ENDCOLOR}"
        read -p " ${branch_type_and_sep}" -e branch_name

        if [ -z "$branch_name" ]; then
            exit
        fi

        # Sanitize branch name input
        if ! sanitize_git_name "$branch_name"; then
            show_sanitization_error "branch name" "Use only letters, numbers, dots, dashes, underscores, and slashes."
            exit 1
        fi
        branch_name="${branch_type_and_sep}${sanitized_git_name}"
    fi



    if [[ "$branch_name" == "HEAD" ]] || [[ "$branch_name" == "$origin_name" ]]; then
        echo
        echo -e "${RED}This name is forbidden${ENDCOLOR}"
        exit
    fi

    ### Switch to main and pull it (if needed)
    from_branch=$current_branch
    if [ -z "${current}" ]; then
        echo
        switch $main_branch "true"

        echo -e "${YELLOW}Pulling '$origin_name/$main_branch'...${ENDCOLOR}"
        echo
        pull $main_branch $origin_name $editor

        from_branch=$main_branch
    fi


    ### Create a new branch and switch to it
    create_output=$(git switch -c $branch_name 2>&1)
    create_code=$?

    echo

    if [ $create_code -eq 0 ]; then
        echo -e "${GREEN}${create_output} from '$from_branch'${ENDCOLOR}"
        changes=$(git_status)
        if [ -n "$changes" ]; then
            echo
            echo -e "${YELLOW}Moved changes:${ENDCOLOR}"
            echo -e "${changes}"
        fi
        exit
    fi

    if [[ $create_output == *"already exists"* ]]; then
        echo -e "${RED}Branch with name '${branch_name}' already exists!${ENDCOLOR}"
        exit $create_code
    fi

    echo -e "${RED}Cannot create '${branch_name}'! Error message:${ENDCOLOR}"
    echo "${create_output}"
    exit $create_code
}
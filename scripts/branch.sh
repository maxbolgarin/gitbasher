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
    elif [ -n "${tag}" ]; then
        header="$header TAG"
    fi

    echo -e "${YELLOW}${header}${ENDCOLOR}"
    echo
    

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb branch <mode>${ENDCOLOR}"
        echo
        echo -e "${YELLOW}Available modes${ENDCOLOR}"
        echo -e "<empty>\t\tSelect a local branch to switch"
        echo -e "list|l\t\tPrint a list of local branches"
        echo -e "remote|re|r\tFetch $origin_name and select a remote branch to switch"
        echo -e "main|def|m\tSwitch to $main_branch without additional confirmations"
        echo -e "tag|t\t\tCheckout to a specific tag"
        echo -e "new|n|c\t\tBuild a conventional name and create a new branch from $main_branch"
        echo -e "newd|nd\t\tBuild a conventional name, switch to $main_branch, pull it and create new branch"
        echo -e "delete|del|d\tSelect a local branch to delete"
        echo -e "help|h\t\tShow this help"
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
                if [ "$choice" == "y" ]; then
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

                elif [ "$choice" == "n" ]; then
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
                if [ "$choice" == "y" ]; then
                    printf "y\n\n"
                    echo -e "${YELLOW}Deleting...${YELLOW}"

                    push_output=$(git push $origin_name -d $branch_name 2>&1)
                    push_code=$?

                    echo
                    if [ "$push_code" != 0 ]; then
                        echo -e "${RED}Cannot delete branch '$branch_name'! Error message:${ENDCOLOR}"
                        echo -e "${delete_output}"
                        exit
                    fi
                    echo -e "${GREEN}Branch '$branch_name' is deleted in the remote!${ENDCOLOR}"
                    break

                elif [ "$choice" == "n" ]; then
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
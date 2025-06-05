#!/usr/bin/env bash

### Script for creating commits in angular style (conventional commits)
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Function to cleanup staged files and git add cache
# $1: git_add arguments
function cleanup_on_exit {
    if [ -n "$1" ]; then
        git restore --staged $1
    fi
    # Clean up the cached git add arguments
    # git config --unset gitbasher.cached-git-add 2>/dev/null
}

### Function prints information about the last commit, use it after `git commit`
# $1: name of operation, e.g. `amend`
# Using of global:
#     * current_branch
#     * commit - message
function after_commit {
    if [ -n "$1" ]; then
        echo -e "${GREEN}Successful commit $1!${ENDCOLOR}"
    else
        echo -e "${GREEN}Successful commit!${ENDCOLOR}"
    fi
    
    echo

    # Print commit hash and message
    commit_hash=$(git rev-parse HEAD)
    echo -e "${BLUE}[$current_branch ${commit_hash::7}]${ENDCOLOR}"
    if [ -z "${commit}" ]; then
        echo $(git log -1 --pretty=%B | cat)
    else
        printf "$commit\n"
    fi

    echo

    # Print stat of last commit - updated files and lines
    print_changes_stat "$(git --no-pager show $commit_hash --stat --format="")"

    # Some info to help users
    if [ -z "${fast}" ] && [ -z "${push}" ]; then
        echo
        echo -e "Push your changes: ${YELLOW}gitb push${ENDCOLOR}"
        echo -e "Undo commit: ${YELLOW}gitb reset${ENDCOLOR}"
    fi
}


### Main function
# $1: mode
    # <empty> - regular commit mode
    # msg: use editor to write commit message
    # ticket: add ticket info to the end of message header
    # fast: fast commit with git add .
    # fasts: fast commit with scope
    # push: push changes after commit
    # fastp: fast commit with push
    # fastsp: fast commit with scope and push
    # fixup: fixup commit   
    # fastfix: fixup commit with git add .
    # fastfixp: fast fixup commit with push
    # amend: add to the last without edit (add to last commit)
    # amendf: add all fiels to the last commit without edit
    # last: change commit message to the last one
    # revert: revert commit
    # help: print help
function commit_script {
    case "$1" in
        msg|m)              msg="true";;
        ticket|jira|j|t)    ticket="true";;
        fast|f)             fast="true";;
        fasts|fs|sf)        fast="true"; scope="true";;
        push|pu|p)          push="true";;
        fastp|fp|pf)        fast="true"; push="true";;
        fastsp|fsp|fps)     fast="true"; push="true"; scope="true";;
        fixup|fix|x)        fixup="true";;
        fixupp|fixp|xp|px)  fixup="true"; push="true";;
        fastfix|fx|xf)      fixup="true"; fast="true";;
        fastfixp|fxp|xfp)   fixup="true"; fast="true"; push="true";;
        amend|am|a)         amend="true";;
        amendf|amf|af|fa)   amend="true"; fast="true";;
        last|l)             last="true";;
        revert|rev)         revert="true";;
        help|h)             help="true";;
        *)
            wrong_mode "commit" $1
    esac


    ### Print header
    header_msg="GIT COMMIT"
    if [ -n "${fast}" ]; then
        if [ -n "${push}" ]; then
            if [ -n "${fixup}" ]; then
                header_msg="$header_msg FAST FIXUP & PUSH"
            else
                header_msg="$header_msg FAST & PUSH"
            fi
        elif [ -n "${fixup}" ]; then
            header_msg="$header_msg FAST FIXUP"
        else
            header_msg="$header_msg FAST"
        fi
    elif [ -n "${fixup}" ]; then
        if [ -n "${push}" ]; then
            header_msg="$header_msg FIXUP & PUSH"
        else
            header_msg="$header_msg FIXUP"
        fi
    elif [ -n "${push}" ]; then
        header_msg="$header_msg & PUSH"
    elif [ -n "${msg}" ]; then
        header_msg="$header_msg MSG"
    elif [ -n "${ticket}" ]; then
        header_msg="$header_msg TICKET"
    elif [ -n "${amend}" ]; then
        header_msg="$header_msg AMEND LAST"
    elif [ -n "${last}" ]; then
        header_msg="$header_msg LAST"
    elif [ -n "${revert}" ]; then
        header_msg="$header_msg REVERT"
    fi

    echo -e "${YELLOW}${header_msg}${ENDCOLOR}"
    echo

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb commit <mode>${ENDCOLOR}"
        echo
        echo -e "${YELLOW}Available modes${ENDCOLOR}"
        echo -e "<empty>\t\tSelect files to commit and create a conventional message in format: 'type(scope): message'"
        echo -e "msg|m\t\tSame as <empty>, but create multiline commit message using text editor"
        echo -e "ticket|t\tSame as <empty>, but add tracker's ticket info to the end of the commit header"
        echo -e "fast|f\t\tAdd all files (git add .) and create a conventional commit message without scope"
        echo -e "fasts|fs|sf\tAdd all files (git add .) and create a conventional commit message with scope"
        echo -e "push|pu|p\tCreate a conventional commit and push changes at the end"
        echo -e "fastp|fp|pf\tCreate a conventional commit in the fast mode and push changes"
        echo -e "fastsp|fsp|fps\tCreate a conventional commit in the fast mode with scope and push changes"
        echo -e "fixup|fix|x\tSelect files and commit to make a --fixup commit (git commit --fixup <hash>)"
        echo -e "fixupp|fixp|xp\tSelect files and commit to make a --fixup commit and push changes"
        echo -e "fastfix|fx|xf\tAdd all files (git add .) and commit to make a --fixup commit"
        echo -e "fastfixp|fxp\tAdd all files (git add .) and commit to make a --fixup commit and push"
        echo -e "amend|am|a\tSelect files and add them to the last commit without message edit (git commit --amend --no-edit)"
        echo -e "amendf|amf|af\tAdd all fiels to the last commit without message edit (git commit --amend --no-edit)"
        echo -e "last|l\t\tChange commit message to the last one"
        echo -e "revert|rev\tSelect a commit to revert (git revert -no-edit <commit>)"
        echo -e "help|h\t\tShow this help"
        # Clean up cached git add on help exit
        git config --unset gitbasher.cached-git-add 2>/dev/null
        exit
    fi


    if [ -n "$last" ]; then
        # Clean up cached git add before amending last commit
        git config --unset gitbasher.cached-git-add 2>/dev/null
        git commit --amend
        exit
    fi


    ### Check if there are unstaged files
    is_clean=$(git status | tail -n 1)
    if [ "$is_clean" = "nothing to commit, working tree clean" ]; then
        if [ -z "${revert}" ]; then
            # Clean up cached git add when working tree is clean
            git config --unset gitbasher.cached-git-add 2>/dev/null
            echo -e "${GREEN}Nothing to commit, working tree clean${ENDCOLOR}"
            exit
        fi
    elif [ -n "${revert}" ]; then
        echo -e "${RED}Cannot revert! There are uncommited changes:${ENDCOLOR}"
        exit
    fi


    ### Run revert logic
    if [ -n "${revert}" ]; then
        echo -e "${YELLOW}Step 1.${ENDCOLOR} Select a commit to ${YELLOW}revert${ENDCOLOR} it:"
        
        choose_commit 20

        result=$(git revert --no-edit ${commit_hash} 2>&1)
        check_code $? "$result" "revert"

        after_commit "revert"
        exit
    fi


    ### Print status (don't need to print in fast mode because we add everything)
    if [ -z "${fast}" ]; then 
        echo -e "${YELLOW}Changed files${ENDCOLOR}"
        git_status
    fi


    ### Check for previously saved git add arguments
    saved_git_add=""
    if [ -z "${fast}" ]; then
        saved_git_add=$(git config --get gitbasher.cached-git-add 2>/dev/null)
        if [ -n "$saved_git_add" ]; then
            echo
            echo -e "${YELLOW}Found previous git add arguments:${ENDCOLOR} ${BOLD}$saved_git_add${ENDCOLOR}"
            read -n 1 -p "Use them? (y/n) " -s choice
            echo
            if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
                git add $saved_git_add
                if [ $? -eq 0 ]; then
                    git_add="$saved_git_add"
                    use_saved_git_add="true"
                else
                    echo
                    echo -e "${RED}Failed to apply saved git add arguments, continuing normally${ENDCOLOR}"
                    git config --unset gitbasher.cached-git-add 2>/dev/null
                fi
                echo
            else
                git config --unset gitbasher.cached-git-add 2>/dev/null
            fi
        fi
    fi


    ### Commit Step 1: add files to commit
    if [ -n "${fast}" ]; then
        git add .
        git_add="."
        # Clean up any existing cached git add since we're using fast mode
        git config --unset gitbasher.cached-git-add 2>/dev/null
    elif [ -n "${use_saved_git_add}" ]; then
        # Files are already staged using saved git add arguments
        echo -e "${YELLOW}Step 1.${ENDCOLOR} Using saved git add arguments: ${BOLD}$git_add${ENDCOLOR}"
        echo
    else
        echo
        printf "${YELLOW}Step 1.${ENDCOLOR} List files for "
        if [ -n "${fixup}" ]; then
            printf "${YELLOW}--fixup${ENDCOLOR} "
        elif [ -n "${squash}" ]; then
            printf "${YELLOW}--squash${ENDCOLOR} "
        elif [ -n "${amend}" ]; then
            printf "${YELLOW}--amend${ENDCOLOR} "
        fi
        if [ -n "${amend}" ]; then
            printf "to the last commit in the ${YELLOW}${current_branch}${ENDCOLOR} branch\n"
        else
            printf "commit to the ${YELLOW}${current_branch}${ENDCOLOR} branch\n"
        fi
        echo "Leave it blank to exit without changes"

        while [ true ]; do
            read -p "$(echo -n -e "${BOLD}git add${ENDCOLOR} ")" -e git_add

            # Trim spaces
            git_add=$(echo "$git_add" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            if [ "$git_add" == "" ]; then
                exit
            fi

            git add $git_add
            if [ $? -eq 0 ]; then
                # Save git add arguments for potential retry
                git config gitbasher.cached-git-add "$git_add"
                break
            fi
        done

        echo
    fi

    ### Print staged files that we add at step 1
    echo -e "${YELLOW}Staged files:${ENDCOLOR}"
    staged="$(sed 's/^/\t/' <<< "$(git diff --name-only --cached)")"
    echo -e "${GREEN}${staged}${ENDCOLOR}"


    ### Run fixup logic
    if [ -n "${fixup}" ]; then
        echo
        echo -e "${YELLOW}Step 2.${ENDCOLOR} Select a commit to ${YELLOW}--fixup${ENDCOLOR}:"

        if [ -n "${fast}" ]; then
            choose_commit 9
        else
            choose_commit 19
        fi
        
        result=$(git commit --fixup $commit_hash 2>&1)
        check_code $? "$result" "fixup"
        
        # Clean up cached git add on successful fixup
        git config --unset gitbasher.cached-git-add 2>/dev/null

        after_commit "fixup"

        if [ -n "${push}" ]; then
            echo
            push_script y
        fi

        exit
    fi


    ### Run amend logic - add staged files to the last commit
    if [ -n "${amend}" ]; then
        result=$(git commit --amend --no-edit 2>&1)
        check_code $? "$result" "amend"
        
        # Clean up cached git add on successful amend
        git config --unset gitbasher.cached-git-add 2>/dev/null

        echo
        after_commit "amend"
        exit
    fi


    ### Commit Step 2: Select commit type
    echo
    step="2"
    if [ -n "${fast}" ]; then
        step="1"
    fi
    echo -e "${YELLOW}Step ${step}.${ENDCOLOR} What ${YELLOW}type${ENDCOLOR} of changes do you want to commit?"
    echo -e "Final meesage will be ${YELLOW}<type>${ENDCOLOR}(${BLUE}<scope>${ENDCOLOR}): ${BLUE}<summary>${ENDCOLOR}"
    echo -e "1. ${BOLD}feat${ENDCOLOR}:\tnew feature, logic change or performance improvement"
    echo -e "2. ${BOLD}fix${ENDCOLOR}:\t\tsmall changes, eg. bug fix"
    echo -e "3. ${BOLD}refactor${ENDCOLOR}:\tcode change that neither fixes a bug nor adds a feature, style changes"
    echo -e "4. ${BOLD}test${ENDCOLOR}:\tadding missing tests or changing existing tests"
    echo -e "5. ${BOLD}build${ENDCOLOR}:\tchanges that affect the build system or external dependencies"
    echo -e "6. ${BOLD}ci${ENDCOLOR}:\t\tchanges to CI configuration files and scripts"
    echo -e "7. ${BOLD}chore${ENDCOLOR}:\tmaintanance and housekeeping"
    echo -e "8. ${BOLD}docs${ENDCOLOR}:\tdocumentation changes"
    echo -e "9.  \t\twrite plain commit without type and scope"
    echo -e "0. Exit without changes"

    declare -A types=(
        [1]="feat"
        [2]="fix"
        [3]="refactor"
        [4]="test"
        [5]="build"
        [6]="ci"
        [7]="chore"
        [8]="docs"
    )

    while [ true ]; do
        read -n 1 -s choice

        if [ "$choice" == "0" ]; then
            cleanup_on_exit "$git_add"
            exit
        fi

        re='^[0-9]+$'
        if ! [[ $choice =~ $re ]]; then
            continue
        fi

        if [ "$choice" == "9" ]; then
            is_empty="true"
            break
        fi

        commit_type="${types[$choice]}"
        if [ -n "$commit_type" ]; then
            break
        fi
    done

    commit=""
    if [ -z "$is_empty" ]; then
        commit="$commit_type"
    fi


    ### Commit Step 3: enter a commit scope
    if [ -z "$is_empty" ] && ([ -z "$fast" ] || [ -n "$scope" ]); then
        step="3"
        if [ -n "${fast}" ]; then
            step="2"
        fi
        echo
        echo -e "${YELLOW}Step ${step}.${ENDCOLOR} Enter a ${YELLOW}scope${ENDCOLOR} of changes to provide some additional context"
        echo -e "Final meesage will be ${BLUE}${commit_type}${ENDCOLOR}(${YELLOW}<scope>${ENDCOLOR}): ${BLUE}<summary>${ENDCOLOR}"
        echo -e "Leave it blank to continue without scope or enter 0 to exit without changes"
        
        # Detect possible scopes from staged files
        detected_scopes=""
        staged_files=$(git diff --name-only --cached)
        if [ -n "$staged_files" ]; then
            # Extract unique directory names and filenames
            declare -A scope_candidates
            
            while IFS= read -r file; do
                if [ -n "$file" ]; then
                    # Get directory path
                    dir=$(dirname "$file")
                    
                    # Skip root directory
                    if [ "$dir" != "." ]; then
                        # Extract the last directory component for nested paths
                        last_dir=$(basename "$dir")
                        scope_candidates["$last_dir"]=1
                        
                        # For paths like internal/app, also consider 'app'
                        if [[ "$dir" == */* ]]; then
                            scope_candidates["$last_dir"]=1
                        fi
                        
                        # For single-level directories like scripts/, consider the dirname
                        if [[ "$dir" != */* ]]; then
                            scope_candidates["$dir"]=1
                        fi
                    fi
                    
                    # Get filename without extension for single files
                    filename=$(basename "$file")
                    filename_no_ext="${filename%.*}"
                    
                    # Only suggest filename if it's a meaningful name (not too generic)
                    if [[ ! "$filename_no_ext" =~ ^(index|main|app|test|spec|config|readme|license)$ ]]; then
                        scope_candidates["$filename_no_ext"]=1
                    fi
                fi
            done <<< "$staged_files"
            
            # Convert to array and sort
            detected_scopes_array=()
            for scope in "${!scope_candidates[@]}"; do
                # Filter out common non-meaningful scopes
                if [[ ! "$scope" =~ ^(src|lib|test|tests|spec|specs|build|dist|node_modules|vendor)$ ]]; then
                    detected_scopes_array+=("$scope")
                fi
            done
            
            # Sort the array
            IFS=$'\n' detected_scopes_sorted=($(sort <<<"${detected_scopes_array[*]}"))
            unset IFS
            
            if [ ${#detected_scopes_sorted[@]} -gt 0 ]; then
                detected_scopes="${detected_scopes_sorted[*]}"
            fi
        fi
        
        # Use predefined scopes or detected scopes
        all_scopes=""
        if [ -n "$scopes" ]; then
            all_scopes="$scopes"
        elif [ -n "$detected_scopes" ]; then
            all_scopes="$detected_scopes"
        fi
        
        if [ -n "$all_scopes" ]; then
           IFS=' ' read -r -a scopes_array <<< "$all_scopes"

           res=""
           for i in "${!scopes_array[@]}"; do
                scope_display="${scopes_array[$i]}"
                res="$res$((i+1)). ${BOLD}${scope_display}${ENDCOLOR}|"
           done
           echo -e "You can select one of the ${YELLOW}detected scopes${ENDCOLOR}: $(echo $res | column -ts'|')"            
        fi

        while [ true ]; do
            read -p "<scope>: " -e commit_scope

            if [ "$commit_scope" == "0" ]; then
                cleanup_on_exit "$git_add"
                exit
            fi

            # Check if input is empty - continue without scope
            if [ -z "$commit_scope" ]; then
                commit="$commit: "
                break
            fi

            # Check if input is a number (index selection from scopes_array)
            re_number='^[1-9][0-9]*$'
            if [[ $commit_scope =~ $re_number ]] && [ -n "$all_scopes" ]; then
                # Try to find matching scope by index
                IFS=' ' read -r -a scopes_array <<< "$all_scopes"
                index=$((commit_scope - 1))
                if [ $index -ge 0 ] && [ $index -lt ${#scopes_array[@]} ]; then
                    selected_scope="${scopes_array[$index]}"
                    # Remove the asterisk marker if present
                    commit_scope="${selected_scope#*}"
                    commit="$commit($commit_scope): "
                    break
                else
                    echo -e "${RED}Invalid scope index! Please choose from 1-${#scopes_array[@]} or enter custom scope.${ENDCOLOR}"
                    continue
                fi
            else
                # Validate custom scope format
                re='^[a-zA-Z0-9/,_.-]+$'
                if [[ $commit_scope =~ $re ]]; then
                    commit="$commit($commit_scope): "
                    break
                else
                    echo -e "${RED}Invalid scope format! Use only letters, numbers, hyphens, underscores, and dots.${ENDCOLOR}"
                    echo -e "${RED}Debug: input was '$commit_scope'${ENDCOLOR}"
                    continue
                fi
            fi
        done

    fi

    if [ -z "$is_empty" ] && [ -n "$fast" ] && [ -z "$scope" ]; then
        commit="$commit: "
    fi


    ### Commit Step 4: enter commit message, use editor in msg mode
    if [ -n "${fast}" ]; then
        if [ -n "$scope" ]; then
            step="3"
        else
            step="2"
        fi
    elif [ -n "$is_empty" ]; then
        step="3"
    else
        step="4"
    fi
    echo
    echo -e "${YELLOW}Step ${step}.${ENDCOLOR} Write a ${YELLOW}summary${ENDCOLOR} about your changes"
    if [ -n "$is_empty" ]; then
        echo -e "Final meesage will be ${YELLOW}<summary>${ENDCOLOR}"
    elif [ "$commit_scope" == "" ]; then
        echo -e "Final meesage will be ${BLUE}${commit_type}${ENDCOLOR}: ${YELLOW}<summary>${ENDCOLOR}"
    else
        echo -e "Final meesage will be ${BLUE}${commit_type}${ENDCOLOR}(${BLUE}${commit_scope}${ENDCOLOR}): ${YELLOW}<summary>${ENDCOLOR}"
    fi
    echo -e "Leave it blank to exit without changes"
    # Use an editor and commitmsg file
    if [ -n "$msg" ]; then
        commitmsg_file=".commitmsg__"
        touch $commitmsg_file

        staged_with_tab="$(sed 's/^/####\t/' <<< "${staged}")"

        echo """
####
#### Step ${step}. Write a <summary> about your changes. Lines starting with '#' will be ignored. 
#### 
#### On branch ${current_branch}
#### Changes to be commited:
${staged_with_tab}
####
#### Here is expected format:
#### ${commit}<summary>
#### <BLANK LINE>
#### <optional body>
#### <BLANK LINE>
#### <optional footer>
####
#### Summary should provide a succinct description of the change:
####     use the imperative, present tense: 'change' not 'changed' nor 'changes'
####     no dot (.) at the end
####     don't capitalize the first letter
####
#### The body is optional and should explain why you are making the change. 
####
#### The footer is optional and should contain any information about 'Breaking Changes'.
#### Breaking Change section should start with the phrase 'BREAKING CHANGE: ' followed by a summary of the breaking change.
####
#### Similarly, a Deprecation section should start with 'DEPRECATED: ' followed by a short description of what is deprecated.
""" >> $commitmsg_file

        while [ true ]; do
            $editor $commitmsg_file
            commit_message=$(cat $commitmsg_file | sed '/^#/d')

            if [ -n "$commit_message" ]; then
                break
            fi
            echo
            echo -e "${YELLOW}Commit message cannot be empty${ENDCOLOR}"
            echo
            read -n 1 -p "Try for one more time? (y/n) " -s -e choice
            if [ "$choice" != "y" ]; then
                cleanup_on_exit "$git_add"
                find . -name "$commitmsg_file*" -delete
                exit
            fi    
        done

        find . -name "$commitmsg_file*" -delete

    # Use read from console
    else
        read -p "$(echo -n -e "${commit}")" -e commit_message
        if [ -z "$commit_message" ]; then
            cleanup_on_exit "$git_add"
            exit
        fi
    fi


    ### Commit Step 5: enter tracker ticket
    if [ -n "${ticket}" ]; then
        echo
        echo -e "${YELLOW}Step 5.${ENDCOLOR} Enter the number of a resolved issue (e.g. in JIRA or Youtrack)"
        echo -e "It will be added to the end of the summary header"
        echo -e "Leave it blank to continue or 0 to exit without changes"

        if [ -n "$ticket_name" ]; then
            read -p "${ticket_name}${sep}" -e commit_ticket
        else 
            read -p "<ticket>: " -e commit_ticket
        fi
        if [ "$commit_ticket" == "0" ]; then
            cleanup_on_exit "$git_add"
            exit
        fi

        if [ "$commit_ticket" != "" ]; then
            commit_ticket=$(echo "$commit_ticket" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

            summary=$(echo "$commit_message" | head -n 1)
            remaining_message=""
            if [ "$summary" != "$commit_message" ]; then
                remaining_message=$(echo "$commit_message" | tail -n +2)
                remaining_message="""
    $remaining_message"
            fi
            if [ -n "$ticket_name" ]; then
                commit_ticket="${ticket_name}${sep}${commit_ticket}"
            fi
            commit_message="$summary ($commit_ticket)$remaining_message"
        fi
    fi

    commit="${commit}${commit_message}"


    ### Finally
    echo

    result=$(git commit -m """$commit""" 2>&1)
    check_code $? "$result" "commit"
    
    # Clean up cached git add on successful commit
    git config --unset gitbasher.cached-git-add 2>/dev/null
    
    after_commit

    if [ -n "${push}" ]; then
        echo
        push_script y
    fi
}
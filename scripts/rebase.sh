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
function rebase_script {
    case "$1" in
        main|master|m)           main="true";;
        interactive|i)           interactive="true";;
        autosquash|a|s|f|ia|if)  autosquash="true";;
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
    elif [ -n "${main}" ]; then
        header="$header MAIN"
    fi
    echo -e "${YELLOW}${header}${ENDCOLOR}"
    echo


    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb rebase <mode>${ENDCOLOR}"
        echo
        echo -e "${YELLOW}Available modes${ENDCOLOR}"
        echo -e "<empty>\t\t\tSelect base branch to rebase current changes"
        echo -e "main|master|m\t\tRebase current branch onto default branch"
        echo -e "interactive|i\t\tSelect base commit in current branch and rebase in an interactive mode"
        echo -e "autosquash|a|s|f|ia|if\tRebase on the current local branch in an interactive mode with --autosquash"
        echo -e "help|h\t\t\tShow this help"
        exit
    fi



    is_clean=$(git status | tail -n 1)
    if [ "$is_clean" != "nothing to commit, working tree clean" ]; then
        echo -e "${RED}Cannot rebase! There are uncommited changes:"
        git_status
        exit 1
    fi


    ### Select branch which will become a base
    if [ -n "$main" ]; then
        if [ "$current_branch" == "${main_branch}" ]; then
            echo -e "${YELLOW}Already on ${main_branch}${ENDCOLOR}"
            exit
        fi
        new_base_branch=${main_branch}

    elif [ -n "$autosquash" ]; then
        new_base_branch=${current_branch}
    else
        echo -e "${YELLOW}Select which branch will become a new base for '${current_branch}'${ENDCOLOR}"
        choose_branch "rebase"
        new_base_branch=${branch_name}
        echo
    fi

    if [ -z "$autosquash" ]; then
        ### Fetch before rebase
        echo -e "Fetch ${YELLOW}${origin_name}/${new_base_branch}${ENDCOLOR} before rebase (y/n/0)?"
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
        echo
    fi


    ### Run rebase and handle conflicts

    rebase_branch "$new_base_branch" "$origin_name" "$from_origin" "$interactive" "$autosquash" "$autosquash"


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
# $6: base commit for autosquash
# Returns:
#      * rebase_output
#      * rebase_code - 0 if everything is ok, not zero if there are conflicts
function rebase_branch {
    ref=$1
    if [ "$3" == "true" ]; then
        ref=$2/$1
    fi

    if [ "$5" == "true" ]; then
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
            re='^[01234]+$'
            if [[ $choice =~ $re ]]; then
                break
            fi
        done

        if [ "$choice" == "1" ]; then
            files_with_conflicts_one_line="$(tr '\n' ' ' <<< "$(git --no-pager diff --name-only --diff-filter=U --relative)")"
            files_with_conflicts_new="$(git grep -l --name-only -E "[<=>]{7} HEAD" $files_with_conflicts_one_lined)"
            
            if [ "$files_with_conflicts_new" != "" ]; then
                echo
                echo -e "${YELLOW}There are files with conflicts${ENDCOLOR}"
                echo -e "$(echo -e "${files_with_conflicts_new}" | tr ' ' '\n' | sed 's/^/\t/')"
                continue
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

        if [ "$choice" == "0" ]; then
            exit
        fi
    done
}


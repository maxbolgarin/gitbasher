#!/usr/bin/env bash

### Script for rebasing commits
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Main function
# $1: mode
    # empty: select base branch to rebase current changes
    # main: rebase current branch onto default branch
    # interactive: select base commit in current branch and rebase in interactive mode
    # autosquash: rebase in interactive mode with --autosquash
function rebase_script {
    case "$1" in
        main|master|m) main="true";;
        interactive|i)          
            interactive="true"
            args="--interactive"
        ;;
        autosquash|s|ia|is)     
            autosquash="true"
            args="--interactive --autosquash"
        ;;
        help|h)                 help="true";;
        *)
            wrong_mode "rebase" $1
    esac

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb rebase <mode>${ENDCOLOR}"
        echo
        echo -e "${YELLOW}Available modes${ENDCOLOR}"
        echo -e "<empty>\t\t\tSelect base branch to rebase current changes"
        echo -e "main|master|m\t\tRebase current branch onto default branch"
        echo -e "interactive|i\t\tSelect base commit in current branch and rebase in interactive mode"
        echo -e "autosquash|s|ia|is\tRebase in interactive mode with --autosquash"
        echo -e "help|h\t\t\tShow this help"
        exit
    fi

    ### Merge mode - print header
    header="GIT REBASE"
    if [ -n "${interactive}" ]; then
        header="$header INTERACTIVE"
    elif [ -n "${autosquash}" ]; then
        header="$header INTERACTIVE AUTOSQUASH"
    fi
    echo -e "${YELLOW}${header}${ENDCOLOR}"
    echo


    ### Select branch which will become a base
    if [ -n "$main" ]; then
        if [ "$current_branch" == "${main_branch}" ]; then
            echo -e "${YELLOW}Already on ${main_branch}${ENDCOLOR}"
            exit
        fi
        new_base_branch=${main_branch}

    else
        echo -e "${YELLOW}Choose which branch will become a new base for '${current_branch}'${ENDCOLOR}"
        choose_branch "rebase"
        new_base_branch=${branch_name}
        echo
    fi


    ### Fetch before rebase
    echo -e "Do you want to use ${YELLOW}${origin_name}/${new_base_branch}${ENDCOLOR} (y/n)?"
    read -n 1 -s choice
    if [ "$choice" == "y" ]; then
        echo
        echo -e "${YELLOW}Fetching ${origin_name}/${new_base_branch}...${ENDCOLOR}"

        fetch $new_base_branch $origin_name
        from_origin=true
    fi
    echo

    
    ### Run rebase and handle conflicts
    rebase_branch $new_base_branch $origin_name $from_origin


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
# Returns:
#      * rebase_output
#      * rebase_code - 0 if everything is ok, not zero if there are conflicts
function rebase_branch {
    if [ "$3" == "true" ]; then
        rebase_output=$(git rebase $2/$1 2>&1)
    else
        rebase_output=$(git rebase $1 2>&1)
    fi
    rebase_code=$?

    if [ $rebase_code == 0 ] ; then
        return
    fi

    ### Cannot rebase because there are uncommitted files
    if [[ $rebase_output == *"Please commit or stash them"* ]]; then
        echo -e "${RED}Cannot rebase! There are uncommited changes, you should commit them first"
        echo 
        git status -s
        exit $rebase_code
    fi

    ### Cannot merge because of some other error
    if [[ $rebase_output != *"CONFLICT"* ]]; then
        echo -e "${RED}Cannot rebase! Error message:${ENDCOLOR}"
        echo "$rebase_output"
        exit $rebase_code
    fi

    echo -e "${RED}Cannot rebase! There are conflicts${ENDCOLOR}"
    rebase_conflicts $rebase_output

    # TODO: success
}

### Function pulls provided branch, handles errors and makes a merge
# $1: rebase_output
function rebase_conflicts {
    ### Ask user what he wants to do
    echo
    echo -e "${YELLOW}You should resolve conflicts manually${ENDCOLOR}"
    echo -e "After resolving, select an option to continue:"
    echo -e "1. Add changes and continue: ${YELLOW}git rebase --continue${ENDCOLOR}"
    echo -e "2. Open editor to change rebase plan: ${YELLOW}git rebase --edit-todo${ENDCOLOR}"
    echo -e "3. Skip this commit (this will throw away this commit from history!): ${YELLOW}git rebase --skip${ENDCOLOR}"
    echo -e "4. Abort rebase and return to the original state: ${YELLOW}git rebase --abort${ENDCOLOR}"
    echo -e "Press any another key to exit from this script ${BOLD}without${NORMAL} rebase abort"

    ### Rebase process
    while [ true ]; do
        ### Print files with conflicts
        # echo
        # echo -e "${YELLOW}Files with conflicts${ENDCOLOR}"
        # IFS=$'\n' read -rd '' -a files_with_conflicts <<<"$(git --no-pager diff --name-only --diff-filter=U --relative)"
        # echo -e "$(sed 's/^/\t/' <<< "$files_with_conflicts")"
        # echo

    # Step 1/18: pick 52e4928 test: for rebase
    #     README.md
    #     Makefile

        status=$(git status)
        current_step=$(echo "$status" | sed -n 's/.*Last command done (\([0-9]*\) command done):/\1/p')
        total_steps=$(echo "$status" | sed -n 's/.*Next commands to do (\([0-9]*\) remaining commands):/\1/p')
        commit_name=$(echo "$status" | head -n 3 | tail -n 1)
        files=$(echo $status | sed -n '/^Unmerged paths:/,/^$/p' | sed '/^Unmerged paths:/d;/^$/d;/^ *(/d')

        echo
        echo -e "${YELLOW}Step $current_step/$total_steps:${ENDCOLOR} $commit_name"
        echo -e "$files"

        read -n 1 -s choice

        re='^[1-9]+$'
        if ! [[ $choice =~ $re ]]; then
            exit
        fi

        if [ "$choice" == "1" ]; then
            files_with_conflicts_one_line="$(tr '\n' ' ' <<< "$files_with_conflicts")"
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
                echo -e "Fix conflicts and press ${YELLOW}1${ENDCOLOR} for one more time"
                merge_error="true"
                continue
            fi

            git add $files_with_conflicts_one_line

            rebase_output=$(git -c core.editor=true rebase --continue)
            rebase_code=$?

            if [[ $rebase_output == *"Successfully rebased"* ]]; then
                return
            fi

            if [[ $rebase_output != *"CONFLICT"* ]]; then
                echo -e "${RED}Cannot rebase! Error message:${ENDCOLOR}"
                echo "$rebase_output"
                exit $rebase_code
            fi
        fi

        if [ "$choice" == "2" ]; then
            git rebase --edit-todo
            ## TODO: handle todo
        fi

        if [ "$choice" == "3" ]; then
            git rebase --skip
            ## TODO: handle skip
        fi


        if [ "$choice" == "4" ]; then
            echo
            echo -e "${YELLOW}Aborting rebase...${ENDCOLOR}"
            git rebase --abort
            exit $?
        fi
    done
}


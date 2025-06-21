#!/usr/bin/env bash

### Script for managing git stashes: create, list, pop, show
# Read README.md to get more information how to use it
# Use this script only with gitbasher


### Function to select files for stashing using git add pattern
# Returns: 
#     git_add - files to add temporarily for stashing
function select_files_for_stash {
    echo -e "${YELLOW}Select files to stash:${ENDCOLOR}"
    echo
    
    # Show current status
    git_status
    echo

    echo -e "Enter file patterns or paths to stash (like ${BOLD}git add${ENDCOLOR} command)"
    echo "Press Enter if you want to exit"

    while [ true ]; do
        read -p "$(echo -n -e "${BOLD}files to stash${ENDCOLOR} ")" -e git_add

        # Trim spaces and remove quotes
        git_add=$(echo "$git_add" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e "s/^'//" -e "s/'$//")
        if [ "$git_add" == "" ]; then
            exit
        fi

        # Test if the pattern matches any changed files
        # Use git add --dry-run to see what would be added
        test_result=$(git add --dry-run "$git_add" 2>&1)
        test_code=$?
        
        if [ $test_code -eq 0 ] && [ -n "$test_result" ]; then
            break
        else
            # Check if error is about "did not match any files" and try with * appended
            if [[ "$test_result" == *"did not match any files"* ]] && [[ "$git_add" != *"*" ]]; then
                git_add_with_star="${git_add}*"
                echo -e "${YELLOW}Trying with wildcard:${ENDCOLOR} ${BOLD}$git_add_with_star${ENDCOLOR}"
                test_result_star=$(git add --dry-run "$git_add_with_star" 2>&1)
                if [ $? -eq 0 ] && [ -n "$test_result_star" ]; then
                    git_add="$git_add_with_star"
                    break
                else
                    echo -e "${RED}No changed files match pattern: $git_add_with_star${ENDCOLOR}"
                    echo
                fi
            else
                echo -e "${RED}No changed files match pattern: $git_add${ENDCOLOR}"
                echo
            fi
        fi
    done
}


### Function to list all stashes
# Returns:
#     stashes_info - array of stash info
#     stashes_refs - array of stash refs
function list_stashes {
    IFS=$'\n' read -rd '' -a stashes_info <<<"$(git stash list --pretty=format:"${YELLOW_ES}%gd${ENDCOLOR_ES} | %s | ${BLUE_ES}%cr${ENDCOLOR_ES}")"
    IFS=$'\n' read -rd '' -a stashes_refs <<<"$(git stash list --pretty=format:"%gd")"

    if [ ${#stashes_info[@]} -eq 0 ]; then
        echo -e "${GREEN}No stashes found${ENDCOLOR}"
        return 1
    fi

    echo -e "${YELLOW}Available stashes:${ENDCOLOR}"
    echo
    for index in "${!stashes_info[@]}"; do
        # Format each stash entry properly
        stash_line="${stashes_info[index]}"
        # Replace | with proper spacing for better readability
        formatted_line=$(echo "$stash_line" | sed 's/ | /\t/g')
        echo -e "$(($index+1)). $formatted_line"
    done
    echo

    return 0
}


### Function to choose a stash
# Returns:
#     selected_stash - selected stash reference
function choose_stash {
    if ! list_stashes; then
        return 1
    fi

    if [ ${#stashes_refs[@]} -gt 9 ]; then
        echo "00. Exit"
    else
        echo "0. Exit"
    fi
    echo

    read_prefix="Select stash number: "

    choose "${stashes_refs[@]}"
    echo
    selected_stash=$choice_result
}


### Function to show stash details
# $1: stash reference
function show_stash {
    echo -e "${YELLOW}Stash details for $1${ENDCOLOR}"
    echo
    git stash show -p "$1"
}


### Main function
# $1: mode
    # <empty> - interactive menu
    # select|sel - select specific files to stash
    # all - stash all changes
    # list|l - list all stashes
    # pop|p - pop from selected stash
    # show|s - show stash contents
    # drop|d - drop selected stash
    # apply|a - apply selected stash without removing it
function stash_script {
    case "$1" in
        select|sel)     select_mode="true";;
        all)            all_mode="true";;
        list|l)         list_mode="true";;
        pop|p)          pop_mode="true";;
        show|s)         show_mode="true";;
        drop|d)         drop_mode="true";;
        apply|a)        apply_mode="true";;
        help|h)         help="true";;
        *)
            if [ -n "$1" ]; then
                wrong_mode "stash" "$1"
            fi
            # If no mode specified, show interactive menu
            interactive="true"
    esac

    ### Print header
    header_msg="GIT STASH"
    if [ -n "${select_mode}" ]; then
        header_msg="${YELLOW}$header_msg SELECT${ENDCOLOR}"
    elif [ -n "${all_mode}" ]; then
        header_msg="${YELLOW}$header_msg ALL${ENDCOLOR}"
    elif [ -n "${list_mode}" ]; then
        header_msg="${YELLOW}$header_msg LIST${ENDCOLOR}"
    elif [ -n "${pop_mode}" ]; then
        header_msg="${YELLOW}$header_msg POP${ENDCOLOR}"
    elif [ -n "${show_mode}" ]; then
        header_msg="${YELLOW}$header_msg SHOW${ENDCOLOR}"
    elif [ -n "${drop_mode}" ]; then
        header_msg="${RED}$header_msg DROP${ENDCOLOR}"
    elif [ -n "${apply_mode}" ]; then
        header_msg="${YELLOW}$header_msg APPLY${ENDCOLOR}"
    else
        header_msg="${YELLOW}$header_msg${ENDCOLOR}"
    fi

    echo -e "${header_msg}"
    echo

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb stash <mode>${ENDCOLOR}"
        echo
        echo -e "${YELLOW}Available modes${ENDCOLOR}"
        echo -e "<empty>\t\tShow interactive menu"
        echo -e "select|sel\tSelect files to stash"
        echo -e "all\t\tStash all changes"
        echo -e "list|l\t\tList all stashes"
        echo -e "pop|p\t\tPop from selected stash"
        echo -e "show|s\t\tShow stash contents"
        echo -e "apply|a\t\tApply selected stash without removing it"
        echo -e "drop|d\t\tDrop selected stash"
        echo -e "help|h\t\tShow this help"
        exit
    fi

    ### Interactive menu mode
    if [ -n "$interactive" ]; then
        echo -e "${YELLOW}What do you want to do?${ENDCOLOR}"
        echo
        echo "1. Select files to stash"
        echo "2. Stash all changes"
        echo "3. List all stashes"
        echo "4. Pop from stash"
        echo "5. Show stash contents"
        echo "6. Apply stash (without removing)"
        echo "7. Drop stash"
        echo "0. Exit"
        
        read -n 1 -s choice
        echo

        case "$choice" in
            1) select_mode="true";;
            2) all_mode="true";;
            3) list_mode="true";;
            4) pop_mode="true";;
            5) show_mode="true";;
            6) apply_mode="true";;
            7) drop_mode="true";;
            0) exit;;
            *) echo -e "${RED}Invalid option${ENDCOLOR}"; exit 1;;
        esac
    fi

    ### Select files to stash
    if [ -n "$select_mode" ]; then
        select_files_for_stash

        echo
        echo -e "${YELLOW}Changed files to stash:${ENDCOLOR}"
        # Show what files would be staged (changed files only)
        files_to_stash=$(git add --dry-run "$git_add" 2>/dev/null | sed 's/^add /\t/' | sed "s/'//g")
        echo -e "${GREEN}$files_to_stash${ENDCOLOR}"
        echo

        read -p "Enter stash message: " stash_message
        if [ -z "$stash_message" ]; then
            exit 0
        fi

        echo -e "${YELLOW}Stashing selected files...${ENDCOLOR}"
        echo

        # Create a temporary stash with only the specified files
        # First stage the files
        result=$(git add "$git_add" 2>&1)
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to stage files! Error:${ENDCOLOR}"
            echo "$result"
            exit 1
        fi

        # Stash staged files
        stash_output=$(git stash push -m "$stash_message" --staged 2>&1)
        stash_code=$?

        if [ $stash_code -eq 0 ]; then
            echo -e "${GREEN}Successfully stashed selected files!${ENDCOLOR}"
            echo "$stash_output"
        else
            echo -e "${RED}Failed to stash files! Error:${ENDCOLOR}"
            echo "$stash_output"
            # Restore staged files on error
            git restore --staged "$git_add" 2>/dev/null
            exit $stash_code
        fi
    fi

    ### Stash all changes
    if [ -n "$all_mode" ]; then
        # Check if there are changes to stash
        if git diff --quiet && git diff --cached --quiet; then
            echo -e "${GREEN}No changes to stash${ENDCOLOR}"
            exit
        fi

        read -p "Enter stash message: " stash_message
        if [ -z "$stash_message" ]; then
            exit 0
        fi

        echo -e "${YELLOW}Stashing all changes...${ENDCOLOR}"
        echo

        stash_output=$(git stash push -m "$stash_message" --include-untracked 2>&1)
        stash_code=$?

        if [ $stash_code -eq 0 ]; then
            echo -e "${GREEN}Successfully stashed all changes!${ENDCOLOR}"
            echo "$stash_output"
        else
            echo -e "${RED}Failed to stash changes! Error:${ENDCOLOR}"
            echo "$stash_output"
            exit $stash_code
        fi
    fi

    ### List stashes
    if [ -n "$list_mode" ]; then
        if ! list_stashes; then
            exit
        fi
    fi

    ### Pop from stash
    if [ -n "$pop_mode" ]; then
        if ! choose_stash; then
            exit 1
        fi

        echo -e "${YELLOW}Popping from stash $selected_stash...${ENDCOLOR}"
        echo

        pop_output=$(git stash pop "$selected_stash" 2>&1)
        pop_code=$?

        if [ $pop_code -eq 0 ]; then
            echo -e "${GREEN}Successfully popped from stash!${ENDCOLOR}"
            echo "$pop_output"
        else
            echo -e "${RED}Failed to pop from stash! Error:${ENDCOLOR}"
            echo "$pop_output"
            exit $pop_code
        fi
    fi

    ### Show stash contents
    if [ -n "$show_mode" ]; then
        if ! choose_stash; then
            exit 1
        fi

        show_stash "$selected_stash"
    fi

    ### Apply stash without removing
    if [ -n "$apply_mode" ]; then
        if ! choose_stash; then
            exit 1
        fi

        echo -e "${YELLOW}Applying stash $selected_stash...${ENDCOLOR}"
        echo

        apply_output=$(git stash apply "$selected_stash" 2>&1)
        apply_code=$?

        if [ $apply_code -eq 0 ]; then
            echo -e "${GREEN}Successfully applied stash!${ENDCOLOR}"
            echo "$apply_output"
        else
            echo -e "${RED}Failed to apply stash! Error:${ENDCOLOR}"
            echo "$apply_output"
            exit $apply_code
        fi
    fi

    ### Drop stash
    if [ -n "$drop_mode" ]; then
        if ! choose_stash; then
            exit 1
        fi
        
        echo
        echo -e "${RED}Are you sure you want to drop stash $selected_stash? This cannot be undone!${ENDCOLOR}"
        echo -e "Do you want to continue (y/n)?"
        yes_no_choice "Dropping stash"

        drop_output=$(git stash drop "$selected_stash" 2>&1)
        drop_code=$?

        if [ $drop_code -eq 0 ]; then
            echo -e "${GREEN}Successfully dropped stash!${ENDCOLOR}"
            echo "$drop_output"
        else
            echo -e "${RED}Failed to drop stash! Error:${ENDCOLOR}"
            echo "$drop_output"
            exit $drop_code
        fi
    fi
} 
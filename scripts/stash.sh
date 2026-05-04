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
    echo "Press Enter to exit without changes"

    while [ true ]; do
        read_editable_input git_add "$(echo -n -e "${BOLD}files to stash${ENDCOLOR} ")"

        # Sanitize file pattern input
        if [ "$git_add" == "" ]; then
            exit
        fi
        
        if ! sanitize_file_path "$git_add"; then
            show_sanitization_error "file pattern" "Invalid file path or pattern. Avoid dangerous characters and sequences."
            continue
        fi
        git_add="$sanitized_file_path"

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
                    echo -e "${RED}✗ No changed files match pattern: $git_add_with_star${ENDCOLOR}"
                    echo
                fi
            else
                echo -e "${RED}✗ No changed files match pattern: $git_add${ENDCOLOR}"
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
        echo -e "${YELLOW}No stashes found.${ENDCOLOR}"
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
    # kcov-skip-start

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
        # kcov-skip-start
        echo -e "usage: ${YELLOW}gitb stash <mode>${ENDCOLOR}"
        echo
        local PAD=14
        print_help_header $PAD
        print_help_row $PAD "<empty>" ""    "Show the interactive menu"
        print_help_row $PAD "all"     ""    "Stash all changes (including untracked)"
        print_help_row $PAD "select"  "sel" "Pick specific files to stash"
        print_help_row $PAD "list"    "l"   "List existing stashes"
        print_help_row $PAD "pop"     "p"   "Pop a stash (apply and remove)"
        print_help_row $PAD "show"    "s"   "Show the contents of a stash"
        print_help_row $PAD "apply"   "a"   "Apply a stash without removing it"
        print_help_row $PAD "drop"    "d"   "Drop (delete) a stash"
        print_help_row $PAD "help"    "h"   "Show this help"
        echo
        echo -e "${YELLOW}Examples${ENDCOLOR}"
        echo -e "  ${GREEN}gitb stash${ENDCOLOR}        Open the interactive menu"
        echo -e "  ${GREEN}gitb stash all${ENDCOLOR}    Stash everything with one prompt for a message"
        echo -e "  ${GREEN}gitb stash pop${ENDCOLOR}    Pick a stash and pop it"
        echo -e "  ${GREEN}gitb stash list${ENDCOLOR}   See what's stashed"
        exit
        # kcov-skip-end
    fi

    ### Interactive menu mode
    if [ -n "$interactive" ]; then
        echo -e "${YELLOW}What do you want to do?${ENDCOLOR}"
        echo
        echo "1. Select files to stash"
        echo "2. Stash all changes"
        echo "3. List all stashes"
        echo "4. Pop from a stash"
        echo "5. Show stash contents"
        echo "6. Apply stash (without removing)"
        echo "7. Drop a stash"
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
            *) echo -e "${RED}✗ Invalid choice.${ENDCOLOR}"; exit 1;;
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

        read_editable_input stash_message "Enter stash message: "
        if [ -z "$stash_message" ]; then
            exit 0
        fi
        
        # Sanitize stash message
        if ! sanitize_text_input "$stash_message" 200; then
            show_sanitization_error "stash message" "Use printable characters only, max 200 characters."
            exit 1
        fi
        stash_message="$sanitized_text"

        echo -e "${YELLOW}Stashing selected files...${ENDCOLOR}"
        echo

        # Create a temporary stash with only the specified files
        # First stage the files
        result=$(git add $git_add 2>&1)
        if [ $? -ne 0 ]; then
            echo -e "${RED}✗ Cannot stage files.${ENDCOLOR}"
            echo "$result"
            exit 1
        fi

        # Stash staged files
        stash_output=$(git stash push -m "$stash_message" --staged 2>&1)
        stash_code=$?

        if [ $stash_code -eq 0 ]; then
            echo -e "${GREEN}✓ Stashed selected files${ENDCOLOR}"
            echo "$stash_output"
        else
            echo -e "${RED}✗ Cannot stash files.${ENDCOLOR}"
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
            echo -e "${GREEN}✓ No changes to stash${ENDCOLOR}"
            exit
        fi

        read_editable_input stash_message "Enter stash message: "
        if [ -z "$stash_message" ]; then
            exit 0
        fi
        
        # Sanitize stash message
        if ! sanitize_text_input "$stash_message" 200; then
            show_sanitization_error "stash message" "Use printable characters only, max 200 characters."
            exit 1
        fi
        stash_message="$sanitized_text"

        echo -e "${YELLOW}Stashing all changes...${ENDCOLOR}"
        echo

        stash_output=$(git stash push -m "$stash_message" --include-untracked 2>&1)
        stash_code=$?

        if [ $stash_code -eq 0 ]; then
            echo -e "${GREEN}✓ Stashed all changes${ENDCOLOR}"
            echo "$stash_output"
        else
            echo -e "${RED}✗ Cannot stash changes.${ENDCOLOR}"
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
            echo -e "${GREEN}✓ Popped stash${ENDCOLOR}"
            echo "$pop_output"
        else
            echo -e "${RED}✗ Cannot pop stash.${ENDCOLOR}"
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
            echo -e "${GREEN}✓ Applied stash${ENDCOLOR}"
            echo "$apply_output"
        else
            echo -e "${RED}✗ Cannot apply stash.${ENDCOLOR}"
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
        echo -e "${RED}⚠  Dropping stash $selected_stash cannot be undone.${ENDCOLOR}"
        echo -e "Are you sure you want to drop it (y/n)?"
        yes_no_choice "Dropping stash"

        drop_output=$(git stash drop "$selected_stash" 2>&1)
        drop_code=$?

        if [ $drop_code -eq 0 ]; then
            echo -e "${GREEN}✓ Dropped stash${ENDCOLOR}"
            echo "$drop_output"
        else
            echo -e "${RED}✗ Cannot drop stash.${ENDCOLOR}"
            echo "$drop_output"
            exit $drop_code
        fi
    fi
    # kcov-skip-end
}
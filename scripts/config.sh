#!/usr/bin/env bash

### Script for configurate gitbasher
# Read README.md to get more information how to use it
# Use this script only with gitbasher because it is using global variables


### Get configuration from git config
main_branch=$(get_config_value gitbasher.branch "$main_branch")
sep=$(get_config_value gitbasher.sep "_")
editor=$(get_config_value core.editor "vim")

### Is this is a first run of gitbasher in this project?
is_first=$(get_config_value gitbasher.isfirst "true")
set_config_value gitbasher.isfirst false > /dev/null

project_name="$(get_repo_name)"
repo_url="$(get_repo)"


### Function asks user to select default gitbasher branch
function set_main_branch {
    echo -e "${YELLOW}Fetching remote branches...${ENDCOLOR}"
    echo

    fetch_output=$(git fetch 2>&1)
    check_code $? "$fetch_output" "fetch remote"

    prune_output=$(git remote prune $origin_name 2>&1)

    echo -e "Current gitbasher default branch: ${YELLOW}$main_branch${ENDCOLOR}"
    echo
    
    echo -e "${YELLOW}Select a branch to make it default in gitbasher${ENDCOLOR}"
    choose_branch "remote"

    echo 

    main_branch=$(set_config_value gitbasher.branch $branch_name)
    echo -e "${GREEN}Set '${branch_name}' as a default gitbasher branch in '${project_name}' repo${ENDCOLOR}"

    echo -e "Do you want to set it globally for all projects (y/n)?"
    yes_no_choice "\nSet '${branch_name}' globally" "true"
    main_branch=$(set_config_value gitbasher.branch $branch_name "true")
}


### Function asks user to select branch name separator
function set_sep {
    echo -e "${YELLOW}Select a branch name separator${ENDCOLOR}"
    echo -e "Separator is a symbol between type and name, e.g. ${YELLOW}name${sep}name${ENDCOLOR}"
    echo -e "Current separator: ${YELLOW}$sep${ENDCOLOR}"
    echo -e "1. type${YELLOW}/${ENDCOLOR}name"
    echo -e "2. type${YELLOW}_${ENDCOLOR}name"
    echo -e "3. type${YELLOW}-${ENDCOLOR}name"
    echo -e "4. type${YELLOW}.${ENDCOLOR}name"
    echo -e "5. type${YELLOW},${ENDCOLOR}name"
    echo -e "6. type${YELLOW}+${ENDCOLOR}name"
    echo -e "7. type${YELLOW}=${ENDCOLOR}name"
    echo -e "8. type${YELLOW}@${ENDCOLOR}name"
    echo "0. Exit without changes"
    
    declare -A seps=(
            [1]="/"
            [2]="_"
            [3]="-"
            [4]="."
            [5]=","
            [6]="+"
            [7]="="
            [8]="@"
        )

    while [ true ]; do
        read -n 1 -s choice

        if [ "$choice" == "0" ]; then
            exit
        fi

        re='^[0-9]+$'
        if ! [[ $choice =~ $re ]]; then
            continue
        fi

        new_sep="${seps[$choice]}"
        if [ -n "$new_sep" ]; then
            break
        fi
    done

    echo

    sep=$(set_config_value gitbasher.sep $new_sep)
    echo -e "${GREEN}Set '${sep}' as a branch name separator in '${project_name}' repo${ENDCOLOR}"

    echo -e "Do you want to set it globally for all projects (y/n)?"
    yes_no_choice "\nSet '${sep}' globally" "true"
    sep=$(set_config_value gitbasher.sep $branch_name $new_sep)
}


### Function asks user to enter editor for commit messages
function set_editor {
    echo -e "${YELLOW}Enter an editor for commit messages${ENDCOLOR}"
    echo -e "Enter the bin name of editor to run for creating commit messages (e.g. 'vim' or 'nano')"
    echo -e "It will override ${YELLOW}core.editor${ENDCOLOR} git config value, leave it blank to exit without changes"
    echo -e "Current editor: ${YELLOW}${editor}${ENDCOLOR}"
    read -p "Editor: " choice

    if [ "$choice" == "" ]; then
        exit
    fi

    echo

    which_output=$(which $choice)
    if [ "${which_output}" == *"not found"* ] || [ "${which_output}" == "" ]; then
        echo -e "${RED}Binary '${choice}' not found!${ENDCOLOR}"
        exit
    fi

    editor=$(set_config_value core.editor $choice)
    echo -e "${GREEN}Use editor '$editor' located at '$which_output'${ENDCOLOR}"

    echo -e "Do you want to set it globally for all projects (y/n)?"
    yes_no_choice "\nSet '${editor}' globally" "true"
    sep=$(set_config_value core.editor $branch_name $new_sep)
}


### Main function
# $1: mode
    # empty: NOT WOIRKIGN
    # main: set main branch
    # sep: set branch separator
    # editor: set commit message editor
function config_script {
    case "$1" in
        main|master)  set_main_cfg="true";;
        separator|sep)          set_sep_cfg="true";;
        editor)       set_editor_cfg="true";;
    esac

    if [ "$set_main_cfg" == "true" ]; then
        set_main_branch
        exit
    fi

    if [ "$set_sep_cfg" == "true" ]; then
        set_sep
        exit
    fi

    if [ "$set_editor_cfg" == "true" ]; then
        set_editor
        exit
    fi

    echo -e "usage: ${YELLOW}gitb config <name>${ENDCOLOR}"
    echo
    echo -e "${YELLOW}Available names for configuration${ENDCOLOR}"
    echo -e "main\t\tUpdate gitbasher's default branch (not remote git repo!)"
    echo -e "sep\t\tUpdate separator between type and name in branch"
    echo -e "editor\t\tUpdate text editor for commit messages"
}

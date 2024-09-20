#!/usr/bin/env bash

### Script for configurate gitbasher
# Read README.md to get more information how to use it
# Use this script only with gitbasher because it is using global variables


### Get configuration from git config
main_branch=$(get_config_value gitbasher.branch "$main_branch")
sep=$(get_config_value gitbasher.sep "-")
editor=$(get_config_value core.editor "vi")
ticket_name=$(get_config_value gitbasher.ticket "")

### Is this is a first run of gitbasher in this project?
is_first=$(get_config_value gitbasher.isfirst "true")
set_config_value gitbasher.isfirst false > /dev/null

project_name="$(get_repo_name)"
repo_url="$(get_repo)"


### Function asks user to select default gitbasher branch
function set_default_branch {
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
    echo

    echo -e "Do you want to set it ${YELLOW}globally${ENDCOLOR} for all projects (y/n)?"
    yes_no_choice "\nSet '${branch_name}' globally" "true"
    main_branch=$(set_config_value gitbasher.branch $branch_name "true")
}


### Function asks user to select branch name separator
function set_sep {
    echo -e "${YELLOW}Select a branch name separator${ENDCOLOR}"
    echo
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
    echo

    echo -e "Do you want to set it ${YELLOW}globally${ENDCOLOR} for all projects (y/n)?"
    yes_no_choice "\nSet '${sep}' globally" "true"
    sep=$(set_config_value gitbasher.sep $branch_name $new_sep)
}


### Function asks user to enter editor for commit messages
function set_editor {
    echo -e "${YELLOW}Enter an editor for commit messages${ENDCOLOR}"
    echo
    echo -e "Enter the bin name of editor to run for creating commit messages (e.g. 'vi' or 'nano')"
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
    echo

    echo -e "Do you want to set it ${YELLOW}globally${ENDCOLOR} for all projects (y/n)?"
    yes_no_choice "\nSet '${editor}' globally" "true"
    sep=$(set_config_value core.editor $branch_name $new_sep)
}


### Function asks user to enter ticket name
function set_ticket {
    if [ -z $ticket_name ]; then
        echo -e "${YELLOW}Current gitbasher ticket name is not set${ENDCOLOR}"
    else
        echo -e "Current gitbasher ticket name: ${YELLOW}$ticket_name${ENDCOLOR}"
    fi
    echo
    
    echo -e "${YELLOW}Enter a new ticket name${ENDCOLOR}"
    read -p "Ticket name: " -e ticket_name

    if [ -z $ticket_name ]; then
        exit
    fi

    ticket_name="${ticket_name##*( )}"

    echo 

    ticket_name=$(set_config_value gitbasher.ticket $ticket_name)
    echo -e "${GREEN}Set '${ticket_name}' as a ticket name in '${project_name}' repo${ENDCOLOR}"
    echo

    echo -e "Do you want to set it ${YELLOW}globally${ENDCOLOR} for all projects (y/n)?"
    yes_no_choice "\nSet '${ticket_name}' globally" "true"
    ticket_name=$(set_config_value gitbasher.ticket $ticket_name "true")
}


### Main function
# $1: mode
    # empty: NOT WOIRKIGN
    # main: set main branch
    # sep: set branch separator
    # editor: set commit message editor
    # ticket: set prefix for tickets
function config_script {
    case "$1" in
        default|def|d|b|main) set_default_cfg="true";;
        separator|sep|s)    set_sep_cfg="true";;
        editor|ed|e)        set_editor_cfg="true";;
        ticket|jira|ti|t)   set_ticket_cfg="true";;
        help|h)             help="true";;
        *)                  wrong_mode "config" $1
    esac

    if [ "$set_default_cfg" == "true" ]; then
        set_default_branch
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

    if [ "$set_ticket_cfg" == "true" ]; then
        set_ticket
        exit
    fi

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb config <mode>${ENDCOLOR}"
        echo
        echo -e "${YELLOW}Available modes for configuration${ENDCOLOR}"
        echo -e "<empty>\t\t\tPrint current gitbasher configuration"
        echo -e "default|def|d|b|main\tUpdate gitbasher's default branch (not in remote git repo!)"
        echo -e "separator|sep|s\t\tUpdate separator between type and name in branch"
        echo -e "editor|ed|e\t\tUpdate text editor for the commit messages"
        echo -e "ticket|ti|t|jira\tSet ticket prefix to help with commit/branch building"
        exit
    fi

    print_configuration
}

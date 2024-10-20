#!/usr/bin/env bash

### Script for configurate gitbasher
# Read README.md to get more information how to use it
# Use this script only with gitbasher because it is using global variables


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
    echo -e "${YELLOW}Enter a ticket prefix${ENDCOLOR}"
    echo

    if [ -z $ticket_name ]; then
        echo -e "${YELLOW}Ticket prefix is not set in gitbasher${ENDCOLOR}"
    else
        echo -e "Current ticket prefix: ${YELLOW}$ticket_name${ENDCOLOR}"
    fi
   
    read -p "Ticket prefix: " -e ticket_name

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


### Function asks user to set scope
function set_scopes {
    echo -e "${YELLOW}Enter a list of predefined scopes${ENDCOLOR}"
    echo
    if [ "$scopes" == "" ]; then
        echo -e "${YELLOW}Scopes list is not set${ENDCOLOR}"
    else
        echo -e "Current list of scopes: ${YELLOW}$scopes${ENDCOLOR}"
    fi
    echo -e "Use only english letters and space as separator, maximum is 9 scopes"
    echo -e "Enter 0 if you want to remove scopes"

    read -p "Scopes: " -e scopes_raw

    if [ "$scopes_raw" == "" ]; then
        exit
    fi

    if [ "$scopes_raw" == "0" ]; then
        git config --local --unset-all gitbasher.scopes

        echo
        echo -e "${GREEN}Scopes list removed from '${project_name}' repo${ENDCOLOR}"
        exit
    fi

    echo

    re='^([a-zA-Z]+ ){0,8}([a-zA-Z]+)+$'
    if ! [[ $scopes_raw =~ $re ]]; then
        echo -e "${RED}Invalid scopes list!${ENDCOLOR}"
        exit
    fi

    git config --local --replace-all gitbasher.scopes "$scopes_raw"

    scopes="$scopes_raw"

    echo -e "${GREEN}Set '${scopes}' as a scopes list in '${project_name}' repo${ENDCOLOR}"
    echo

    echo -e "Do you want to set it ${YELLOW}globally${ENDCOLOR} for all projects (y/n)?"
    yes_no_choice "\nSet '${scopes}' globally" "true"

    git config --global --replace-all gitbasher.scopes "$scopes_raw"
}


### Function asks user to unset global
function delete_global {
    echo -e "${YELLOW}Unset global config${ENDCOLOR}"
    echo
    echo -e "Select a cfg to unset from global settings"

    global_default=$(git config --global --get gitbasher.branch)
    if [ "$global_default" != "" ]; then
        echo -e "1. Default branch: ${YELLOW}${global_default}${ENDCOLOR}"
    fi

    global_sep=$(git config --global --get gitbasher.sep)
    if [ "$global_sep" != "" ]; then
        echo -e "2. Branch separator: ${YELLOW}${global_sep}${ENDCOLOR}"
    fi

    global_editor=$(git config --global --get core.editor)
    if [ "$global_editor" != "" ]; then
        echo -e "3. Commit message editor: ${YELLOW}${global_editor}${ENDCOLOR}"
    fi

    global_ticket=$(git config --global --get gitbasher.ticket)
    if [ "$global_ticket" != "" ]; then
        echo -e "4. Ticket prefix: ${YELLOW}${global_ticket}${ENDCOLOR}"
    fi

    global_scopes=$(git config --global --get gitbasher.scopes)
    if [ "$global_scopes" != "" ]; then
        echo -e "5. Scopes list: ${YELLOW}${global_scopes}${ENDCOLOR}"
    fi

    echo -e "0. Exit"

    read -n 1 -s choice
    re='^[012345]+$'
    if ! [[ $choice =~ $re ]]; then
        break
    fi

    if [ "$choice" == "0" ]; then
        exit
    fi

    echo

    case "$choice" in
        1)  
            echo -e "${GREEN}Unset default branch from global settings${ENDCOLOR}"
            git config --global --unset gitbasher.branch
            ;;
        2)
            echo -e "${GREEN}Unset branch separator from global settings${ENDCOLOR}"
            git config --global --unset gitbasher.sep
            ;;
        3)
            echo -e "${GREEN}Unset commit message editor from global settings${ENDCOLOR}"
            git config --global --unset core.editor
            ;;
        4)
            echo -e "${GREEN}Unset ticket prefix from global settings${ENDCOLOR}"
            git config --global --unset gitbasher.ticket
            ;;
        5)
            echo -e "${GREEN}Unset scopes list from global settings${ENDCOLOR}"
            git config --global --unset gitbasher.scopes
            ;;
    esac
}


### Function asks user to set name and email
function set_user {
    echo -e "${YELLOW}Set user name and email${ENDCOLOR}"
    echo
    echo -e "Current name: ${YELLOW}$(get_config_value user.name)${ENDCOLOR}"
    echo -e "Enter new name or leave it empty if you don't want to change it"
    read -p "Name: " -e user_name

    echo
    echo -e "Current email: ${YELLOW}$(get_config_value user.email)${ENDCOLOR}"
    echo -e "Enter new email or leave it empty if you don't want to change it"
    read -p "Email: " -e user_email

    if [ "$user_name" == "" ] && [ "$user_email" == "" ]; then
        exit
    fi

    echo

    if [ "$user_name" != "" ]; then
        echo -e "${GREEN}Set user name to '${user_name}'${ENDCOLOR}"
        git config --local --replace-all user.name "$user_name"
    fi
    if [ "$user_email" != "" ]; then
        echo -e "${GREEN}Set user email to '${user_email}'${ENDCOLOR}"
        git config --local --replace-all user.email "$user_email"
    fi
}

### Main function
# $1: mode
    # empty: show current config
    # default: set main branch
    # sep: set branch separator
    # editor: set commit message editor
    # ticket: set prefix for tickets
    # scope: add list of scopes
    # delete: delete global config
    # user: set user name and email
function config_script {
    case "$1" in
        default|def|d|b|main) set_default_cfg="true";;
        separator|sep)        set_sep_cfg="true";;
        editor|ed|e)          set_editor_cfg="true";;
        ticket|jira|ti|t)     set_ticket_cfg="true";;
        scopes|scope|sc|s)    set_scopes_cfg="true";;
        delete|unset|del)     delete_cfg="true";;
        user|name|email|u)    set_user_cfg="true";;
        help|h)               help="true";;
        *)                    wrong_mode "config" $1
    esac

    ### Merge mode - print header
    header="GIT CONFIG"
    if [ -n "${set_default_cfg}" ]; then
        header="$header DEFAULT BRANCH"
    elif [ -n "${set_sep_cfg}" ]; then
        header="$header BRANCH SEPARATOR"
    elif [ -n "${set_editor_cfg}" ]; then
        header="$header COMMIT MESSAGE EDITOR"
    elif [ -n "${set_ticket_cfg}" ]; then
        header="$header TICKET PREFIX"
    elif [ -n "${set_scopes_cfg}" ]; then
        header="$header SCOPES LIST"
    elif [ -n "${delete}" ]; then
        header="$header UNSET GLOBAL CONFIG"
    elif [ -n "${set_user_cfg}" ]; then
        header="$header USER NAME & EMAIL"
    fi

    echo -e "${YELLOW}${header}${ENDCOLOR}"
    echo

    if [ "$set_user_cfg" == "true" ]; then
        set_user
        exit
    fi

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

    if [ "$set_scopes_cfg" == "true" ]; then
        set_scopes
        exit
    fi

    if [ "$delete_cfg" == "true" ]; then
        delete_global
        exit
    fi

    if [ -n "$help" ]; then
        echo -e "usage: ${YELLOW}gitb config <mode>${ENDCOLOR}"
        echo
        echo -e "${YELLOW}Available modes for configuration${ENDCOLOR}"
        echo -e "<empty>\t\t\tPrint current gitbasher configuration"
        echo -e "user|name|email|u\tSet user name and email"
        echo -e "default|def|d|b|main\tUpdate gitbasher's default branch (not in remote git repo!)"
        echo -e "separator|sep|s\t\tUpdate separator between type and name in branch"
        echo -e "editor|ed|e\t\tUpdate text editor for the commit messages"
        echo -e "ticket|ti|t|jira\tSet ticket prefix to help with commit/branch building"
        echo -e "scopes|sc|s\t\tSet a list of scopes to help with commit building"
        echo -e "delete|unset|del\tUnset global configuration"
        exit
    fi

    print_configuration
}

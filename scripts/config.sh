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
    echo -e "It will override ${YELLOW}core.editor${ENDCOLOR} git config value, press Enter if you want to exit"
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


### Function asks user to set AI API key
function configure_ai_key {
    echo -e "${YELLOW}Enter AI API key${ENDCOLOR}"
    echo
    
    ai_api_key=$(get_ai_api_key)
    if [ -z "$ai_api_key" ]; then
        echo -e "${YELLOW}AI API key is not set${ENDCOLOR}"
    else
        echo -e "AI API key is ${GREEN}configured${ENDCOLOR}: ${BLUE}$(mask_api_key "$ai_api_key")${ENDCOLOR}"
    fi
    echo -e "Enter your ${YELLOW}Gemini API key${ENDCOLOR} to enable AI commit message generation"
    echo -e "Get your API key from: ${BLUE}https://aistudio.google.com/app/apikey${ENDCOLOR}"
    echo -e "Press Enter to exit without changes or enter 0 to remove existing key"

    echo
    echo -e "${YELLOW}API key enters silently, so you can't see it, but it is entered${ENDCOLOR}"

    read -p "API Key: " -s ai_key_input
    echo

    if [ "$ai_key_input" == "" ]; then
        exit
    fi

    if [ "$ai_key_input" == "0" ]; then
        git config --local --unset gitbasher.ai-api-key 2>/dev/null
        echo
        echo -e "${GREEN}AI API key removed from '${project_name}' repo${ENDCOLOR}"
        exit
    fi

    echo

    # Validate API key format (basic check)
    if [[ ! "$ai_key_input" =~ ^AIza[A-Za-z0-9_-]{35}$ ]]; then
        echo -e "${RED}Warning: API key format doesn't match expected Gemini format${ENDCOLOR}"
        read -n 1 -p "Continue anyway? (y/n) " -s choice
        echo
        if [ "$choice" != "y" ] && [ "$choice" != "Y" ]; then
            exit
        fi
    fi

    ai_api_key=$(set_config_value gitbasher.ai-api-key "$ai_key_input")
    echo -e "${GREEN}AI API key configured for '${project_name}' repo${ENDCOLOR}: ${BLUE}$(mask_api_key "$ai_api_key")${ENDCOLOR}"
    echo

    echo -e "Do you want to set it ${YELLOW}globally${ENDCOLOR} for all projects (y/n)?"
    yes_no_choice "\nSet AI API key globally" "true"
    ai_api_key=$(set_config_value gitbasher.ai-api-key "$ai_key_input" "true")
}


### Function asks user to set AI proxy
function configure_ai_proxy {    
    echo -e "${YELLOW}Configure AI HTTP/SOCKS Proxy${ENDCOLOR}"
    echo
    
    ai_proxy=$(get_ai_proxy)
    if [ -z "$ai_proxy" ]; then
        echo -e "${YELLOW}AI proxy is not configured${ENDCOLOR}"
    else
        echo -e "Current AI proxy: ${GREEN}$ai_proxy${ENDCOLOR}"
    fi
    
    echo -e "Enter proxy URL to route AI requests through (useful for bypassing geo-restrictions)"
    echo -e ""
    echo -e "${BLUE}HTTP proxy formats:${ENDCOLOR}"
    echo -e "  • ${BLUE}http://proxy.example.com:8080${ENDCOLOR}"
    echo -e "  • ${BLUE}http://username:password@proxy.example.com:8080${ENDCOLOR}"
    echo -e "  • ${BLUE}http://[2001:db8::1]:8080${ENDCOLOR} (IPv6)"
    echo -e ""
    echo -e "Press Enter to exit without changes or enter 0 to remove existing proxy"

    read -p "Proxy URL: " ai_proxy_input

    if [ "$ai_proxy_input" == "" ]; then
        exit
    fi

    if [ "$ai_proxy_input" == "0" ]; then
        clear_ai_proxy
        echo
        echo -e "${GREEN}AI proxy removed from '${project_name}' repo${ENDCOLOR}"
        exit
    fi

    echo

    # Validate and sanitize proxy URL to prevent command injection
    if ! validate_proxy_url "$ai_proxy_input"; then
        echo -e "${RED}Invalid proxy URL format: $ai_proxy_input${ENDCOLOR}"
        echo -e "${YELLOW}Expected format: protocol://host:port (e.g., http://proxy.example.com:8080)${ENDCOLOR}"
        echo -e "${YELLOW}Or: host:port (e.g., proxy.example.com:8080)${ENDCOLOR}"
        echo -e "${YELLOW}Supported protocols: http, https, socks5${ENDCOLOR}"
        exit 1
    fi
    
    # Use the validated proxy URL
    ai_proxy_input="$validated_proxy_url"

    set_ai_proxy "$ai_proxy_input"
    echo -e "${GREEN}AI proxy configured for '${project_name}' repo${ENDCOLOR}: ${BLUE}$ai_proxy_input${ENDCOLOR}"
    echo
    echo -e "${YELLOW}Example usage:${ENDCOLOR}"
    echo -e "  ${BLUE}gitb commit ai${ENDCOLOR}    - Generate commit with AI through proxy"
    echo -e "  ${BLUE}gitb commit aif${ENDCOLOR}   - Fast AI commit through proxy"
    echo
   
    echo -e "Do you want to set it ${YELLOW}globally${ENDCOLOR} for all projects (y/n)?"
    yes_no_choice "\nSet AI proxy globally" "true"
    set_ai_proxy "$ai_proxy_input"
    git config --global gitbasher.ai-proxy "$ai_proxy_input"
}


### Function asks user to configure AI commit history limit
function configure_ai_history {
    echo -e "${YELLOW}Configure AI Commit History Limit${ENDCOLOR}"
    echo
    
    current_limit=$(get_ai_commit_history_limit)
    echo -e "Current limit: ${GREEN}$current_limit${ENDCOLOR} recent commits"
    echo
    echo -e "This setting controls how many recent commit messages are included in AI prompts"
    echo -e "to help the AI learn from your commit message patterns and style."
    echo -e ""
    echo -e "Recommended range: ${BLUE}5-15${ENDCOLOR} commits"
    echo -e "• Lower values (5-8): Faster, uses fewer tokens, focuses on recent patterns"
    echo -e "• Higher values (10-15): Better style learning, uses more tokens"
    echo
    echo -e "Press Enter to exit without changes"

    read -p "Number of recent commits to include: " limit_input

    if [ "$limit_input" == "" ]; then
        exit
    fi

    echo

    # Validate input is a positive number
    if ! [[ "$limit_input" =~ ^[1-9][0-9]*$ ]]; then
        echo -e "${RED}Error: Please enter a positive number${ENDCOLOR}"
        exit 1
    fi

    # Warn if value is outside recommended range
    if [ "$limit_input" -lt 5 ] || [ "$limit_input" -gt 20 ]; then
        echo -e "${YELLOW}Warning: Value outside recommended range (5-20)${ENDCOLOR}"
        if [ "$limit_input" -gt 20 ]; then
            echo -e "${YELLOW}High values may exceed token limits and slow down AI responses${ENDCOLOR}"
        fi
        read -n 1 -p "Continue anyway? (y/n) " -s choice
        echo
        if [ "$choice" != "y" ] && [ "$choice" != "Y" ]; then
            exit
        fi
    fi

    set_ai_commit_history_limit "$limit_input"
    echo -e "${GREEN}AI commit history limit set to ${limit_input} for '${project_name}' repo${ENDCOLOR}"
    echo

    echo -e "Do you want to set it ${YELLOW}globally${ENDCOLOR} for all projects (y/n)?"
    yes_no_choice "\nSet AI commit history limit globally" "true"
    git config --global gitbasher.ai-commit-history-limit "$limit_input"
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

    global_ai_key=$(git config --global --get gitbasher.ai-api-key)
    if [ "$global_ai_key" != "" ]; then
        echo -e "6. AI API key: ${GREEN}configured${ENDCOLOR}"
    fi

    global_ai_proxy=$(git config --global --get gitbasher.ai-proxy)
    if [ "$global_ai_proxy" != "" ]; then
        echo -e "7. AI proxy: ${GREEN}$global_ai_proxy${ENDCOLOR}"
    fi

    global_ai_history=$(git config --global --get gitbasher.ai-commit-history-limit)
    if [ "$global_ai_history" != "" ]; then
        echo -e "8. AI commit history limit: ${GREEN}$global_ai_history${ENDCOLOR}"
    fi

    echo -e "0. Exit"

    read -n 1 -s choice
    re='^[012345678]+$'
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
        6)
            echo -e "${GREEN}Unset AI API key from global settings${ENDCOLOR}"
            git config --global --unset gitbasher.ai-api-key
            ;;
        7)
            echo -e "${GREEN}Unset AI proxy from global settings${ENDCOLOR}"
            git config --global --unset gitbasher.ai-proxy
            ;;
        8)
            echo -e "${GREEN}Unset AI commit history limit from global settings${ENDCOLOR}"
            git config --global --unset gitbasher.ai-commit-history-limit
            ;;
    esac
}


### Function asks user to set name and email
function set_user {
    echo -e "${YELLOW}Set user name and email${ENDCOLOR}"
    echo
    echo -e "Current name: ${YELLOW}$(get_config_value user.name)${ENDCOLOR}"
    echo -e "Enter new name or press Enter if you don't want to change it"
    read -p "Name: " -e user_name

    echo
    echo -e "Current email: ${YELLOW}$(get_config_value user.email)${ENDCOLOR}"
    echo -e "Enter new email or press Enter if you don't want to change it"
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
        ai|llm|key)           set_ai_cfg="true";;
        proxy|prx|p)          set_proxy_cfg="true";;
        history|hist)         set_ai_history_cfg="true";;
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
    elif [ -n "${set_ai_cfg}" ]; then
        header="$header AI API KEY"
    elif [ -n "${set_proxy_cfg}" ]; then
        header="$header AI PROXY"
    elif [ -n "${set_ai_history_cfg}" ]; then
        header="$header AI COMMIT HISTORY"
    elif [ -n "${delete_cfg}" ]; then
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

    if [ "$set_ai_cfg" == "true" ]; then
        configure_ai_key
        exit
    fi

    if [ "$set_proxy_cfg" == "true" ]; then
        configure_ai_proxy
        exit
    fi

    if [ "$set_ai_history_cfg" == "true" ]; then
        configure_ai_history
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
        echo -e "ai|llm|key\t\tSet AI API key for commit message generation"
        echo -e "proxy|prx|p\t\tSet HTTP proxy for AI requests (bypass geo-restrictions)"
        echo -e "history|hist\t\tSet number of recent commits to include in AI prompts"
        echo -e "delete|unset|del\tUnset global configuration"
        exit
    fi

    print_configuration
}

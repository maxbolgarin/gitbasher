#!/usr/bin/env bash

### Script for initializing gitbasher
# Run it before using gitbasher

### Consts for colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
PURPLE="\e[35m"
CYAN="\e[36m"
GRAY="\e[37m"
ENDCOLOR="\e[0m"
BOLD="\033[1m"
NORMAL="\033[0m"


### Function tries to get config from local, then from global, then returns default
# $1: config name
# $2: default value
# Returns: config value
function get_config_value {
    value=$(git config --local --get "$1")
    if [ "$value" == "" ]; then
        value=$(git config --global --get "$1")
        if [ "$value" == "" ]; then
            value=$2
        fi
    fi
    echo -e "$value"
}


### Function sets git config value
# $1: name
# $2: value
# $3: global flag
# Returns: value
function set_config_value {
    if [ -z $3 ]; then
        git config --local "$1" "$2"
    else
        git config --global "$1" "$2"
    fi
}


### Function to unset git config value
# $1: config name
# Returns: value
function unset_config_value {
    git config --unset "$1"

    # Check if global config exists and ask user if they want to clear it too
    local global_config=$(git config --global --get "$1" 2>/dev/null)
    if [ -n "$global_config" ]; then
        echo
        echo -e "${YELLOW}Global $1 is also configured: ${BLUE}$global_config${ENDCOLOR}"
        echo -e "Do you want to clear it ${YELLOW}globally${ENDCOLOR} for all projects (y/n)?"
        yes_no_choice "\nClear AI proxy globally" "false"
        if [ $? -eq 0 ]; then
            git config --global --unset "$1" 2>/dev/null
            echo -e "${GREEN}$1 cleared globally${ENDCOLOR}"
        fi
    fi
}


### Function to validate git remote URL
# $1: URL string
# Returns: 0 if valid URL format, 1 if invalid
# Sets: validated_url global variable
function validate_git_url {
    local input="$1"
    validated_url=""
    
    if [ -z "$input" ]; then
        return 1
    fi
    
    # Remove dangerous characters first
    local cleaned=$(echo "$input" | tr -d '\000-\037\177')
    
    # Basic validation for common git URL formats:
    # https://github.com/user/repo.git
    # git@github.com:user/repo.git
    # ssh://git@server.com/repo.git
    # /path/to/repo.git (local)
    if [[ "$cleaned" =~ ^https?://[a-zA-Z0-9.-]+/[a-zA-Z0-9._/-]+(.git)?$ ]] || \
       [[ "$cleaned" =~ ^git@[a-zA-Z0-9.-]+:[a-zA-Z0-9._/-]+(.git)?$ ]] || \
       [[ "$cleaned" =~ ^ssh://[a-zA-Z0-9@.-]+/[a-zA-Z0-9._/-]+(.git)?$ ]] || \
       [[ "$cleaned" =~ ^[a-zA-Z0-9._/-]+(.git)?$ ]]; then
        
        # Length check
        if [ ${#cleaned} -le 500 ]; then
            validated_url="$cleaned"
            return 0
        fi
    fi
    
    return 1
}


### Branches
current_branch=$(git branch --show-current)

main_branch=$(get_config_value gitbasher.branch "main")
if [[ "$( git branch | grep "^[\s\*]*\s*main\s*$" )" == "" ]] && [[ "$( git branch | grep "^[\s\*]*\s*master\s*$" )" != "" ]]; then
    main_branch="master"
elif [[ "$(git branch | cat)" == "" ]]; then
    main_branch=$current_branch
fi

if [ "$(get_config_value gitbasher.branch "")" == "" ]; then
    git config --local gitbasher.branch "$main_branch"
fi


### Remote
origin_name=$(git remote -v | head -n 1 | sed 's/\t.*//')
if [ "$origin_name" == "" ]; then 
    echo -e "${YELLOW}There is no configured remote in this repo!${ENDCOLOR}"
    echo
    echo -e "Use ${BLUE}git remote add origin <url>${ENDCOLOR} to add it manually"
    echo -e "Press '${BOLD}y${ENDCOLOR}' to add it now or an any key to exit"

    read -n 1 -s choice
    if [ "$choice" != "y" ]; then
        exit
    fi

    echo
    
    read -p "Remote repo URL: " -e remote_url

    if [ "$remote_url" == "" ]; then
        exit
    fi

    # Validate remote URL format
    if ! validate_git_url "$remote_url"; then
        echo
        echo -e "${RED}Invalid git URL format!${ENDCOLOR}"
        echo -e "${YELLOW}Expected formats:${ENDCOLOR}"
        echo -e "  • https://github.com/user/repo.git"
        echo -e "  • git@github.com:user/repo.git"
        echo -e "  • ssh://git@server.com/repo.git"
        exit 1
    fi
    remote_url="$validated_url"

    remote_check=$(git ls-remote "$remote_url" 2>&1)
    if [[ "$remote_check" == *"does not appear to be a git"* ]]; then
        echo
        echo -e "${RED}'$remote_url' is not a git repository!${ENDCOLOR}"
        echo "Please make sure you have the correct access rights and the repository exists."
        exit
    fi

    git remote add origin "$remote_url"
    echo -e "${GREEN}Remote successfully added!${ENDCOLOR}"
    if [ "$remote_check" == "" ]; then
        echo -e "${YELLOW}Repository '$remote_url' is probably empty${ENDCOLOR}"
    fi
    echo
    
    origin_name=$(git remote -v | head -n 1 | sed 's/\t.*//')
fi


### Get configuration from git config
sep=$(get_config_value gitbasher.sep "-")
editor=$(get_config_value core.editor "vi")
ticket_name=$(get_config_value gitbasher.ticket "")
scopes=$(get_config_value gitbasher.scopes "")


### Is this is a first run of gitbasher in this project?
is_first=$(get_config_value gitbasher.isfirst "true")
git config --local gitbasher.isfirst "false"

